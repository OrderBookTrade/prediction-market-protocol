// SPDX-License-Identifier: MIT
pragma solidity >=0.8.15;

import {console2, Script} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {OutcomeTokenFactory} from "src/outcome/OutcomeTokenFactory.sol";

contract DeployOutcomeTokenFactory is BaseScript {
    function run() external {
        OutcomeTokenFactory outcomeTokenFactory = new OutcomeTokenFactory();
        console2.log("OutcomeTokenFactory deployed at:", address(outcomeTokenFactory));
    }
}
