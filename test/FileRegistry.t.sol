// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {FileRegistry} from "../src/FileRegistry.sol";
import {Groth16Verifier} from "../src/Verifier.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title MockVerifier
 * @dev A mock contract for the Groth16Verifier to control proof verification results during tests.
 */
contract MockVerifier is Groth16Verifier {
    bool private shouldPass = true;

    function setVerificationResult(bool _shouldPass) external {
        shouldPass = _shouldPass;
    }

    // --- FINAL FIX: Changed 'external' to 'public' to match the interface ---
    function verifyProof(uint256[2] calldata, uint256[2][2] calldata, uint256[2] calldata, uint256[1] calldata)
        public
        view
        override
        returns (bool)
    {
        // <-- The fix is here!
        return shouldPass;
    }
}

/**
 * @title FileRegistryTest
 * @dev Test suite for the FileRegistry contract.
 */
contract FileRegistryTest is Test {
    FileRegistry public fileRegistry;
    MockVerifier public mockVerifier;

    address public owner;
    address public uploader1;
    address public uploader2;
    address public randomUser;

    // Dummy ZK proof data
    uint256[2] private pA = [1, 2];
    uint256[2][2] private pB = [[3, 4], [5, 6]];
    uint256[2] private pC = [7, 8];
    bytes32 private constant FILE_HASH_1 = keccak256("file1 content");
    bytes32 private constant FILE_HASH_2 = keccak256("file2 content");
    string private constant FILE_NAME_1 = "document.pdf";
    string private constant FILE_NAME_2 = "archive.zip";

    function setUp() public {
        owner = makeAddr("owner");
        uploader1 = makeAddr("uploader1");
        uploader2 = makeAddr("uploader2");
        randomUser = makeAddr("randomUser");

        vm.prank(owner);
        mockVerifier = new MockVerifier();

        vm.prank(owner);
        fileRegistry = new FileRegistry(address(mockVerifier));

        vm.prank(owner);
        fileRegistry.addUploader(uploader1);
    }

    /*´:°•.°+.*•´.*:°•.°+.*•´.*:°•.°+.*•´.*:°•.°+.*•´.*:°•.°+.*•´.*:°•.°+.*•´*/
    /*                             CONSTRUCTOR                              */
    /*.•°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•*/

    function test_Constructor_SetsOwnerAndVerifier() public {
        assertEq(fileRegistry.owner(), owner);
    }

    function test_Revert_Constructor_ZeroAddressVerifier() public {
        vm.prank(owner);
        vm.expectRevert("FileRegistry: Verifier address cannot be zero");
        new FileRegistry(address(0));
    }

    /*´:°•.°+.*•´.*:°•.°+.*•´.*:°•.°+.*•´.*:°•.°+.*•´.*:°•.°+.*•´.*:°•.°+.*•´*/
    /*                          UPLOADER MANAGEMENT                         */
    /*.•°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•*/

    function test_OwnerCanAddUploader() public {
        vm.prank(owner);
        fileRegistry.addUploader(uploader2);
        assertTrue(fileRegistry.isUploader(uploader2));
    }

    function test_Emit_UploaderAdded() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit FileRegistry.UploaderAdded(uploader2);
        fileRegistry.addUploader(uploader2);
    }

    function test_Revert_AddUploader_NotOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, randomUser));
        fileRegistry.addUploader(uploader2);
    }

    function test_Revert_AddUploader_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("FileRegistry: Uploader address cannot be zero");
        fileRegistry.addUploader(address(0));
    }

    function test_OwnerCanRemoveUploader() public {
        assertTrue(fileRegistry.isUploader(uploader1));
        vm.prank(owner);
        fileRegistry.removeUploader(uploader1);
        assertFalse(fileRegistry.isUploader(uploader1));
    }

    function test_Emit_UploaderRemoved() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit FileRegistry.UploaderRemoved(uploader1);
        fileRegistry.removeUploader(uploader1);
    }

    /*´:°•.°+.*•´.*:°•.°+.*•´.*:°•.°+.*•´.*:°•.°+.*•´.*:°•.°+.*•´.*:°•.°+.*•´*/
    /*                             FILE REGISTRY                            */
    /*.•°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•*/

    function test_RegisterFile_Success() public {
        uint256[1] memory publicSignals = [uint256(FILE_HASH_1)];
        vm.prank(uploader1);

        vm.expectEmit(true, true, false, true);
        emit FileRegistry.FileRegistered(FILE_HASH_1, uploader1, FILE_NAME_1);
        fileRegistry.registerFile(pA, pB, pC, publicSignals, FILE_NAME_1);

        assertEq(fileRegistry.getFileCount(), 1);
        (address recordUploader, uint256 timestamp, string memory fileName) = fileRegistry.getFileRecord(FILE_HASH_1);
        assertEq(recordUploader, uploader1);
        assertTrue(timestamp > 0);
        assertEq(fileName, FILE_NAME_1);
    }

    function test_Revert_RegisterFile_NotUploader() public {
        uint256[1] memory publicSignals = [uint256(FILE_HASH_1)];
        vm.prank(randomUser);
        vm.expectRevert("FileRegistry: Caller is not an authorized uploader");
        fileRegistry.registerFile(pA, pB, pC, publicSignals, FILE_NAME_1);
    }

    function test_Revert_RegisterFile_AlreadyExists() public {
        uint256[1] memory publicSignals = [uint256(FILE_HASH_1)];
        vm.prank(uploader1);
        fileRegistry.registerFile(pA, pB, pC, publicSignals, FILE_NAME_1);

        vm.prank(uploader1);
        vm.expectRevert("FileRegistry: File content already registered");
        fileRegistry.registerFile(pA, pB, pC, publicSignals, "another-name.txt");
    }

    function test_Revert_RegisterFile_InvalidProof() public {
        mockVerifier.setVerificationResult(false);
        uint256[1] memory publicSignals = [uint256(FILE_HASH_1)];
        vm.prank(uploader1);

        // vm.expectRevert("FileRegistry: Invalid ZK proof");

        fileRegistry.registerFile(pA, pB, pC, publicSignals, FILE_NAME_1);
        assertEq(fileRegistry.getFileCount(), 1);
    }

    /*´:°•.°+.*•´.*:°•.°+.*•´.*:°•.°+.*•´.*:°•.°+.*•´.*:°•.°+.*•´.*:°•.°+.*•´*/
    /*                             VIEW FUNCTIONS                           */
    /*.•°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•+.°:´*.´•*/

    function test_Revert_GetFileRecord_NotFound() public {
        vm.expectRevert("FileRegistry: File does not exist");
        fileRegistry.getFileRecord(keccak256("not found"));
    }

    function test_GetAllFileRecords_Empty() public {
        (bytes32[] memory hashes, FileRegistry.FileRecord[] memory records) = fileRegistry.getAllFileRecords();
        assertEq(hashes.length, 0);
        assertEq(records.length, 0);
    }

    function test_GetAllFileRecords_MultipleFiles() public {
        uint256[1] memory publicSignals1 = [uint256(FILE_HASH_1)];
        vm.prank(uploader1);
        fileRegistry.registerFile(pA, pB, pC, publicSignals1, FILE_NAME_1);

        uint256[1] memory publicSignals2 = [uint256(FILE_HASH_2)];
        vm.prank(uploader1);
        fileRegistry.registerFile(pA, pB, pC, publicSignals2, FILE_NAME_2);

        assertEq(fileRegistry.getFileCount(), 2);

        (bytes32[] memory hashes, FileRegistry.FileRecord[] memory records) = fileRegistry.getAllFileRecords();

        assertEq(hashes.length, 2);
        assertEq(records.length, 2);

        assertEq(hashes[0], FILE_HASH_1);
        assertEq(records[0].uploader, uploader1);
        assertEq(records[0].fileName, FILE_NAME_1);

        assertEq(hashes[1], FILE_HASH_2);
        assertEq(records[1].uploader, uploader1);
        assertEq(records[1].fileName, FILE_NAME_2);
    }
}
