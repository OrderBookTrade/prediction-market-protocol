// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Errors
 * @notice Centralized error definitions for the protocol
 */
library Errors {
    error Unauthorized();
    error ZeroAddress();
    error InvalidParameters();
    error MarketNotResolved();
    error MarketAlreadyResolved();
    error InsufficientBalance();
    error TransferFailed();
    error InvalidOutcome();
    error DeadlinePassed();
    error MarketPaused();
}
