// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SimpleCTHelpers
 * @notice Simplified version of CTHelpers without elliptic curve operations
 * @dev This version uses simple keccak256 hashing instead of EC point addition
 *      Trade-off: Loses commutative property for combining conditions
 *      Benefit: Much lower gas costs (~1000x cheaper)
 *      Use case: Simple binary markets (like Polymarket) where conditions are not combined
 */
library SimpleCTHelpers {
    /// @dev Constructs a condition ID from an oracle, a question ID, and the outcome slot count for the question.
    function getConditionId(address oracle, bytes32 questionId, uint256 outcomeSlotCount)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(oracle, questionId, outcomeSlotCount));
    }

    /// @dev Constructs a collection ID using simple hashing (no elliptic curve)
    /// @notice This is NOT commutative like the original Gnosis implementation
    /// For simple markets where you don't combine conditions, this is sufficient
    function getCollectionId(bytes32 parentCollectionId, bytes32 conditionId, uint256 indexSet)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(parentCollectionId, conditionId, indexSet));
    }

    /// @dev Constructs a position ID from a collateral token and an outcome collection
    function getPositionId(IERC20 collateralToken, bytes32 collectionId) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(collateralToken, collectionId)));
    }
}
