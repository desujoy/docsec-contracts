// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {FileRegistry} from "../src/FileRegistry.sol";
import {Groth16Verifier} from "../src/Verifier.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy the ZK Verifier contract
        Groth16Verifier verifier = new Groth16Verifier();

        // Deploy the FileRegistry contract with the verifier address
        FileRegistry fileRegistry = new FileRegistry(address(verifier));

        console.log("FileRegistry deployed at:", address(fileRegistry));
        console.log("Verifier deployed at:", address(verifier));

        vm.stopBroadcast();
    }
}
