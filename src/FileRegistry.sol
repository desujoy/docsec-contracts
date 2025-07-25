// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Verifier.sol";

contract FileRegistry {
    Groth16Verifier public verifier;

    struct FileRecord {
        address uploader;
        uint256 timestamp;
        string fileName;
    }

    mapping(bytes32 => FileRecord) public fileRecords;

    event FileRegistered(
        bytes32 indexed poseidonHash,
        address indexed uploader,
        uint256 timestamp,
        string fileName
    );

    constructor(address verifierAddress) {
        require(verifierAddress != address(0), "Invalid verifier address");
        verifier = Groth16Verifier(verifierAddress);
    }

    /**
     * @dev Registers a file by verifying a ZK proof of knowledge of its SHA256 hash.
     * @param _pA The A point of the groth16 proof.
     * @param _pB The B point of the groth16 proof.
     * @param _pC The C point of the groth16 proof.
     * @param _publicSignals The public signals (containing the Poseidon hash).
     * @param _fileName The original name of the file.
     */
    function registerFile(
        uint256[2] memory _pA,
        uint256[2][2] memory _pB,
        uint256[2] memory _pC,
        uint256[1] memory _publicSignals,
        string memory _fileName
    ) public {
        // The public signal is the unique identifier for the file's content
        bytes32 poseidonHash = bytes32(_publicSignals[0]);

        // 1. Integrity Check: Ensure this file content hasn't been registered before
        require(
            fileRecords[poseidonHash].uploader == address(0),
            "FileRegistry: File content already registered"
        );

        // 2. ZK Verification: Call the verifier contract to validate the proof.
        // The parameters are passed directly as the verifier expects them.
        require(verifier.verifyProof(_pA, _pB, _pC, _publicSignals), "FileRegistry: Invalid ZK proof");

        // 3. State Change: Store the file metadata on-chain
        fileRecords[poseidonHash] = FileRecord({
            uploader: msg.sender,
            timestamp: block.timestamp,
            fileName: _fileName
        });

        // 4. Audit Trail: Emit an event for easy off-chain tracking
        emit FileRegistered(
            poseidonHash,
            msg.sender,
            block.timestamp,
            _fileName
        );
    }

    /**
     * @dev Public view function to check a file's integrity record.
     * Anyone can call this off-chain without a transaction.
     */
    function getFileRecord(bytes32 poseidonHash)
        public
        view
        returns (address, uint256, string memory)
    {
        FileRecord memory record = fileRecords[poseidonHash];
        return (record.uploader, record.timestamp, record.fileName);
    }
}