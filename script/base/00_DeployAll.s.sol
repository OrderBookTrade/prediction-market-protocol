// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2, Script} from "forge-std/Script.sol";
import {MockERC20} from "src/token/MockERC20.sol";
import {MockUSDC} from "src/token/MockUSDC.sol";
import {CTFExchange} from "src/exchange/CTFExchange.sol";
import {ConditionalTokens} from "src/token/ConditionalTokens.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {BaseScript} from "../BaseScript.s.sol";

contract DeployAll is BaseScript {
    // ── Config ──────────────────────────────────────────────
    uint256 constant FUND_AMOUNT = 10_000 * 1e18; // 10,000 mock USDC
    uint256 constant SPLIT_AMOUNT = 5_000 * 1e18; // 5,000 split into YES/NO tokens

    // ── State (set during run) ───────────────────────────────
    address public obt_mock_usdc = 0x348475f4B999069169AC6C5835f290caf0d2267b;

    address public collateral = 0x348475f4B999069169AC6C5835f290caf0d2267b;
    address public ctf = 0xa69b5Ce1e56256cCF85d1910906Fe27Db6722e9f;
    address public exchange = 0xA518f5394f4bc8b3DC7478FAF7614ADbCa96B27f;

    // == Logs ==
    //   [6] tokenIdYes       : 109446563909122268726163789479242001029893107976120913855023459460148077033656
    //       tokenIdNo        : 105503768390099242107939260718822850437652720914443779545258912597313439118475

    bytes32 public conditionId = 0x9e316d3bf403517b2d164f0b55ed21c5c767b6a4e83f650f6c4a2cc6c22c65ed;
    uint256 public tokenIdYes = 109446563909122268726163789479242001029893107976120913855023459460148077033656;
    uint256 public tokenIdNo = 105503768390099242107939260718822850437652720914443779545258912597313439118475;

    // Keys
    uint256 public deployerKey;
    uint256 public makerKey;
    uint256 public takerKey;
    address public deployer = 0xDFF68F93792dDD4b539cC7179Dd04E648AB7660e;
    address public maker = 0xB077778149f450C44b15F879f15Bf2E21121A8C7;
    address public taker = 0x8E8d5f70025068940FBc3E9945932EA02fAC7aC5;

    function run() public {
        // 1.deploy mock usdc
        // deployUSDCToken();

        // 2. deploy Mock USDC Token of decimal 6
        // deployMockUSDC();

        // 2. deploy CTF Token
        // deployCTFToken();

        // 3. deploy exchange
        // deployCTFExchange();

        // 4. add operator
        // addOperator();

        // 5. prepare condition
        // prepareCondition();

        // 6.getYesAndNoOutcomeToken
        // getYesAndNoOutcomeToken();

        // 7.register token
        // resgisterToken();

        // 8. mint token to maker and taker
        // mintToken();

        // 9. token functions
        tokenfunctions();
    }

    function deployUSDCToken() public {
        MockERC20 usdc = new MockERC20();
        console2.log("deployed usdc token ");
    }

    function deployMockUSDC() public {
        MockUSDC usdc = new MockUSDC();
        console2.log("deployed mock usdc token ");
    }

    function deployCTFToken() public {
        ConditionalTokens ctf = new ConditionalTokens();
        console2.log("[1] ctf token ", address(ctf));
    }

    function deployCTFExchange() public {
        CTFExchange exchange = new CTFExchange(collateral, ctf, address(0), address(0));
        console2.log("[3] CTFExchange      :", address(exchange));
    }

    function addOperator() public {
        CTFExchange(exchange).addOperator(deployer);
        console2.log("[4] Operator added   :", deployer);
    }

    function prepareCondition() public {
        bytes32 questionId =
            keccak256(abi.encodePacked("Will ETH break $3,000 before March 31?", uint256(block.chainid)));
        ConditionalTokens(ctf).prepareCondition(deployer, questionId, 2);
        conditionId = ConditionalTokens(ctf).getConditionId(deployer, questionId, 2);
        console2.log("[5] Condition ID     :", vm.toString(conditionId));
    }

    function getYesAndNoOutcomeToken() public {
        // Compute YES / NO token IDs
        bytes32 colIdYes = ConditionalTokens(ctf).getCollectionId(bytes32(0), conditionId, 1);
        bytes32 colIdNo = ConditionalTokens(ctf).getCollectionId(bytes32(0), conditionId, 2);
        tokenIdYes = ConditionalTokens(ctf).getPositionId(IERC20(collateral), colIdYes);
        tokenIdNo = ConditionalTokens(ctf).getPositionId(IERC20(collateral), colIdNo);
        console2.log("[6] tokenIdYes       :", tokenIdYes);
        console2.log("    tokenIdNo        :", tokenIdNo);
    }

    // register yes and no token
    function resgisterToken() public {
        // Register tokens on exchange
        CTFExchange(exchange).registerToken(tokenIdYes, tokenIdNo, conditionId);
        console2.log("[7] Tokens registered on exchange");
    }

    // mint token
    function mintToken() public {
        // MockERC20(collateral).mint(maker, FUND_AMOUNT);
        // MockERC20(collateral).mint(taker, FUND_AMOUNT);

        MockUSDC(obt_mock_usdc).mint(taker, 1000e6);
        console2.log("[8] Minted", FUND_AMOUNT / 1e6, "mUSDC to maker & taker");
    }

    function tokenfunctions() public {
        // 1. maker split token
        // splitPos();

        // 2. taker aprove exchange
        takerApproveExchange();
    }

    function splitPos() public {
        // IERC20(collateral).approve(ctf, SPLIT_AMOUNT);
        // uint256[] memory partition = new uint256[](2);
        // partition[0] = 1;
        // partition[1] = 2;
        // ConditionalTokens(ctf).splitPosition(IERC20(collateral), bytes32(0), conditionId, partition, SPLIT_AMOUNT);

        // Approve exchange to move maker's outcome tokens
        ConditionalTokens(ctf).setApprovalForAll(exchange, true);
        console2.log("[9] Maker split USDC -> YES/NO and approved exchange");
    }

    function takerApproveExchange() public {
        IERC20(collateral).approve(exchange, FUND_AMOUNT);
        console2.log("[10] Taker approved exchange for USDC");
    }
}
