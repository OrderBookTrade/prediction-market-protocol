// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/core/MarketRegistry.sol";
import "../src/outcome/OutcomeTokenFactory.sol";
import "../src/core/MarketFactory.sol";

contract SmokeTest is Test {
    MarketRegistry public registry;
    OutcomeTokenFactory public tokenFactory;
    MarketFactory public marketFactory;

    address public admin = address(0x1);
    address public oracle = address(0x2);
    address public collateral = address(0x3);

    function setUp() public {
        vm.startPrank(admin);

        // 1. Deploy Registry
        registry = new MarketRegistry(admin);

        // 2. Deploy Token Factory
        tokenFactory = new OutcomeTokenFactory();

        // 3. Deploy Market Factory
        marketFactory = new MarketFactory(address(registry), address(tokenFactory), admin);

        // 4. Link Token Factory to Market Factory
        tokenFactory.setMarketFactory(address(marketFactory));

        vm.stopPrank();
    }

    function testDeployMarket() public {
        vm.startPrank(admin);

        string[] memory titles = new string[](2);
        titles[0] = "YES";
        titles[1] = "NO";

        uint256 marketId = marketFactory.createMarket(oracle, collateral, 2, "ipfs://metadata", titles);

        assertEq(marketId, 1);

        vm.stopPrank();
    }
}
