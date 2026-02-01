// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2, Script} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {MarketRegistry} from "src/core/MarketRegistry.sol";

contract DeployMarketRegistry is BaseScript {
    address _adminController;

    function run() external {
        MarketRegistry marketRegistry = new MarketRegistry(_adminController);
        console2.log("MarketRegistry deployed at:", address(marketRegistry));
    }
}
