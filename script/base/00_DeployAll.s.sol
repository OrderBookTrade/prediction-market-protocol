// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2, Script} from "forge-std/Script.sol";
import {CTFExchange} from "src/exchange/CTFExchange.sol";
import {ConditionalTokens} from "src/token/ConditionalTokens.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// ─────────────────────────────────────────────────────────────
//  Inline MockUSDC — open mint, 6 decimals (testnet only!)
// ─────────────────────────────────────────────────────────────
contract MockUSDC is ERC20 {
    uint8 private immutable _dec;

    constructor() ERC20("Mock USDC", "mUSDC") {
        _dec = 6;
    }

    function decimals() public view override returns (uint8) { return _dec; }

    /// @notice Anyone can mint on testnet
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// ─────────────────────────────────────────────────────────────
/**
 * @title DeployAll
 * @notice One-shot script: deploys MockUSDC + ConditionalTokens + CTFExchange,
 *         prepares a prediction market, and funds maker/taker accounts.
 *
 * Usage:
 *   forge script script/base/00_DeployAll.s.sol:DeployAll \
 *     --rpc-url $BASE_SEPOLIA_RPC \
 *     --broadcast \
 *     --private-key $PRI_KEY \
 *     -vvvv
 *
 * After running, add the printed values to your .env and then run:
 *   bash script/base/demo_loop.sh
 */
contract DeployAll is Script {
    // ── Config ──────────────────────────────────────────────
    uint256 constant FUND_AMOUNT  = 10_000 * 1e6; // 10,000 mock USDC
    uint256 constant SPLIT_AMOUNT =  5_000 * 1e6; // 5,000 split into YES/NO tokens

    // ── State (set during run) ───────────────────────────────
    address public collateral;
    address public ctf;
    address public exchange;
    bytes32 public conditionId;
    uint256 public tokenIdYes;
    uint256 public tokenIdNo;

    // Keys
    uint256 public deployerKey;
    uint256 public makerKey;
    uint256 public takerKey;
    address public deployer;
    address public maker;
    address public taker;

    function run() external {
        // Load keys
        deployerKey = vm.envUint("PRI_KEY");
        makerKey    = vm.envOr("MAKER_PRIVATE_KEY", deployerKey);
        takerKey    = vm.envOr("TAKER_PRIVATE_KEY", deployerKey);
        deployer    = vm.addr(deployerKey);
        maker       = vm.addr(makerKey);
        taker       = vm.addr(takerKey);

        console2.log("\n=====================================================");
        console2.log(" Base Sepolia - Prediction Market - Full Deploy");
        console2.log("=====================================================");
        console2.log("Chain ID :", block.chainid);
        console2.log("Deployer :", deployer);
        console2.log("Maker    :", maker);
        console2.log("Taker    :", taker);

        // ── Step 1: Deploy contracts (as deployer) ───────────
        vm.startBroadcast(deployerKey);

        collateral = address(new MockUSDC());
        console2.log("\n[1] MockUSDC        :", collateral);

        ctf = address(new ConditionalTokens());
        console2.log("[2] ConditionalTokens:", ctf);

        exchange = address(new CTFExchange(collateral, ctf, address(0), address(0)));
        console2.log("[3] CTFExchange      :", exchange);

        // Add operator (deployer == matching engine)
        CTFExchange(exchange).addOperator(deployer);
        console2.log("[4] Operator added   :", deployer);

        // Prepare market: "Will ETH reach $10k in 2026?"
        bytes32 questionId = keccak256(abi.encodePacked("Will ETH reach $10k in 2026?", uint256(block.chainid)));
        ConditionalTokens(ctf).prepareCondition(deployer, questionId, 2);
        conditionId = ConditionalTokens(ctf).getConditionId(deployer, questionId, 2);
        console2.log("[5] Condition ID     :", vm.toString(conditionId));

        // Compute YES / NO token IDs
        bytes32 colIdYes = ConditionalTokens(ctf).getCollectionId(bytes32(0), conditionId, 1);
        bytes32 colIdNo  = ConditionalTokens(ctf).getCollectionId(bytes32(0), conditionId, 2);
        tokenIdYes = ConditionalTokens(ctf).getPositionId(IERC20(collateral), colIdYes);
        tokenIdNo  = ConditionalTokens(ctf).getPositionId(IERC20(collateral), colIdNo);
        console2.log("[6] tokenIdYes       :", tokenIdYes);
        console2.log("    tokenIdNo        :", tokenIdNo);

        // Register tokens on exchange
        CTFExchange(exchange).registerToken(tokenIdYes, tokenIdNo, conditionId);
        console2.log("[7] Tokens registered on exchange");

        // Mint mock USDC to maker and taker
        MockUSDC(collateral).mint(maker, FUND_AMOUNT);
        MockUSDC(collateral).mint(taker, FUND_AMOUNT);
        console2.log("[8] Minted", FUND_AMOUNT / 1e6, "mUSDC to maker & taker");

        vm.stopBroadcast();

        // ── Step 2: Maker splits USDC -> YES+NO tokens ───────
        vm.startBroadcast(makerKey);
        IERC20(collateral).approve(ctf, SPLIT_AMOUNT);
        uint256[] memory partition = new uint256[](2);
        partition[0] = 1; partition[1] = 2;
        ConditionalTokens(ctf).splitPosition(
            IERC20(collateral), bytes32(0), conditionId, partition, SPLIT_AMOUNT
        );
        // Approve exchange to move maker's outcome tokens
        ConditionalTokens(ctf).setApprovalForAll(exchange, true);
        vm.stopBroadcast();
        console2.log("[9] Maker split USDC -> YES/NO and approved exchange");

        // ── Step 3: Taker approves exchange to spend USDC ───
        vm.startBroadcast(takerKey);
        IERC20(collateral).approve(exchange, FUND_AMOUNT);
        vm.stopBroadcast();
        console2.log("[10] Taker approved exchange for USDC");

        // ── Print env summary ────────────────────────────────
        console2.log("\n=====================================================");
        console2.log(" COPY INTO YOUR .env FILE");
        console2.log("=====================================================");
        console2.log("CTF_EXCHANGE=%s",   exchange);
        console2.log("CTF=%s",           ctf);
        console2.log("COLLATERAL=%s",    collateral);
        console2.log("TOKEN_ID_YES=%s",  vm.toString(bytes32(tokenIdYes)));
        console2.log("TOKEN_ID_NO=%s",   vm.toString(bytes32(tokenIdNo)));
        console2.log("CONDITION_ID=%s",  vm.toString(conditionId));
        console2.log("=====================================================");
        console2.log("Next step: bash script/base/demo_loop.sh\n");
    }
}
