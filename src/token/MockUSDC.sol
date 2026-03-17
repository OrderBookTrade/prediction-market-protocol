// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("OrderbookTrade Mock USDC", "USDC") {
        _mint(msg.sender, 1_000_000 * 10 ** 6);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    // USDC has decimals 6
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
