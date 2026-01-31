// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title OutcomeToken
 * @notice ERC20 representing a share in a specific market outcome
 */
contract OutcomeToken is ERC20, Ownable {
    uint256 public marketId;
    uint256 public outcomeIndex;

    constructor(string memory name, string memory symbol, uint256 _marketId, uint256 _outcomeIndex)
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        marketId = _marketId;
        outcomeIndex = _outcomeIndex;
    }

    /**
     * @notice Mint tokens to a user
     * @dev Restricted to the Factory or SettlementEngine
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens from a user
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
