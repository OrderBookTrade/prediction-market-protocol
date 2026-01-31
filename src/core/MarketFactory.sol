// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MarketRegistry} from "./MarketRegistry.sol";
import {OutcomeTokenFactory} from "../outcome/OutcomeTokenFactory.sol";
import {Errors} from "../libs/Errors.sol";

/**
 * @title MarketFactory
 * @notice Factory for creating new prediction markets
 */
contract MarketFactory {
    address public registry;
    address public outcomeTokenFactory;
    address public adminController;

    event MarketCreated(uint256 indexed marketId, address indexed creator);

    constructor(address _registry, address _outcomeTokenFactory, address _adminController) {
        if (_registry == address(0) || _outcomeTokenFactory == address(0) || _adminController == address(0)) {
            revert Errors.ZeroAddress();
        }
        registry = _registry;
        outcomeTokenFactory = _outcomeTokenFactory;
        adminController = _adminController;
    }

    function createMarket(
        address oracle,
        address collateralToken,
        uint256 outcomeCount,
        string calldata metadataURI,
        string[] calldata outcomeTitles
    ) external returns (uint256) {
        if (outcomeTitles.length != outcomeCount) {
            revert Errors.InvalidParameters();
        }

        uint256 marketId =
            MarketRegistry(registry).registerMarket(msg.sender, oracle, collateralToken, outcomeCount, metadataURI);

        OutcomeTokenFactory(outcomeTokenFactory).createOutcomeTokens(marketId, outcomeTitles);

        emit MarketCreated(marketId, msg.sender);
        return marketId;
    }
}
