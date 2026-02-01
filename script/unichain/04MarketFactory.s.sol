// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2, Script} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {MarketFactory} from "src/core/MarketFactory.sol";

contract DeployMarketFactory is BaseScript {
    address _marketRegistry;
    address _outcomeTokenFactory;
    address _adminController;

    function run() external {
        MarketFactory marketFactory = new MarketFactory(_marketRegistry, _outcomeTokenFactory, _adminController);
        console2.log("MarketFactory deployed at:", address(marketFactory));
    }
}
