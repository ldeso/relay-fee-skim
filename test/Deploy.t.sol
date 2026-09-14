// SPDX-FileCopyrightText: 2026 Klima Protocol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";

import {Deploy} from "../script/Deploy.s.sol";
import {RelayFeeSkim} from "../src/RelayFeeSkim.sol";

contract DeployTest is Test {
    Deploy internal d;

    function setUp() public {
        d = new Deploy();
    }

    function test_canonicalValues() public view {
        assertEq(d.FEE_BPS(), 500);
        assertEq(d.FEE_SINK(), 0xf624f9Fe1D3165c5Ca32c7Fbdbf82f4a5b1D2d0e);
        assertEq(d.SALT(), keccak256("klimaprotocol.com/RelayFeeSkim/v1"));
    }

    function test_recordMatchesScript() public {
        string memory json = vm.readFile("verification/bytecode-hashes.json");
        assertEq(vm.parseJsonString(json, ".contract"), "src/RelayFeeSkim.sol:RelayFeeSkim");
        assertEq(vm.parseJsonAddress(json, ".create2Deployer"), CREATE2_FACTORY);
        assertEq(vm.parseJsonString(json, ".saltPreimage"), d.SALT_PREIMAGE());
        assertEq(vm.parseJsonBytes32(json, ".salt"), d.SALT());
        assertEq(vm.parseJsonBytes32(json, ".creationCodeKeccak"), keccak256(type(RelayFeeSkim).creationCode));
        assertEq(
            vm.parseJsonBytes32(json, ".runtimeTemplateKeccak"),
            keccak256(vm.getDeployedCode("RelayFeeSkim.sol:RelayFeeSkim"))
        );
        assertEq(vm.parseJsonUint(json, ".deployment.feeBps"), d.FEE_BPS());
        assertEq(vm.parseJsonAddress(json, ".deployment.feeSink"), d.FEE_SINK());
        assertEq(vm.parseJsonBytes(json, ".deployment.constructorArgs"), abi.encode(d.FEE_BPS(), d.FEE_SINK()));
        assertEq(vm.parseJsonAddress(json, ".deployment.address"), d.predict());
        assertEq(
            vm.parseJsonBytes32(json, ".deployment.runtimeKeccak"),
            keccak256(address(new RelayFeeSkim(d.FEE_BPS(), d.FEE_SINK())).code)
        );
    }

    function test_run_deploysAtPredictedAddress() public {
        address predicted = d.predict();
        assertEq(predicted.code.length, 0);

        assertEq(d.run(), predicted);

        assertEq(RelayFeeSkim(predicted).FEE_BPS(), d.FEE_BPS());
        assertEq(RelayFeeSkim(predicted).FEE_SINK(), d.FEE_SINK());
    }

    function test_run_isIdempotent() public {
        address first = d.run();
        bytes32 codehash = first.codehash;

        assertEq(d.run(), first);
        assertEq(first.codehash, codehash);
    }

    function test_run_failsWithoutDeployer() public {
        vm.etch(CREATE2_FACTORY, "");
        vm.expectRevert(bytes("CREATE2 deployer not present"));
        d.run();
    }
}
