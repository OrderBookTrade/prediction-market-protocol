// SPDX-License-Identifier: MIT
pragma solidity >=0.8.15;

import {console2, Script} from "forge-std/Script.sol";

// Chain Name	Unichain Sepolia
// Chain ID	1301
// RPC URL	https://sepolia.unichain.org (rate limited, not for production)
// Currency Symbol	ETH
// Block Explorer	https://sepolia.uniscan.xyz/

// Chain Name Base Sepolia
// https://base-sepolia-rpc.publicnode.com

contract BaseScript is Script {
    function setUp() public virtual {
        vm.createSelectFork("https://base-sepolia-rpc.publicnode.com");
        // vm.createSelectFork("https://mainnet.base.org");
        uint256 deployerPrivateKey = vm.envUint("PRI_KEY");
        vm.startBroadcast(deployerPrivateKey);
    }
}
