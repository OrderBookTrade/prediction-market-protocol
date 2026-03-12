// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2, Script} from "forge-std/Script.sol";
import {MockERC20} from "src/token/MockERC20.sol";
import {CTFExchange} from "src/exchange/CTFExchange.sol";
import {ConditionalTokens} from "src/token/ConditionalTokens.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {BaseScript} from "../BaseScript.s.sol";

contract DeployAll is BaseScript {
    // ── Config ──────────────────────────────────────────────
    uint256 constant FUND_AMOUNT = 10_000 * 1e6; // 10,000 mock USDC
    uint256 constant SPLIT_AMOUNT = 5_000 * 1e6; // 5,000 split into YES/NO tokens

    // ── State (set during run) ───────────────────────────────
    address public collateral = 0xB54Cfef749d104b54D514538cAdb281f2E951079;
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

    function run() public {
        // 1.deploy mock usdc
        deployUSDCToken();

        // 2. deploy CTF Token
        // deployCTFToken();

        
    }

    /**
     * //     // Add operator (deployer == matching engine)
     * //     CTFExchange(exchange).addOperator(deployer);
     * //     console2.log("[4] Operator added   :", deployer);
     *
     * //     // Prepare market: "Will ETH reach $10k in 2026?"
     * //     bytes32 questionId = keccak256(abi.encodePacked("Will ETH reach $10k in 2026?", uint256(block.chainid)));
     * //     ConditionalTokens(ctf).prepareCondition(deployer, questionId, 2);
     * //     conditionId = ConditionalTokens(ctf).getConditionId(deployer, questionId, 2);
     * //     console2.log("[5] Condition ID     :", vm.toString(conditionId));
     *
     * //     // Compute YES / NO token IDs
     * //     bytes32 colIdYes = ConditionalTokens(ctf).getCollectionId(bytes32(0), conditionId, 1);
     * //     bytes32 colIdNo = ConditionalTokens(ctf).getCollectionId(bytes32(0), conditionId, 2);
     * //     tokenIdYes = ConditionalTokens(ctf).getPositionId(IERC20(collateral), colIdYes);
     * //     tokenIdNo = ConditionalTokens(ctf).getPositionId(IERC20(collateral), colIdNo);
     * //     console2.log("[6] tokenIdYes       :", tokenIdYes);
     * //     console2.log("    tokenIdNo        :", tokenIdNo);
     *
     * //     // Register tokens on exchange
     * //     CTFExchange(exchange).registerToken(tokenIdYes, tokenIdNo, conditionId);
     * //     console2.log("[7] Tokens registered on exchange");
     *
     * //     // Mint mock USDC to maker and taker
     * //     MockUSDC(collateral).mint(maker, FUND_AMOUNT);
     * //     MockUSDC(collateral).mint(taker, FUND_AMOUNT);
     * //     console2.log("[8] Minted", FUND_AMOUNT / 1e6, "mUSDC to maker & taker");
     *
     * //     vm.stopBroadcast();
     *
     * //     // ── Step 2: Maker splits USDC -> YES+NO tokens ───────
     * //     vm.startBroadcast(makerKey);
     * //     IERC20(collateral).approve(ctf, SPLIT_AMOUNT);
     * //     uint256[] memory partition = new uint256[](2);
     * //     partition[0] = 1;
     * //     partition[1] = 2;
     * //     ConditionalTokens(ctf).splitPosition(IERC20(collateral), bytes32(0), conditionId, partition, SPLIT_AMOUNT);
     * //     // Approve exchange to move maker's outcome tokens
     * //     ConditionalTokens(ctf).setApprovalForAll(exchange, true);
     * //     vm.stopBroadcast();
     * //     console2.log("[9] Maker split USDC -> YES/NO and approved exchange");
     *
     * //     // ── Step 3: Taker approves exchange to spend USDC ───
     * //     vm.startBroadcast(takerKey);
     * //     IERC20(collateral).approve(exchange, FUND_AMOUNT);
     * //     vm.stopBroadcast();
     * //     console2.log("[10] Taker approved exchange for USDC");
     *
     * //     // ── Print env summary ────────────────────────────────
     * //     console2.log("\n=====================================================");
     * //     console2.log(" COPY INTO YOUR .env FILE");
     * //     console2.log("=====================================================");
     * //     console2.log("CTF_EXCHANGE=%s", exchange);
     * //     console2.log("CTF=%s", ctf);
     * //     console2.log("COLLATERAL=%s", collateral);
     * //     console2.log("TOKEN_ID_YES=%s", vm.toString(bytes32(tokenIdYes)));
     * //     console2.log("TOKEN_ID_NO=%s", vm.toString(bytes32(tokenIdNo)));
     * //     console2.log("CONDITION_ID=%s", vm.toString(conditionId));
     * //     console2.log("=====================================================");
     * //     console2.log("Next step: bash script/base/demo_loop.sh\n");
     * // }
     */
    function deployUSDCToken() public {
        MockERC20 usdc = new MockERC20();
        console2.log("deployed usdc token ");
    }

    function deployCTFToken() public {
        ConditionalTokens ctf = new ConditionalTokens();
        console2.log("ctf token ", address(ctf));
    }

    function deployCTFExchange() public {
        CTFExchange exchange = new CTFExchange(collateral, ctf, address(0), address(0));
        console2.log("[3] CTFExchange      :", address(exchange));
    }
}
