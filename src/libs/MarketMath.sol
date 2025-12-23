// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MarketMath
 * @notice Math utilities for prediction market calculations
 */
library MarketMath {
    uint256 public constant SCALE = 1e18;

    /**
     * @notice Calculate shares for a given collateral amount based on current price
     * @dev Simplistic linear model for now, can be expanded to AMM logic
     */
    function collateralToShares(
        uint256 collateralAmount,
        uint256 price
    ) internal pure returns (uint256) {
        if (price == 0) return 0;
        return (collateralAmount * SCALE) / price;
    }

    /**
     * @notice Calculate collateral for a given share amount based on current price
     */
    function sharesToCollateral(
        uint256 shareAmount,
        uint256 price
    ) internal pure returns (uint256) {
        return (shareAmount * price) / SCALE;
    }
}
