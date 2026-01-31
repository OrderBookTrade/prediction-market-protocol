// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2, Script} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {AdminController} from "src/governance/AdminController.sol";

contract AdminControllerScript is BaseScript {
    function run() external {
        AdminController adminController = new AdminController(msg.sender);
        console2.log("AdminController deployed at:", address(adminController));
    }
}
