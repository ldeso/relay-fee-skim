// SPDX-FileCopyrightText: 2026 Klima Protocol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {RelayFeeSkim} from "../src/RelayFeeSkim.sol";
import {Deploy} from "./Deploy.s.sol";

/// @notice Writes verification/bytecode-hashes.json for the canonical deployment.
contract Hashes is Deploy {
    function run() external override returns (address predicted) {
        predicted = predict();
        string memory artifact = vm.readFile("out/RelayFeeSkim.sol/RelayFeeSkim.json");
        RelayFeeSkim local = new RelayFeeSkim(FEE_BPS, FEE_SINK);

        string memory dep = "deployment";
        string memory depJson = vm.serializeUint(dep, "feeBps", FEE_BPS);
        depJson = vm.serializeAddress(dep, "feeSink", FEE_SINK);
        depJson = vm.serializeBytes(dep, "constructorArgs", abi.encode(FEE_BPS, FEE_SINK));
        depJson = vm.serializeAddress(dep, "address", predicted);
        depJson = vm.serializeBytes32(dep, "runtimeKeccak", keccak256(address(local).code));

        string memory root = "hashes";
        string memory json = vm.serializeString(root, "contract", "src/RelayFeeSkim.sol:RelayFeeSkim");
        json = vm.serializeString(root, "solc", vm.parseJsonString(artifact, ".metadata.compiler.version"));
        json = vm.serializeAddress(root, "create2Deployer", CREATE2_FACTORY);
        json = vm.serializeString(root, "saltPreimage", SALT_PREIMAGE);
        json = vm.serializeBytes32(root, "salt", SALT);
        json = vm.serializeBytes32(root, "creationCodeKeccak", keccak256(type(RelayFeeSkim).creationCode));
        json = vm.serializeBytes32(
            root, "runtimeTemplateKeccak", keccak256(vm.getDeployedCode("RelayFeeSkim.sol:RelayFeeSkim"))
        );
        json = vm.serializeString(root, "deployment", depJson);
        vm.writeJson(json, "verification/bytecode-hashes.json");
    }
}
