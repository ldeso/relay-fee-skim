// SPDX-FileCopyrightText: 2026 Klima Protocol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {IERC20Minimal} from "../../src/interfaces/IERC20Minimal.sol";
import {IRelayEntrypoint} from "../../src/interfaces/IRelayEntrypoint.sol";

interface IMintable {
    function mint(address to, uint256 amount) external;
}

/// @notice Upstream semantics of the role gate, `pull`, `claimRewards` and the Voter's claim validation.
contract MockRelay {
    uint256 public constant COMPOUNDER = 1 << 2;
    uint256 public constant CONVERTER = 1 << 3;

    error NotAuthorized();
    error RewardExceedsBalance();
    error RecipientNotSet();
    error NoValueOnRootClaim();
    error TransferFailed();
    error EmptyClaimRewardsParams();
    error ZeroCheckpoints();

    mapping(address account => uint256 roles) public rolesOf;
    mapping(address token => uint256 accounted) public accountedBalance;
    mapping(address token => uint256 amount) public claimable;
    address[] internal _claimTokens;

    uint256 public claimCalls;

    function grantRoles(address account, uint256 roles) external {
        rolesOf[account] |= roles;
    }

    function revokeRoles(address account, uint256 roles) external {
        rolesOf[account] &= ~roles;
    }

    function hasAnyRole(address account, uint256 roles) public view returns (bool) {
        return rolesOf[account] & roles != 0;
    }

    function setAccountedBalance(address token, uint256 amount) external {
        accountedBalance[token] = amount;
    }

    function setClaimable(address token, uint256 amount) external {
        if (claimable[token] == 0 && amount != 0) _claimTokens.push(token);
        claimable[token] = amount;
    }

    function pull(address token, uint256 amount) external {
        if (!hasAnyRole(msg.sender, COMPOUNDER | CONVERTER)) revert NotAuthorized();
        if (amount > IERC20Minimal(token).balanceOf(address(this)) - accountedBalance[token]) {
            revert RewardExceedsBalance();
        }
        (bool ok, bytes memory data) = token.call(abi.encodeCall(IERC20Minimal.transfer, (msg.sender, amount)));
        if (!ok || !(data.length == 0 || (data.length >= 32 && abi.decode(data, (bool))))) revert TransferFailed();
    }

    function claimRewards(
        uint256 chainId,
        uint256,
        IRelayEntrypoint.FeeClaim[] calldata feeClaims,
        IRelayEntrypoint.IncentiveClaim[] calldata incentiveClaims
    ) external payable {
        if (chainId != block.chainid) {
            revert RecipientNotSet();
        }
        if (msg.value != 0) revert NoValueOnRootClaim();
        if (feeClaims.length == 0 && incentiveClaims.length == 0) revert EmptyClaimRewardsParams();
        for (uint256 i; i < feeClaims.length; ++i) {
            if (feeClaims[i].maxCheckpoints == 0) revert ZeroCheckpoints();
        }
        for (uint256 i; i < incentiveClaims.length; ++i) {
            if (incentiveClaims[i].maxCheckpoints == 0) revert ZeroCheckpoints();
        }

        claimCalls++;
        for (uint256 i; i < _claimTokens.length; ++i) {
            address token = _claimTokens[i];
            uint256 amount = claimable[token];
            if (amount == 0) continue;
            claimable[token] = 0;
            IMintable(token).mint(address(this), amount);
        }
    }
}

/// @notice `pull` is a no-op, so the skimmer's own transfer is the only one that runs.
contract NoopPullRelay {
    mapping(address token => uint256 amount) public claimable;

    function setClaimable(address token, uint256 amount) external {
        claimable[token] = amount;
    }

    function pull(address, uint256) external {}

    function claimRewards(
        uint256,
        uint256,
        IRelayEntrypoint.FeeClaim[] calldata feeClaims,
        IRelayEntrypoint.IncentiveClaim[] calldata
    ) external payable {
        // `votingRewardsManager` doubles as the token to mint.
        for (uint256 i; i < feeClaims.length; ++i) {
            address token = feeClaims[i].votingRewardsManager;
            uint256 amount = claimable[token];
            if (amount == 0) continue;
            claimable[token] = 0;
            IMintable(token).mint(address(this), amount);
        }
    }
}
