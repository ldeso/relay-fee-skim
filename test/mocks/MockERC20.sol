// SPDX-FileCopyrightText: 2026 Klima Protocol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {RelayFeeSkim} from "../../src/RelayFeeSkim.sol";
import {IRelayEntrypoint} from "../../src/interfaces/IRelayEntrypoint.sol";
import {MockRelay} from "./MockRelay.sol";

abstract contract MockLedger {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    error InsufficientBalance();

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function _move(address from, address to, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

contract MockERC20 is MockLedger {
    string public name;

    constructor(string memory name_) {
        name = name_;
    }

    function transfer(address to, uint256 amount) external virtual returns (bool) {
        _move(msg.sender, to, amount);
        return true;
    }
}

/// @notice USDT style: `transfer` returns no data.
contract NoReturnERC20 is MockLedger {
    function transfer(address to, uint256 amount) external {
        _move(msg.sender, to, amount);
    }
}

contract ReturnsFalseERC20 is MockLedger {
    function transfer(address, uint256) external pure returns (bool) {
        return false;
    }
}

/// @notice Reenters `claimAndSkim` when the skimmer transfers, for itself or for `reentryToken` after topping
///         up its claim source. With `record` off an inner revert fails the transfer; with it on, the revert
///         data is stored in `lastRevert` and the transfer completes.
contract ReentrantERC20 is MockERC20 {
    RelayFeeSkim public immutable SKIMMER;
    address public immutable RELAY;
    address public reentryToken;
    uint256 public reentryTopUp;
    bool public record;
    bytes public lastRevert;
    bool public reentered;

    constructor(RelayFeeSkim skimmer, address relay) MockERC20("REENTRANT") {
        SKIMMER = skimmer;
        RELAY = relay;
        reentryToken = address(this);
    }

    function setReentryTarget(address token, uint256 topUp) external {
        reentryToken = token;
        reentryTopUp = topUp;
    }

    function setRecord(bool record_) external {
        record = record_;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        if (msg.sender == address(SKIMMER) && !reentered) {
            reentered = true;
            _reenter();
        }
        _move(msg.sender, to, amount);
        return true;
    }

    function _reenter() internal {
        if (reentryTopUp != 0) MockRelay(RELAY).setClaimable(reentryToken, reentryTopUp);

        address[] memory tokens = new address[](1);
        tokens[0] = reentryToken;
        IRelayEntrypoint.FeeClaim[] memory feeClaims = new IRelayEntrypoint.FeeClaim[](1);
        feeClaims[0] = IRelayEntrypoint.FeeClaim({votingRewardsManager: address(0xB0B), maxCheckpoints: 1});
        bytes memory call = abi.encodeCall(
            RelayFeeSkim.claimAndSkim, (RELAY, feeClaims, new IRelayEntrypoint.IncentiveClaim[](0), tokens)
        );

        (bool ok, bytes memory data) = address(SKIMMER).call(call);
        if (!record) {
            require(ok, "reentrant call reverted");
            return;
        }
        lastRevert = data;
        require(!ok, "reentrant call unexpectedly succeeded");
    }
}
