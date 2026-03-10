// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2, Script} from "forge-std/Script.sol";
import {CTFExchange} from "src/exchange/CTFExchange.sol";
import {ConditionalTokens} from "src/token/ConditionalTokens.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployBase
 * @notice Deploy ConditionalTokens + CTFExchange on Base Mainnet using real USDC.
 *         Does NOT split positions — run 03_PrepareMarket.s.sol after this.
 *
 * Prerequisites:
 *   PRI_KEY — deployer (also becomes the operator / matching engine)
 *
 * Usage:
 *   # Dry-run (no broadcast)
 *   forge script script/base/02_DeployBase.s.sol:DeployBase \
 *     --rpc-url $BASE_RPC \
 *     --private-key $PRI_KEY \
 *     -vvvv
 *
 *   # Broadcast + verify
 *   forge script script/base/02_DeployBase.s.sol:DeployBase \
 *     --rpc-url $BASE_RPC \
 *     --broadcast \
 *     --verify \
 *     --private-key $PRI_KEY \
 *     -vvvv
 *
 * After running, copy the printed env vars to .env, then run:
 *   forge script script/base/03_PrepareMarket.s.sol:PrepareMarket ...
 *   bash script/base/demo_loop.sh
 */
contract DeployBase is Script {
    // ── Base Mainnet — real USDC (Circle native) ─────────────
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // ── State (populated during run) ─────────────────────────
    address public ctf;
    address public exchange;
    bytes32 public conditionId;
    uint256 public tokenIdYes;
    uint256 public tokenIdNo;

    function run() external {
        uint256 deployerKey = vm.envUint("PRI_KEY");
        address deployer    = vm.addr(deployerKey);

        console2.log("\n=====================================================");
        console2.log(" Base Mainnet - Prediction Market - Deploy");
        console2.log("=====================================================");
        console2.log("Chain ID  :", block.chainid);
        console2.log("Deployer  :", deployer);
        console2.log("Collateral:", USDC);

        vm.startBroadcast(deployerKey);

        // 1. Deploy ConditionalTokens
        ctf = address(new ConditionalTokens());
        console2.log("\n[1] ConditionalTokens:", ctf);

        // 2. Deploy CTFExchange (proxyFactory=0, safeFactory=0)
        exchange = address(new CTFExchange(USDC, ctf, address(0), address(0)));
        console2.log("[2] CTFExchange      :", exchange);

        // 3. Add deployer as operator (matching engine)
        CTFExchange(exchange).addOperator(deployer);
        console2.log("[3] Operator added   :", deployer);

        // 4. Prepare prediction market condition
        //    "Will ETH reach $10k in 2026?" — oracle = deployer for demo
        bytes32 questionId = keccak256(
            abi.encodePacked("Will ETH reach $10k in 2026?", uint256(block.chainid))
        );
        ConditionalTokens(ctf).prepareCondition(deployer, questionId, 2);
        conditionId = ConditionalTokens(ctf).getConditionId(deployer, questionId, 2);
        console2.log("[4] conditionId      :", vm.toString(conditionId));

        // 5. Compute YES / NO position IDs
        bytes32 colIdYes = ConditionalTokens(ctf).getCollectionId(bytes32(0), conditionId, 1);
        bytes32 colIdNo  = ConditionalTokens(ctf).getCollectionId(bytes32(0), conditionId, 2);
        tokenIdYes = ConditionalTokens(ctf).getPositionId(IERC20(USDC), colIdYes);
        tokenIdNo  = ConditionalTokens(ctf).getPositionId(IERC20(USDC), colIdNo);
        console2.log("[5] tokenIdYes       :", tokenIdYes);
        console2.log("    tokenIdNo        :", tokenIdNo);

        // 6. Register YES/NO token pair on exchange
        CTFExchange(exchange).registerToken(tokenIdYes, tokenIdNo, conditionId);
        console2.log("[6] Tokens registered on exchange");

        vm.stopBroadcast();

        // ── Print env summary ────────────────────────────────
        console2.log("\n=====================================================");
        console2.log(" COPY INTO YOUR .env FILE");
        console2.log("=====================================================");
        console2.log("CTF_EXCHANGE=%s",  exchange);
        console2.log("CTF=%s",           ctf);
        console2.log("COLLATERAL=%s",    USDC);
        console2.log("TOKEN_ID_YES=%s",  vm.toString(bytes32(tokenIdYes)));
        console2.log("TOKEN_ID_NO=%s",   vm.toString(bytes32(tokenIdNo)));
        console2.log("CONDITION_ID=%s",  vm.toString(conditionId));
        console2.log("=====================================================");
        console2.log("Next step: forge script script/base/03_PrepareMarket.s.sol:PrepareMarket");
    }
}
