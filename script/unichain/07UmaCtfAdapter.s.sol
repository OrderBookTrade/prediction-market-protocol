// SPDX-License-Identifier: MIT
pragma solidity >=0.8.15;

import {console2, Script} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {UmaCtfAdapter} from "src/oracle/UmaCtfAdapter.sol";

contract DeployUmaCtfAdapter is BaseScript {
    
    address _ctf;            
    address _finder;           
    address _optimisticOracle; 

    function run() external {
        UmaCtfAdapter adapter = new UmaCtfAdapter(
            _ctf,
            _finder,
            _optimisticOracle
        );
        console2.log("UmaCtfAdapter deployed at:", address(adapter));
    }
}
