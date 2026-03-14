// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2, Script} from "forge-std/Script.sol";
import {CTFExchange} from "src/exchange/CTFExchange.sol";
import {ConditionalTokens} from "src/token/ConditionalTokens.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseScript} from "../BaseScript.s.sol";

contract PrepareMarket is BaseScript {
    // 10 USDC = 10 * 1e6 (USDC has 6 decimals)
    uint256 constant SPLIT_AMOUNT = 10 * 1e6;

    // How much USDC the taker pre-approves exchange to spend
    uint256 constant TAKER_APPROVE = 1000 * 1e6;

    address exchange = 0xA518f5394f4bc8b3DC7478FAF7614ADbCa96B27f;
    address ctf = 0xa69b5Ce1e56256cCF85d1910906Fe27Db6722e9f;
    address collateral = 0x348475f4B999069169AC6C5835f290caf0d2267b;
    bytes32 conditionId = 0x9e316d3bf403517b2d164f0b55ed21c5c767b6a4e83f650f6c4a2cc6c22c65ed;

    address public deployer = 0xDFF68F93792dDD4b539cC7179Dd04E648AB7660e;
    address public maker = 0xB077778149f450C44b15F879f15Bf2E21121A8C7;
    address public taker = 0x8E8d5f70025068940FBc3E9945932EA02fAC7aC5;

    function run() external {
        uint256 makerUsdc = IERC20(collateral).balanceOf(maker);
        console2.log("\nMaker USDC balance:", makerUsdc / 1e6, "USDC");

        // 1. approve
        // IERC20(collateral).approve(ctf, SPLIT_AMOUNT);

        // 2. split token  1 YES + 1 NO
        // spiltPosition();

        // 3. approve exchange
        approveExchange();
    }

    function spiltPosition() public {
        uint256[] memory partition = new uint256[](2);
        partition[0] = 1; // YES (index set bit 0)
        partition[1] = 2; // NO  (index set bit 1)
        ConditionalTokens(ctf).splitPosition(IERC20(collateral), bytes32(0), conditionId, partition, SPLIT_AMOUNT);
        console2.log("[2] Maker split", SPLIT_AMOUNT / 1e6, "USDC -> YES/NO tokens");
    }

    function approveExchange() public {
        ConditionalTokens(ctf).setApprovalForAll(exchange, true);
        console2.log("[3] Maker approved exchange for all CTF tokens");
    }
}

/**
 *
 *     // ── Taker: approve exchange to spend USDC ─────────────
 *     // (skip if maker == taker, i.e. same PRI_KEY used for both)
 *     if (maker != taker) {
 *         uint256 takerUsdc = IERC20(collateral).balanceOf(taker);
 *         console2.log("\nTaker USDC balance:", takerUsdc / 1e6, "USDC");
 *         require(takerUsdc > 0, "Taker needs some USDC on Base mainnet");
 *
 *         vm.startBroadcast(takerKey);
 *         uint256 approveAmt = takerUsdc < TAKER_APPROVE ? takerUsdc : TAKER_APPROVE;
 *         IERC20(collateral).approve(exchange, approveAmt);
 *         console2.log("[4] Taker approved exchange for", approveAmt / 1e6, "USDC");
 *         vm.stopBroadcast();
 *     } else {
 *         // Same account for maker & taker — also approve USDC for the taker side
 *         vm.startBroadcast(makerKey);
 *         IERC20(collateral).approve(exchange, TAKER_APPROVE);
 *         console2.log("[4] Maker/Taker (same acct) approved exchange for USDC");
 *         vm.stopBroadcast();
 *     }
 *
 *     console2.log("\n[SUCCESS] Market is ready for matchOrders!");
 *     console2.log("Next step: bash script/base/demo_loop.sh");
 */
