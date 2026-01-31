// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OutcomeToken} from "./OutcomeToken.sol";
import {Errors} from "../libs/Errors.sol";

/**
 * @title OutcomeTokenFactory
 * @notice Factory for deploying outcome tokens for a market
 */
contract OutcomeTokenFactory {
    address public marketFactory;

    // marketId => outcomeIndex => OutcomeToken address
    mapping(uint256 => mapping(uint256 => address)) public marketOutcomeTokens;

    event OutcomeTokensCreated(uint256 indexed marketId, address[] tokens);

    constructor() {}

    function setMarketFactory(address _marketFactory) external {
        if (marketFactory != address(0)) revert Errors.Unauthorized();
        marketFactory = _marketFactory;
    }

    modifier onlyMarketFactory() {
        if (msg.sender != marketFactory) revert Errors.Unauthorized();
        _;
    }

    function createOutcomeTokens(uint256 marketId, string[] calldata titles)
        external
        onlyMarketFactory
        returns (address[] memory)
    {
        uint256 count = titles.length;
        address[] memory tokens = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            OutcomeToken token = new OutcomeToken(
                string(abi.encodePacked("Outcome ", titles[i])),
                string(abi.encodePacked("OUT-", uint2str(marketId), "-", uint2str(i))),
                marketId,
                i
            );
            tokens[i] = address(token);
            marketOutcomeTokens[marketId][i] = address(token);
        }

        emit OutcomeTokensCreated(marketId, tokens);
        return tokens;
    }

    function getOutcomeToken(uint256 marketId, uint256 outcomeIndex) external view returns (address) {
        return marketOutcomeTokens[marketId][outcomeIndex];
    }

    // Helper to convert uint to string for token symbols
    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
