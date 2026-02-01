// SPDX-License-Identifier: MIT
pragma solidity >=0.8.15;

import {console2, Script} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {MockERC20} from "src/token/MockERC20.sol";

contract DeployMockERC20 is BaseScript {
    function run() external {
        MockERC20 usdc = new MockERC20();
        console2.log("MockUSDC deployed at:", address(usdc));
        console2.log("Initial supply:", usdc.totalSupply());
    }
}
