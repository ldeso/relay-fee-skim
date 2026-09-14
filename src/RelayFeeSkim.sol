// SPDX-FileCopyrightText: 2026 Klima Protocol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {IERC20Minimal} from "./interfaces/IERC20Minimal.sol";
import {IRelayEntrypoint} from "./interfaces/IRelayEntrypoint.sol";

/// @title RelayFeeSkim
/// @notice Takes a fixed fee from a Metadex Relay's rewards and forwards it to a fixed sink. Sits in the
///         Relay's `converter` slot for `pull`; permissionless, no owner, no storage, no swaps.
contract RelayFeeSkim {
    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_FEE_BPS = 1_000;
    uint256 public immutable FEE_BPS;
    address public immutable FEE_SINK;
    bool transient _locked;

    /// @param base Claim delta the fee was computed on.
    event Skimmed(address indexed relay, address indexed token, uint256 base, uint256 fee);

    error FeeOutOfRange();
    error ZeroAddress();
    error TokensNotSorted();
    error NoFee();
    error TransferFailed();
    error Reentrancy();

    constructor(uint256 feeBps, address feeSink) {
        if (feeBps == 0 || feeBps > MAX_FEE_BPS) revert FeeOutOfRange();
        if (feeSink == address(0)) revert ZeroAddress();
        FEE_BPS = feeBps;
        FEE_SINK = feeSink;
    }

    modifier nonReentrant() {
        if (_locked) revert Reentrancy();
        _locked = true;
        _;
        _locked = false;
    }

    /// @notice Claim the Relay's root-chain rewards and take the fee on each token's balance delta.
    /// @param tokens Strictly ascending, so no token is taxed twice.
    function claimAndSkim(
        address relay,
        IRelayEntrypoint.FeeClaim[] calldata feeClaims,
        IRelayEntrypoint.IncentiveClaim[] calldata incentiveClaims,
        address[] calldata tokens
    ) external nonReentrant returns (uint256[] memory fees) {
        uint256 n = tokens.length;
        uint256[] memory before = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            if (i != 0 && tokens[i] <= tokens[i - 1]) revert TokensNotSorted();
            before[i] = IERC20Minimal(tokens[i]).balanceOf(relay);
        }

        IRelayEntrypoint(relay).claimRewards(block.chainid, 0, feeClaims, incentiveClaims);

        fees = new uint256[](n);
        bool any;
        for (uint256 i; i < n; ++i) {
            uint256 balance = IERC20Minimal(tokens[i]).balanceOf(relay);
            uint256 delta = balance > before[i] ? balance - before[i] : 0;
            fees[i] = _take(relay, tokens[i], delta);
            if (fees[i] != 0) any = true;
        }
        if (!any) revert NoFee();
    }

    /// @dev Forwards the whole held balance, not just `fee`, so nothing strands here.
    function _take(address relay, address token, uint256 base) internal returns (uint256 fee) {
        fee = (base * FEE_BPS) / BPS;
        if (fee == 0) return 0;

        IRelayEntrypoint(relay).pull(token, fee);
        _safeTransfer(token, FEE_SINK, IERC20Minimal(token).balanceOf(address(this)));

        emit Skimmed(relay, token, base, fee);
    }

    /// @dev Accepts no return data or `true`.
    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(abi.encodeCall(IERC20Minimal.transfer, (to, amount)));
        if (!ok || !(data.length == 0 || (data.length >= 32 && abi.decode(data, (bool))))) revert TransferFailed();
    }
}
