// SPDX-License-Identifier: MIT
pragma solidity >=0.8.15;

import {console2, Script} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {ConditionalTokens} from "src/token/ConditionalTokens.sol";

contract DeployConditionalTokens is BaseScript {
    function run() external {
        ConditionalTokens ctf = new ConditionalTokens();
        console2.log("ConditionalTokens deployed at:", address(ctf));
    }
}
