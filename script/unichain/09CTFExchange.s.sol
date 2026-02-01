// SPDX-License-Identifier: MIT
pragma solidity >=0.8.15;

import {console2, Script} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {CTFExchange} from "src/exchange/CTFExchange.sol";

contract DeployCTFExchange is BaseScript {
    address _collateral;   
    address _ctf;          
    address _proxyFactory; 
    address _safeFactory;  

    function run() external {
        CTFExchange exchange = new CTFExchange(
            _collateral,
            _ctf,
            _proxyFactory,
            _safeFactory
        );
        console2.log("CTFExchange deployed at:", address(exchange));
        console2.log("  Collateral:", _collateral);
        console2.log("  CTF:", _ctf);
        console2.log("  ProxyFactory:", _proxyFactory);
        console2.log("  SafeFactory:", _safeFactory);
    }
}
