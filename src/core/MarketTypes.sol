// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MarketTypes
 * @notice Enums and structs used across the Prediction Market Protocol
 */
library MarketTypes {
    enum MarketStatus {
        Active,
        Paused,
        Resolved,
        Cancelled
    }

    struct MarketInfo {
        uint256 id;
        address creator;
        address oracle;
        address collateralToken;
        uint256 outcomeCount;
        uint256 totalLiquidity;
        uint256 resolvedOutcome;
        uint256 resolutionTimestamp;
        MarketStatus status;
        string metadataURI;
    }
}
