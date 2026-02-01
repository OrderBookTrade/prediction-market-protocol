// SPDX-License-Identifier: MIT
pragma solidity >=0.8.15;

import {console2, Script} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {CTFExchange} from "src/exchange/CTFExchange.sol";

contract DeployCTFExchange is BaseScript {
    // usdc token
    address _collateral = 0xE5687DB12c99F99bCbC165643d7FeF2C0139aa92;
    address _ctf = 0x9d8E5bC640338E1054C540668712De69Fe39f057;
    address _proxyFactory = address(0);
    address _safeFactory = address(0);

    function run() external {
        CTFExchange exchange = new CTFExchange(_collateral, _ctf, _proxyFactory, _safeFactory);
        console2.log("CTFExchange deployed at:", address(exchange));
        console2.log("  Collateral:", _collateral);
        console2.log("  CTF:", _ctf);
        console2.log("  ProxyFactory:", _proxyFactory);
        console2.log("  SafeFactory:", _safeFactory);
    }
}
