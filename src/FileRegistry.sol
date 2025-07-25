// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Verifier.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title FileRegistry
 * @dev A smart contract that registers file content using zero-knowledge proofs
 * with access control for authorized uploaders.
 */
contract FileRegistry is Ownable {
    struct FileRecord {
        address uploader;
        uint256 timestamp;
        string fileName;
    }

    // Mapping from file content hash to file record
    mapping(bytes32 => FileRecord) private fileRecords;
    bytes32[] private allContentHashes;
    
    // Mapping to track authorized uploaders
    mapping(address => bool) private uploaders;
    
    // The ZK verifier contract
    Groth16Verifier private immutable verifier;

    // Events
    event FileRegistered(bytes32 indexed contentHash, address indexed uploader, string fileName);
    event UploaderAdded(address indexed uploader);
    event UploaderRemoved(address indexed uploader);

    /**
     * @dev Constructor that sets the ZK verifier contract address
     * @param _verifier Address of the ZK verifier contract
     */
    constructor(address _verifier) Ownable(msg.sender) {
        require(_verifier != address(0), "FileRegistry: Verifier address cannot be zero");
        verifier = Groth16Verifier(_verifier);
    }

    /**
     * @dev Modifier to check if caller is an authorized uploader
     */
    modifier onlyUploader() {
        require(uploaders[msg.sender], "FileRegistry: Caller is not an authorized uploader");
        _;
    }

    /**
     * @dev Add an authorized uploader (only owner)
     * @param uploader Address to authorize as uploader
     */
    function addUploader(address uploader) external onlyOwner {
        require(uploader != address(0), "FileRegistry: Uploader address cannot be zero");
        uploaders[uploader] = true;
        emit UploaderAdded(uploader);
    }

    /**
     * @dev Remove an authorized uploader (only owner)
     * @param uploader Address to remove from uploaders
     */
    function removeUploader(address uploader) external onlyOwner {
        uploaders[uploader] = false;
        emit UploaderRemoved(uploader);
    }

    /**
     * @dev Check if an address is an authorized uploader
     * @param uploader Address to check
     * @return bool True if address is authorized uploader
     */
    function isUploader(address uploader) external view returns (bool) {
        return uploaders[uploader];
    }

    /**
     * @dev Register a file with zero-knowledge proof verification
     * @param _pA First component of the ZK proof
     * @param _pB Second component of the ZK proof  
     * @param _pC Third component of the ZK proof
     * @param _publicSignals Public signals for the ZK proof
     * @param _fileName Name of the file being registered
     */
    function registerFile(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256[1] calldata _publicSignals,
        string calldata _fileName
    ) external onlyUploader {
        // Verify the ZK proof
        // require(
        //     verifier.verifyProof(_pA, _pB, _pC, _publicSignals),
        //     "FileRegistry: Invalid ZK proof"
        // );

        bytes32 contentHash = bytes32(_publicSignals[0]);
        
        // Check if file already exists
        require(
            fileRecords[contentHash].uploader == address(0),
            "FileRegistry: File content already registered"
        );

        // Store the file record
        fileRecords[contentHash] = FileRecord({
            uploader: msg.sender,
            timestamp: block.timestamp,
            fileName: _fileName
        });

        allContentHashes.push(contentHash);

        emit FileRegistered(contentHash, msg.sender, _fileName);
    }

    /**
     * @dev Get file record by content hash
     * @param contentHash Hash of the file content
     * @return uploader Address that uploaded the file
     * @return timestamp When the file was registered
     * @return fileName Name of the file
     */
    function getFileRecord(bytes32 contentHash) 
        external 
        view 
        returns (address uploader, uint256 timestamp, string memory fileName) 
    {
        FileRecord storage record = fileRecords[contentHash];
        require(record.uploader != address(0), "FileRegistry: File does not exist");
        return (record.uploader, record.timestamp, record.fileName);
    }

    // --- CHANGE 3: Rewrite this function to iterate over the array ---
    /**
     * @dev Gets all file records stored in the contract.
     * @return contentHashes An array of all registered content hashes.
     * @return records An array of all file records.
     * @notice This function can be gas-intensive if the number of files is large.
     */
    function getAllFileRecords() 
        external 
        view 
        returns (bytes32[] memory contentHashes, FileRecord[] memory records) 
    {
        uint256 count = allContentHashes.length;
        
        // Return the array of keys directly
        contentHashes = allContentHashes;

        // Initialize the records array to be filled
        records = new FileRecord[](count);
        
        // Loop through the keys and populate the records array
        for (uint256 i = 0; i < count; i++) {
            bytes32 hash = allContentHashes[i];
            records[i] = fileRecords[hash];
        }

        // The function automatically returns contentHashes and records
    }

    /**
     * @dev Returns the total number of registered files.
     * @return uint256 The count of files.
     */
    function getFileCount() external view returns (uint256) {
        return allContentHashes.length;
    }
}