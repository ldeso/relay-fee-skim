// SPDX-FileCopyrightText: 2026 Klima Protocol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";

import {IRelayEntrypoint} from "../src/interfaces/IRelayEntrypoint.sol";
import {IRelayEntrypoint as UpstreamIRelayEntrypoint} from "./upstream/IRelayEntrypoint.sol";

/// @notice Pins `pull` and `claimRewards` against literals, keccak256 of the signatures, the vendored upstream
///         files (compiled where possible, otherwise as text) and the table in UPSTREAM.md.
contract SelectorsTest is Test {
    bytes4 internal constant PULL = 0xf2d5d56b;
    bytes4 internal constant CLAIM_REWARDS = 0xfa6a8ba9;

    function test_selectors_literals() public pure {
        assertEq(IRelayEntrypoint.pull.selector, PULL);
        assertEq(IRelayEntrypoint.claimRewards.selector, CLAIM_REWARDS);
    }

    function test_selectors_keccak() public pure {
        assertEq(IRelayEntrypoint.pull.selector, bytes4(keccak256("pull(address,uint256)")));
        assertEq(
            IRelayEntrypoint.claimRewards.selector,
            bytes4(keccak256("claimRewards(uint256,uint256,(address,uint256)[],(address,uint256,uint256)[])"))
        );
    }

    function test_selectors_upstreamCompiled() public pure {
        assertEq(IRelayEntrypoint.pull.selector, UpstreamIRelayEntrypoint.pull.selector);
    }

    function test_selectors_upstreamMdTable() public view {
        string memory md = vm.readFile("test/upstream/UPSTREAM.md");
        _assertRow(md, "pull(address,uint256)", IRelayEntrypoint.pull.selector);
        _assertRow(
            md,
            "claimRewards(uint256,uint256,(address,uint256)[],(address,uint256,uint256)[])",
            IRelayEntrypoint.claimRewards.selector
        );
    }

    function _assertRow(string memory md, string memory signature, bytes4 selector) internal pure {
        string memory row = string.concat("| `", signature, "` | `", vm.toString(abi.encodePacked(selector)), "` |");
        assertTrue(vm.contains(md, row), string.concat("UPSTREAM.md row missing or stale: ", row));
    }

    function test_selectors_upstreamText() public view {
        string memory entrypoint = vm.readFile("test/upstream/IRelayEntrypoint.sol");
        assertTrue(vm.contains(entrypoint, "function pull(address _token, uint256 _amount) external;"));

        string memory relay = vm.readFile("test/upstream/IRelay.sol");
        assertTrue(
            vm.contains(
                relay,
                "function claimRewards(\n" "    uint256 _chainId,\n" "    uint256 _gasLimit,\n"
                "    ILeafVoter.FeeClaim[] calldata _feeClaims,\n"
                "    ILeafVoter.IncentiveClaim[] calldata _incentiveClaims\n" "  ) external payable;"
            )
        );

        string memory voter = vm.readFile("test/upstream/ILeafVoter.sol");
        assertTrue(
            vm.contains(
                voter, "struct FeeClaim {\n" "    address votingRewardsManager;\n" "    uint256 maxCheckpoints;\n" "  }"
            )
        );
        assertTrue(
            vm.contains(
                voter,
                "struct IncentiveClaim {\n" "    address votingRewardsManager;\n" "    uint256 programId;\n"
                "    uint256 maxCheckpoints;\n" "  }"
            )
        );
    }
}
