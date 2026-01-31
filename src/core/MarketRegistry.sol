// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MarketTypes} from "./MarketTypes.sol";
import {Errors} from "../libs/Errors.sol";

/**
 * @title MarketRegistry
 * @notice Central registry for all markets in the protocol
 */
contract MarketRegistry {
    address public adminController;

    mapping(uint256 => MarketTypes.MarketInfo) private _markets;
    uint256 private _marketCount;

    event MarketRegistered(uint256 indexed marketId, address indexed creator, address indexed oracle);
    event MarketStatusUpdated(uint256 indexed marketId, MarketTypes.MarketStatus status);

    constructor(address _adminController) {
        if (_adminController == address(0)) revert Errors.ZeroAddress();
        adminController = _adminController;
    }

    function registerMarket(
        address creator,
        address oracle,
        address collateralToken,
        uint256 outcomeCount,
        string calldata metadataURI
    ) external returns (uint256) {
        if (oracle == address(0) || collateralToken == address(0)) {
            revert Errors.ZeroAddress();
        }
        if (outcomeCount < 2) revert Errors.InvalidParameters();

        uint256 marketId = ++_marketCount;

        _markets[marketId] = MarketTypes.MarketInfo({
            id: marketId,
            creator: creator,
            oracle: oracle,
            collateralToken: collateralToken,
            outcomeCount: outcomeCount,
            totalLiquidity: 0,
            resolvedOutcome: 0,
            resolutionTimestamp: 0,
            status: MarketTypes.MarketStatus.Active,
            metadataURI: metadataURI
        });

        emit MarketRegistered(marketId, creator, oracle);
        return marketId;
    }

    function getMarket(uint256 marketId) external view returns (MarketTypes.MarketInfo memory) {
        return _markets[marketId];
    }

    function resolveMarket(uint256 marketId, uint256 outcome) external {
        MarketTypes.MarketInfo storage market = _markets[marketId];
        if (market.status == MarketTypes.MarketStatus.Resolved) {
            revert Errors.MarketAlreadyResolved();
        }

        market.resolvedOutcome = outcome;
        market.status = MarketTypes.MarketStatus.Resolved;
        market.resolutionTimestamp = block.timestamp;
    }
}
