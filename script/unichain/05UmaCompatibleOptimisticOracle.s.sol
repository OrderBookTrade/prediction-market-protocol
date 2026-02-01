// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2, Script} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {UmaCompatibleOptimisticOracle} from "src/oracle/UmaCompatibleOptimisticOracle.sol";

contract DeployUmaCompatibleOptimisticOracle is BaseScript {
    function run() external {
        uint256 defaultLiveness = 7200; // 2 hours
        UmaCompatibleOptimisticOracle oracle = new UmaCompatibleOptimisticOracle(
            defaultLiveness,
            msg.sender // Deployer as initial owner
        );
        console2.log("UmaCompatibleOptimisticOracle deployed at:", address(oracle));
    }
}
