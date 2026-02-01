// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2, Script} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {CTFExchange} from "src/exchange/CTFExchange.sol";
import {Order, Side, SignatureType} from "src/exchange/libraries/OrderStructs.sol";

/**
 * @title MatchOrdersOnly
 * @notice Simplified script to match pre-configured orders on existing CTFExchange
 * @dev Assumes exchange and market are already set up
 *
 * Usage:
 *   forge script script/unichain/MatchOrdersOnly.s.sol:MatchOrdersOnly \
 *     --rpc-url $UNICHAIN_TESTNET_RPC \
 *     --private-key $PRIVATE_KEY \
 *     --broadcast -vvvv
 */
contract MatchOrdersOnly is BaseScript {
    // ============ UPDATE THESE ADDRESSES ============
    address constant EXCHANGE = address(0); // Your deployed CTFExchange address
    address constant MAKER = address(0);    // Maker address
    address constant TAKER = address(0);    // Taker address
    uint256 constant TOKEN_ID = 0;          // Token ID to trade

    // Maker order parameters
    uint256 constant MAKER_AMOUNT = 100 * 1e6;  // Sell 100 tokens
    uint256 constant MAKER_PRICE = 60 * 1e6;     // For 60 USDC (0.6 per token)

    // Taker order parameters
    uint256 constant TAKER_AMOUNT = 100 * 1e6;  // Buy 100 tokens
    uint256 constant TAKER_PRICE = 60 * 1e6;     // Pay 60 USDC (0.6 per token)

    function run() external  {
        require(EXCHANGE != address(0), "Set EXCHANGE address");
        require(MAKER != address(0), "Set MAKER address");
        require(TAKER != address(0), "Set TAKER address");
        require(TOKEN_ID != 0, "Set TOKEN_ID");

        CTFExchange exchange = CTFExchange(EXCHANGE);

        // Create orders (you'll need to get signatures off-chain in production)
        Order memory makerOrder = Order({
            salt: uint256(keccak256(abi.encodePacked(block.timestamp, MAKER))),
            maker: MAKER,
            signer: MAKER,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: MAKER_AMOUNT,
            takerAmount: MAKER_PRICE,
            expiration: block.timestamp + 1 days,
            nonce: 0,
            feeRateBps: 0,
            side: Side.SELL,
            signatureType: SignatureType.EOA,
            signature: hex"" // Add signature here
        });

        Order memory takerOrder = Order({
            salt: uint256(keccak256(abi.encodePacked(block.timestamp, TAKER))),
            maker: TAKER,
            signer: TAKER,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: TAKER_PRICE,
            takerAmount: TAKER_AMOUNT,
            expiration: block.timestamp + 1 days,
            nonce: 0,
            feeRateBps: 0,
            side: Side.BUY,
            signatureType: SignatureType.EOA,
            signature: hex"" // Add signature here
        });

        // Match orders
        Order[] memory makerOrders = new Order[](1);
        makerOrders[0] = makerOrder;

        uint256[] memory makerFillAmounts = new uint256[](1);
        makerFillAmounts[0] = MAKER_AMOUNT;

        console2.log("Matching orders on exchange:", EXCHANGE);
        console2.log("Maker:", MAKER);
        console2.log("Taker:", TAKER);
        console2.log("Token ID:", TOKEN_ID);
        console2.log("Amount:", MAKER_AMOUNT / 1e6);
        console2.log("Price:", MAKER_PRICE / 1e6, "USDC");

        exchange.matchOrders(
            takerOrder,
            makerOrders,
            TAKER_AMOUNT,
            makerFillAmounts
        );

        console2.log("Orders matched successfully!");
    }
}
