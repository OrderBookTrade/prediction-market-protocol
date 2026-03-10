// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2, Script} from "forge-std/Script.sol";
import {CTFExchange} from "src/exchange/CTFExchange.sol";
import {ConditionalTokens} from "src/token/ConditionalTokens.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PrepareMarket
 * @notice One-time setup: maker splits USDC -> YES/NO tokens, both sides approve exchange.
 *         Run this ONCE after 02_DeployBase.s.sol.
 *
 * Prerequisites (.env must contain):
 *   PRI_KEY             — deployer / operator
 *   MAKER_PRIVATE_KEY   — maker account (needs real USDC on Base mainnet)
 *   TAKER_PRIVATE_KEY   — taker account (needs real USDC on Base mainnet)
 *   CTF_EXCHANGE        — from 02_DeployBase output
 *   CTF                 — from 02_DeployBase output
 *   COLLATERAL          — 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
 *   CONDITION_ID        — from 02_DeployBase output
 *
 * Usage:
 *   forge script script/base/03_PrepareMarket.s.sol:PrepareMarket \
 *     --rpc-url $BASE_RPC \
 *     --broadcast \
 *     --private-key $PRI_KEY \
 *     -vvvv
 */
contract PrepareMarket is Script {
    // Amount of USDC to split into YES+NO tokens for the maker
    // 10 USDC = 10 * 1e6 (USDC has 6 decimals)
    uint256 constant SPLIT_AMOUNT = 10 * 1e6;

    // How much USDC the taker pre-approves exchange to spend
    uint256 constant TAKER_APPROVE = 1000 * 1e6;

    function run() external {
        // ── Read env ──────────────────────────────────────────
        address exchange    = vm.envAddress("CTF_EXCHANGE");
        address ctf         = vm.envAddress("CTF");
        address collateral  = vm.envAddress("COLLATERAL");
        bytes32 conditionId = vm.envBytes32("CONDITION_ID");

        uint256 makerKey = vm.envOr("MAKER_PRIVATE_KEY", vm.envUint("PRI_KEY"));
        uint256 takerKey = vm.envOr("TAKER_PRIVATE_KEY", vm.envUint("PRI_KEY"));
        address maker    = vm.addr(makerKey);
        address taker    = vm.addr(takerKey);

        console2.log("\n=====================================================");
        console2.log(" Base Mainnet - Prepare Market");
        console2.log("=====================================================");
        console2.log("Exchange   :", exchange);
        console2.log("CTF        :", ctf);
        console2.log("Collateral :", collateral);
        console2.log("Maker      :", maker);
        console2.log("Taker      :", taker);

        // ── Maker: check balance ──────────────────────────────
        uint256 makerUsdc = IERC20(collateral).balanceOf(maker);
        console2.log("\nMaker USDC balance:", makerUsdc / 1e6, "USDC");
        require(makerUsdc >= SPLIT_AMOUNT, "Maker needs at least 10 USDC on Base mainnet");

        // ── Maker: approve CTF to spend USDC, then splitPosition ─
        vm.startBroadcast(makerKey);

        IERC20(collateral).approve(ctf, SPLIT_AMOUNT);
        console2.log("[1] Maker approved CTF to spend", SPLIT_AMOUNT / 1e6, "USDC");

        uint256[] memory partition = new uint256[](2);
        partition[0] = 1; // YES (index set bit 0)
        partition[1] = 2; // NO  (index set bit 1)
        ConditionalTokens(ctf).splitPosition(
            IERC20(collateral), bytes32(0), conditionId, partition, SPLIT_AMOUNT
        );
        console2.log("[2] Maker split", SPLIT_AMOUNT / 1e6, "USDC -> YES/NO tokens");

        // Maker approves exchange to move outcome tokens
        ConditionalTokens(ctf).setApprovalForAll(exchange, true);
        console2.log("[3] Maker approved exchange for all CTF tokens");

        vm.stopBroadcast();

        // ── Taker: approve exchange to spend USDC ─────────────
        // (skip if maker == taker, i.e. same PRI_KEY used for both)
        if (maker != taker) {
            uint256 takerUsdc = IERC20(collateral).balanceOf(taker);
            console2.log("\nTaker USDC balance:", takerUsdc / 1e6, "USDC");
            require(takerUsdc > 0, "Taker needs some USDC on Base mainnet");

            vm.startBroadcast(takerKey);
            uint256 approveAmt = takerUsdc < TAKER_APPROVE ? takerUsdc : TAKER_APPROVE;
            IERC20(collateral).approve(exchange, approveAmt);
            console2.log("[4] Taker approved exchange for", approveAmt / 1e6, "USDC");
            vm.stopBroadcast();
        } else {
            // Same account for maker & taker — also approve USDC for the taker side
            vm.startBroadcast(makerKey);
            IERC20(collateral).approve(exchange, TAKER_APPROVE);
            console2.log("[4] Maker/Taker (same acct) approved exchange for USDC");
            vm.stopBroadcast();
        }

        console2.log("\n[SUCCESS] Market is ready for matchOrders!");
        console2.log("Next step: bash script/base/demo_loop.sh");
    }
}
