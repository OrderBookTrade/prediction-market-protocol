// SPDX-License-Identifier: MIT
pragma solidity >=0.8.15;

import {console2, Script} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {UmaCtfAdapter} from "src/oracle/UmaCtfAdapter.sol";
import {Finder} from "src/oracle/Finder.sol";
import {SimpleAddressWhitelist} from "src/oracle/SimpleAddressWhitelist.sol";

contract DeployUmaCtfAdapter is BaseScript {
    address _ctf = 0x618F09386e484Eeb3bD76aB927ae2DF1a3425feC;
    address _finder = 0xc6d745e9938F5B6F9cf8dA4D9b573Dc252dc834f;
    address _optimisticOracle = 0x5d77a932C2efACABF990a54A8eF22F2aa32444e6;

    function run() external {
        //1. UMA Finder
        // Finder finder = new Finder();
        // console2.log("Finder deployed at:", address(finder));

        // //2. Whitelist
        // SimpleAddressWhitelist whitelist = new SimpleAddressWhitelist(true);
        // console2.log("Whitelist deployed at:", address(whitelist));

        // //3. Adapter
        UmaCtfAdapter adapter = new UmaCtfAdapter(_ctf, _finder, _optimisticOracle);
        console2.log("UmaCtfAdapter deployed at:", address(adapter));
    }

    function deployFinder() public {
        Finder finder = new Finder();
        console2.log("Finder deployed at:", address(finder));
    }

    function deployWhitelist() public {
        SimpleAddressWhitelist whitelist = new SimpleAddressWhitelist(true);
        console2.log("Whitelist deployed at:", address(whitelist));
    }

    function deployAdapter() public {
        UmaCtfAdapter adapter = new UmaCtfAdapter(_ctf, _finder, _optimisticOracle);
        console2.log("UmaCtfAdapter deployed at:", address(adapter));
    }
}
