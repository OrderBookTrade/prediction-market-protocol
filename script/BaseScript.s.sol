// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2, Script} from "forge-std/Script.sol";

// Chain Name	Unichain Sepolia
// Chain ID	1301
// RPC URL	https://sepolia.unichain.org (rate limited, not for production)
// Currency Symbol	ETH
// Block Explorer	https://sepolia.uniscan.xyz/

contract BaseScript is Script {
    function setUp() public {
        vm.createSelectFork("https://sepolia.unichain.org");
        uint256 deployerPrivateKey = vm.envUint("PRI_KEY");
        vm.startBroadcast(deployerPrivateKey);
    }
}
