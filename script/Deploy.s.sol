// SPDX-FileCopyrightText: 2026 Klima Protocol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {RelayFeeSkim} from "../src/RelayFeeSkim.sol";

/// @notice CREATE2 deployment through forge's default deployer; a no-op once the address has code.
contract Deploy is Script {
    uint256 public constant FEE_BPS = 500;
    address public constant FEE_SINK = 0xf624f9Fe1D3165c5Ca32c7Fbdbf82f4a5b1D2d0e;
    string public constant SALT_PREIMAGE = "klimaprotocol.com/RelayFeeSkim/v1";
    bytes32 public constant SALT = keccak256(bytes(SALT_PREIMAGE));

    function initCode() public pure returns (bytes memory) {
        return bytes.concat(type(RelayFeeSkim).creationCode, abi.encode(FEE_BPS, FEE_SINK));
    }

    function predict() public pure returns (address) {
        return vm.computeCreate2Address(SALT, keccak256(initCode()), CREATE2_FACTORY);
    }

    function run() external virtual returns (address deployed) {
        require(CREATE2_FACTORY.code.length != 0, "CREATE2 deployer not present");
        deployed = predict();
        console.log("RelayFeeSkim", deployed);
        if (deployed.code.length != 0) {
            console.log("already deployed");
            return deployed;
        }
        vm.startBroadcast();
        (bool ok,) = CREATE2_FACTORY.call(bytes.concat(SALT, initCode()));
        vm.stopBroadcast();
        require(ok && deployed.code.length != 0, "CREATE2 deploy failed");
        console.log("deployed");
    }
}
