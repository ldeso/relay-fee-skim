// SPDX-FileCopyrightText: 2026 Klima Protocol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

interface IRelayEntrypoint {
    struct FeeClaim {
        address votingRewardsManager;
        uint256 maxCheckpoints;
    }

    struct IncentiveClaim {
        address votingRewardsManager;
        uint256 programId;
        uint256 maxCheckpoints;
    }

    function pull(address token, uint256 amount) external;

    function claimRewards(
        uint256 chainId,
        uint256 gasLimit,
        FeeClaim[] calldata feeClaims,
        IncentiveClaim[] calldata incentiveClaims
    ) external payable;
}
