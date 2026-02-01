// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2, Script} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {CTFExchange} from "src/exchange/CTFExchange.sol";
import {ConditionalTokens} from "src/token/ConditionalTokens.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    Order,
    Side,
    SignatureType
} from "src/exchange/libraries/OrderStructs.sol";

/**
 * @title MatchOrders Script
 * @notice Script to match orders on CTFExchange on Unichain Testnet
 * @dev Usage:
 *   1. Deploy: forge script script/unichain/MatchOrders.s.sol:MatchOrders --rpc-url $UNICHAIN_TESTNET_RPC --broadcast
 *   2. Or run specific function: --sig "matchOrders()"
 */
contract MatchOrders is BaseScript {
    // ============ Contract Addresses ============
    address constant USDC = 0xE5687DB12c99F99bCbC165643d7FeF2C0139aa92; // USDC Token
    address constant CTF = 0x618F09386e484Eeb3bD76aB927ae2DF1a3425feC; // Condition Token

    // Exchange address (already deployed)
    address public exchange = 0xB2B41176f0d466103f7b6195DC0ADE4C604adD77;

    // Test accounts
    address public maker;
    address public taker;
    address public operator;

    // Private keys (for testnet only!)
    uint256 makerPrivateKey;
    uint256 takerPrivateKey;

    // Market configuration
    bytes32 public questionId;
    uint256 public tokenIdYes;
    uint256 public tokenIdNo;
    bytes32 public conditionId;

    function setUp() public virtual override {
        // Get deployer as operator
        operator = msg.sender;

        // For testnet, you can use test private keys or generate new ones
        // WARNING: Never use these keys on mainnet!
        makerPrivateKey = vm.envOr("MAKER_PRIVATE_KEY", uint256(0x1));
        takerPrivateKey = vm.envOr("TAKER_PRIVATE_KEY", uint256(0x2));

        maker = vm.addr(makerPrivateKey);
        taker = vm.addr(takerPrivateKey);

        console2.log("=== Account Setup ===");
        console2.log("Operator:", operator);
        console2.log("Maker:", maker);
        console2.log("Taker:", taker);
    }

    /**
     * @notice Main entry point - deploys exchange and matches orders
     */
    function run() external {
        console2.log(
            "\n=== Starting Order Matching Script (Using Existing Exchange) ===\n"
        );
        console2.log("Using Exchange at:", exchange);

        // 1. Setup exchange (admin, operator, tokens)
        setupExchange();

        // 2. Setup test market
        setupMarket();

        // 3. Fund accounts
        fundAccounts();

        // 4. Create and match orders
        createAndMatchOrders();
    }

    /**
     * @notice Setup exchange: add operator and register tokens
     */
    function setupExchange() public  {
        console2.log("\n=== Setting Up Exchange ===");

        CTFExchange exchangeContract = CTFExchange(exchange);

        // Add operator (allows calling matchOrders)
        console2.log("Adding operator:", operator);
        exchangeContract.addOperator(operator);

        // Note: Token registration happens after market setup
    }

    /**
     * @notice Setup a test market for trading
     */
    function setupMarket() public  {
        console2.log("\n=== Setting Up Test Market ===");

        ConditionalTokens ctf = ConditionalTokens(CTF);

        // Create a question ID (unique identifier for the market)
        questionId = keccak256(
            abi.encodePacked("Will ETH reach $10k in 2026?", block.timestamp)
        );

        // Prepare condition on CTF
        ctf.prepareCondition(
            operator, // oracle address
            questionId,
            2 // outcome count (Yes/No)
        );

        conditionId = ctf.getConditionId(operator, questionId, 2);

        // Calculate token IDs for YES and NO outcomes
        bytes32 collectionIdYes = ctf.getCollectionId(
            bytes32(0),
            conditionId,
            1
        ); // YES = index 1
        bytes32 collectionIdNo = ctf.getCollectionId(
            bytes32(0),
            conditionId,
            2
        ); // NO = index 2

        tokenIdYes = ctf.getPositionId(IERC20(USDC), collectionIdYes);
        tokenIdNo = ctf.getPositionId(IERC20(USDC), collectionIdNo);

        console2.log("Question ID:", vm.toString(questionId));
        console2.log("Condition ID:", vm.toString(conditionId));
        console2.log("Token ID (YES):", tokenIdYes);
        console2.log("Token ID (NO):", tokenIdNo);

        // Register tokens on exchange
        CTFExchange exchangeContract = CTFExchange(exchange);
        exchangeContract.registerToken(tokenIdYes, tokenIdNo, conditionId);
        console2.log("Tokens registered on exchange");
    }

    /**
     * @notice Fund test accounts with USDC and outcome tokens
     */
    function fundAccounts() public  {
        console2.log("\n=== Funding Accounts ===");

        IERC20 usdc = IERC20(USDC);
        ConditionalTokens ctf = ConditionalTokens(CTF);

        uint256 fundAmount = 1000 * 1e6; // 1000 USDC (6 decimals)

        // Fund maker with USDC
        if (usdc.balanceOf(operator) >= fundAmount) {
            usdc.transfer(maker, fundAmount);
            console2.log("Funded maker with", fundAmount / 1e6, "USDC");
        } else {
            console2.log("WARNING: Insufficient USDC balance for funding");
        }

        // Approve CTF to spend USDC
        vm.startBroadcast(makerPrivateKey);
        usdc.approve(CTF, fundAmount);
        vm.stopBroadcast();

        // Split position: USDC -> YES + NO tokens
        vm.startBroadcast(makerPrivateKey);
        uint256[] memory partition = new uint256[](2);
        partition[0] = 1; // YES
        partition[1] = 2; // NO

        ctf.splitPosition(
            IERC20(USDC),
            bytes32(0), // parentCollectionId
            conditionId,
            partition,
            fundAmount
        );
        vm.stopBroadcast();

        console2.log(
            "Maker split",
            fundAmount / 1e6,
            "USDC into YES/NO tokens"
        );

        // Approve exchange to spend tokens
        vm.startBroadcast(makerPrivateKey);
        ctf.setApprovalForAll(exchange, true);
        vm.stopBroadcast();

        console2.log("Maker approved exchange for tokens");

        // Fund taker with USDC for buying
        if (usdc.balanceOf(operator) >= fundAmount) {
            usdc.transfer(taker, fundAmount);
            console2.log("Funded taker with", fundAmount / 1e6, "USDC");
        }

        vm.startBroadcast(takerPrivateKey);
        usdc.approve(exchange, fundAmount);
        vm.stopBroadcast();

        console2.log("Taker approved exchange for USDC");
    }

    /**
     * @notice Create and match orders
     */
    function createAndMatchOrders() public  {
        console2.log("\n=== Creating and Matching Orders ===");

        CTFExchange exchangeContract = CTFExchange(exchange);

        // Create maker order (SELL YES tokens at 0.6 USDC each)
        Order memory makerOrder = createMakerOrder();

        // Create taker order (BUY YES tokens at 0.6 USDC each)
        Order memory takerOrder = createTakerOrder();

        // Print orders
        console2.log("\nMaker Order (SELL):");
        console2.log("  Token ID:", makerOrder.tokenId);
        console2.log("  Maker Amount:", makerOrder.makerAmount);
        console2.log("  Taker Amount:", makerOrder.takerAmount);
        console2.log(
            "  Price:",
            (makerOrder.takerAmount * 1e18) / makerOrder.makerAmount / 1e12,
            "USDC per token"
        );

        console2.log("\nTaker Order (BUY):");
        console2.log("  Token ID:", takerOrder.tokenId);
        console2.log("  Maker Amount:", takerOrder.makerAmount);
        console2.log("  Taker Amount:", takerOrder.takerAmount);
        console2.log(
            "  Price:",
            (takerOrder.makerAmount * 1e18) / takerOrder.takerAmount / 1e12,
            "USDC per token"
        );

        // Match orders
        Order[] memory makerOrders = new Order[](1);
        makerOrders[0] = makerOrder;

        uint256[] memory makerFillAmounts = new uint256[](1);
        makerFillAmounts[0] = 100 * 1e6; // Fill 100 tokens from maker

        uint256 takerFillAmount = 100 * 1e6; // Fill 100 tokens for taker

        console2.log("\nMatching orders...");
        console2.log("  Taker fill amount:", takerFillAmount / 1e6);
        console2.log("  Maker fill amount:", makerFillAmounts[0] / 1e6);

        exchangeContract.matchOrders(
            takerOrder,
            makerOrders,
            takerFillAmount,
            makerFillAmounts
        );

        console2.log("Orders matched successfully!");
    }

    /**
     * @notice Create a maker order
     */
    function createMakerOrder() internal view returns (Order memory) {
        Order memory order = Order({
            salt: uint256(
                keccak256(abi.encodePacked(block.timestamp, maker, "maker"))
            ),
            maker: maker,
            signer: maker,
            taker: address(0), // Public order
            tokenId: tokenIdYes,
            makerAmount: 100 * 1e6, // Sell 100 YES tokens
            takerAmount: 60 * 1e6, // For 60 USDC (price = 0.6 USDC per token)
            expiration: block.timestamp + 1 days,
            nonce: 0,
            feeRateBps: 0, // 0% fee
            side: Side.SELL,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        // Sign the order
        bytes32 orderHash = hashOrder(order);
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", orderHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            makerPrivateKey,
            ethSignedHash
        );
        order.signature = abi.encodePacked(r, s, v);

        return order;
    }

    /**
     * @notice Create a taker order
     */
    function createTakerOrder() internal view returns (Order memory) {
        Order memory order = Order({
            salt: uint256(
                keccak256(abi.encodePacked(block.timestamp, taker, "taker"))
            ),
            maker: taker,
            signer: taker,
            taker: address(0), // Public order
            tokenId: tokenIdYes,
            makerAmount: 60 * 1e6, // Pay 60 USDC
            takerAmount: 100 * 1e6, // To buy 100 YES tokens (price = 0.6 USDC per token)
            expiration: block.timestamp + 1 days,
            nonce: 0,
            feeRateBps: 0, // 0% fee
            side: Side.BUY,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        // Sign the order
        bytes32 orderHash = hashOrder(order);
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", orderHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            takerPrivateKey,
            ethSignedHash
        );
        order.signature = abi.encodePacked(r, s, v);

        return order;
    }

    /**
     * @notice Hash an order for signing
     */
    function hashOrder(Order memory order) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "Order(uint256 salt,address maker,address signer,address taker,uint256 tokenId,uint256 makerAmount,uint256 takerAmount,uint256 expiration,uint256 nonce,uint256 feeRateBps,uint8 side,uint8 signatureType)"
                    ),
                    order.salt,
                    order.maker,
                    order.signer,
                    order.taker,
                    order.tokenId,
                    order.makerAmount,
                    order.takerAmount,
                    order.expiration,
                    order.nonce,
                    order.feeRateBps,
                    uint8(order.side),
                    uint8(order.signatureType)
                )
            );
    }
}
