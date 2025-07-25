// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FileRegistry.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract MockVerifier is Groth16Verifier {
    bool private shouldPassProof;

    function setVerificationResult(bool _shouldPass) public {
        shouldPassProof = _shouldPass;
    }

    function verifyProof(
        uint256[2] calldata,
        uint256[2][2] calldata,
        uint256[2] calldata,
        uint256[1] calldata
    ) public view override returns (bool) {
        return shouldPassProof;
    }
}

contract FileRegistryTest is Test {
    FileRegistry public fileRegistry;
    MockVerifier public mockVerifier;

    address public owner;
    uint256[2] private dummyPA;
    uint256[2][2] private dummyPB;
    uint256[2] private dummyPC;
    uint256[1] private dummyPublicSignals = [uint256(bytes32("unique_file_content_hash"))];

    function setUp() public {
        owner = address(this);
        mockVerifier = new MockVerifier();
        fileRegistry = new FileRegistry(address(mockVerifier));
        fileRegistry.addUploader(owner);
    }

    function test_RegisterFileSuccessfully() public {
        mockVerifier.setVerificationResult(true);
        fileRegistry.registerFile(dummyPA, dummyPB, dummyPC, dummyPublicSignals, "my_legal_document.pdf");
        (address uploader, , string memory fileName) = fileRegistry.getFileRecord(bytes32(dummyPublicSignals[0]));
        assertEq(uploader, owner);
        assertEq(fileName, "my_legal_document.pdf");
    }

    function test_FailOnDuplicateRegistration() public {
        mockVerifier.setVerificationResult(true);
        fileRegistry.registerFile(dummyPA, dummyPB, dummyPC, dummyPublicSignals, "original.txt");
        vm.expectRevert("FileRegistry: File content already registered");
        fileRegistry.registerFile(dummyPA, dummyPB, dummyPC, dummyPublicSignals, "duplicate.txt");
    }

    function test_FailWithInvalidProof() public {
        mockVerifier.setVerificationResult(false);
        vm.expectRevert("FileRegistry: Invalid ZK proof");
        fileRegistry.registerFile(dummyPA, dummyPB, dummyPC, dummyPublicSignals, "bad_proof.zip");
    }

    function test_OwnerCanAddAndRemoveUploader() public {
        address newUploader = makeAddr("newUploader");
        assertFalse(fileRegistry.isUploader(newUploader));
        fileRegistry.addUploader(newUploader);
        assertTrue(fileRegistry.isUploader(newUploader));
        fileRegistry.removeUploader(newUploader);
        assertFalse(fileRegistry.isUploader(newUploader));
    }

    function test_FailNonOwnerCannotAddUploader() public {
        address nonOwner = makeAddr("nonOwner");
        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        fileRegistry.addUploader(makeAddr("some_address"));
        vm.stopPrank();
    }

    function test_FailNonUploaderCannotRegisterFile() public {
        address nonUploader = makeAddr("nonUploader");
        mockVerifier.setVerificationResult(true);
        vm.startPrank(nonUploader);
        vm.expectRevert("FileRegistry: Caller is not an authorized uploader");
        fileRegistry.registerFile(dummyPA, dummyPB, dummyPC, dummyPublicSignals, "unauthorized.txt");
        vm.stopPrank();
    }
}