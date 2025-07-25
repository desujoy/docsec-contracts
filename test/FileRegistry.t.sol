// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FileRegistry.sol";
import "../src/Verifier.sol"; 

contract MockVerifier is Groth16Verifier {
    bool private shouldPassProof;

    function setVerificationResult(bool _shouldPass) public {
        shouldPassProof = _shouldPass;
    }

    /**
     * @dev CORRECTED: This function now correctly overrides the parent.
     * 1. Added the `override` keyword.
     * 2. Changed parameter data locations from `memory` to `calldata` to match the parent.
     */
    function verifyProof(
        uint256[2] calldata /* _pA */,
        uint256[2][2] calldata /* _pB */,
        uint256[2] calldata /* _pC */,
        uint256[1] calldata /* _publicSignals */
    ) public view override returns (bool) {
        return shouldPassProof;
    }
}


contract FileRegistryTest is Test {
    FileRegistry public fileRegistry;
    MockVerifier public mockVerifier;

    // Dummy data for tests
    uint256[2] private dummyPA;
    uint256[2][2] private dummyPB;
    uint256[2] private dummyPC;
    uint256[1] private dummyPublicSignals = [uint256(bytes32("unique_file_content_hash"))];

    function setUp() public {
        mockVerifier = new MockVerifier();
        fileRegistry = new FileRegistry(address(mockVerifier));
    }

    function test_RegisterFileSuccessfully() public {
        mockVerifier.setVerificationResult(true);

        // For the test, we need to pass the parameters that registerFile now expects
        fileRegistry.registerFile(dummyPA, dummyPB, dummyPC, dummyPublicSignals, "my_legal_document.pdf");

        (address uploader, , string memory fileName) = fileRegistry.getFileRecord(
            bytes32(dummyPublicSignals[0])
        );
        assertEq(uploader, address(this));
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
        fileRegistry.registerFile(dummyPA, dummyPB, dummyPC, dummyPublicSignals, "file_with_bad_proof.zip");
    }
}