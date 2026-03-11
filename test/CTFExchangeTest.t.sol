// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {CTFExchange} from "src/exchange/CTFExchange.sol";
import {ConditionalTokens} from "src/token/ConditionalTokens.sol";
import {MockERC20} from "src/token/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Order, Side, SignatureType, ORDER_TYPEHASH} from "src/exchange/libraries/OrderStructs.sol";

contract CTFExchangeTest is Test {
    CTFExchange exchange;
    ConditionalTokens ctf;
    MockERC20 collateral;

    uint256 makerPk = 0xA11CE;
    address maker = vm.addr(makerPk);

    uint256 takerPk = 0xB0B;
    address taker = vm.addr(takerPk);

    bytes32 constant QUESTION_ID = bytes32(uint256(1));
    bytes32 conditionId;
    bytes32 collectionId;
    uint256 tokenId;
    uint256 tokenId1;

    function setUp() public {
        ctf = new ConditionalTokens();
        collateral = new MockERC20();

        // Deploy Exchange with zero address factories
        exchange = new CTFExchange(address(collateral), address(ctf), address(0), address(0));

        // Prepare CTF Condition
        ctf.prepareCondition(address(this), QUESTION_ID, 2);
        conditionId = ctf.getConditionId(address(this), QUESTION_ID, 2);
        collectionId = ctf.getCollectionId(bytes32(0), conditionId, 1); // Outcome 0
        tokenId = ctf.getPositionId(IERC20(address(collateral)), collectionId);

        bytes32 collectionId1 = ctf.getCollectionId(bytes32(0), conditionId, 2); // Outcome 1
        tokenId1 = ctf.getPositionId(IERC20(address(collateral)), collectionId1);

        // Register Token Pair
        exchange.registerToken(tokenId, tokenId1, conditionId);

        // Mint Collateral
        collateral.mint(maker, 10000 ether);
        collateral.mint(taker, 10000 ether);

        // Approvals
        vm.startPrank(maker);
        collateral.approve(address(exchange), type(uint256).max);
        ctf.setApprovalForAll(address(exchange), true);
        vm.stopPrank();

        vm.startPrank(taker);
        collateral.approve(address(exchange), type(uint256).max);
        ctf.setApprovalForAll(address(exchange), true);
        vm.stopPrank();

        // Add taker as operator
        exchange.addOperator(taker);
    }

    function testFillOrder_BuySide() public {
        // Maker wants to BUY outcome tokens
        // Maker pays Collateral (takerAsset), receives CTF (makerAsset)
        // Wait, in OrderStructs:
        // If BUY, tokenId is the asset to be bought (makerAssetId).
        // makerAmount is "maximum amount of tokens to be sold"... wait.

        // Let's verify Asset definitions in Assets.sol or CTFExchange.
        // Usually:
        // BUY: Maker wants to BUY tokenId. Maker gives Collateral.
        // makerAmount: Amount of Collateral offered? Or amount of TokenId wanted?

        // Let's look at `_fillOrder` logic in Trading.sol or Assets.sol interactions to be sure.
        // But assuming standard Polymarket:
        // Side.BUY: Maker pays Collateral, receives TokenId.
        // makerAmount: Amount of Collateral (input).
        // takerAmount: Amount of TokenId (output).

        // Let's assume:
        // Order(BUY):
        //   makerAmount = 100 USDC (Collateral)
        //   takerAmount = 200 YES (TokenId)

        // Setup Taker with CTF tokens (to sell to Maker)
        _mintCTFTokensTo(taker, 1000 ether);

        Order memory order = Order({
            salt: 1,
            maker: maker,
            signer: maker,
            taker: address(0), // Public order
            tokenId: tokenId,
            makerAmount: 100 ether, // Paying 100 USDC
            takerAmount: 200 ether, // Buying 200 YES
            expiration: block.timestamp + 1000,
            nonce: 0,
            feeRateBps: 0,
            side: Side.BUY,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        // Sign Order
        bytes32 orderHash = exchange.hashOrder(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(makerPk, orderHash);
        order.signature = abi.encodePacked(r, s, v);

        uint256 makerCollateralBefore = collateral.balanceOf(maker);
        uint256 takerCollateralBefore = collateral.balanceOf(taker);
        uint256 makerTokenBefore = ctf.balanceOf(maker, tokenId);
        uint256 takerTokenBefore = ctf.balanceOf(taker, tokenId);

        // Taker fills the order
        vm.prank(taker);
        exchange.fillOrder(order, 100 ether); // Fill full amount (100 USDC)

        // Verify Balances
        // Maker spent 100 USDC, got 200 YES
        assertEq(collateral.balanceOf(maker), makerCollateralBefore - 100 ether, "Maker should spend collateral");
        assertEq(ctf.balanceOf(maker, tokenId), makerTokenBefore + 200 ether, "Maker should receive tokens");

        // Taker got 100 USDC, spent 200 YES
        assertEq(collateral.balanceOf(taker), takerCollateralBefore + 100 ether, "Taker should receive collateral");
        assertEq(ctf.balanceOf(taker, tokenId), takerTokenBefore - 200 ether, "Taker should spend tokens");
    }

    function testFillOrder_SellSide() public {
        // Maker wants to SELL outcome tokens
        // Maker has 200 YES, wants 100 USDC.

        // Mint CTF tokens to Maker
        _mintCTFTokensTo(maker, 1000 ether);

        Order memory order = Order({
            salt: 2,
            maker: maker,
            signer: maker,
            taker: address(0),
            tokenId: tokenId,
            makerAmount: 200 ether, // Selling 200 YES
            takerAmount: 100 ether, // Asking for 100 USDC
            expiration: block.timestamp + 1000,
            nonce: 0,
            feeRateBps: 0,
            side: Side.SELL,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        // Sign Order
        bytes32 orderHash = exchange.hashOrder(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(makerPk, orderHash);
        order.signature = abi.encodePacked(r, s, v);

        uint256 makerCollateralBefore = collateral.balanceOf(maker);
        uint256 takerCollateralBefore = collateral.balanceOf(taker);
        uint256 makerTokenBefore = ctf.balanceOf(maker, tokenId);
        uint256 takerTokenBefore = ctf.balanceOf(taker, tokenId);

        // Taker fills the order
        vm.prank(taker);
        exchange.fillOrder(order, 200 ether); // Fill full maker amount (200 YES)

        // Verify Balances
        // Maker gave 200 YES, got 100 USDC
        assertEq(collateral.balanceOf(maker), makerCollateralBefore + 100 ether, "Maker should receive collateral");
        assertEq(ctf.balanceOf(maker, tokenId), makerTokenBefore - 200 ether, "Maker should spend tokens");

        // Taker gave 100 USDC, got 200 YES
        assertEq(collateral.balanceOf(taker), takerCollateralBefore - 100 ether, "Taker should spend collateral");
        assertEq(ctf.balanceOf(taker, tokenId), takerTokenBefore + 200 ether, "Taker should receive tokens");
    }

    function _mintCTFTokensTo(address user, uint256 amount) internal {
        // Logic: Helper to split position and give tokens to user
        // 1. Give user collateral
        // 2. User approves CTF
        // 3. CTF splitPosition
        uint256[] memory partition = new uint256[](2);
        partition[0] = 1;
        partition[1] = 2;

        uint256 mintAmount = amount;

        // Ensure user has enough collateral to split
        // collateral.mint(user, mintAmount); // Already minted in setUp

        vm.startPrank(user);
        collateral.approve(address(ctf), mintAmount);
        ctf.splitPosition(IERC20(address(collateral)), bytes32(0), conditionId, partition, mintAmount);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        MATCHING ENGINE INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testMatchOrders_Mint() public {
        // Taker (Order 1): BUY YES (tokenId)
        // Maker (Order 2): BUY NO (tokenId1)
        // MatchType.MINT
        
        uint256 takerAmountCollateral = 60 ether; // Taker pays 60 USDC
        uint256 takerWantedShares = 100 ether; // Taker wants 100 YES
        
        uint256 makerAmountCollateral = 40 ether; // Maker pays 40 USDC
        uint256 makerWantedShares = 100 ether; // Maker wants 100 NO

        Order memory takerOrder = Order({
            salt: 10,
            maker: taker,
            signer: taker,
            taker: address(0),
            tokenId: tokenId, // YES
            makerAmount: takerAmountCollateral,
            takerAmount: takerWantedShares,
            expiration: block.timestamp + 1000,
            nonce: 0,
            feeRateBps: 0,
            side: Side.BUY,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        Order memory makerOrder = Order({
            salt: 11,
            maker: maker,
            signer: maker,
            taker: address(0),
            tokenId: tokenId1, // NO
            makerAmount: makerAmountCollateral,
            takerAmount: makerWantedShares,
            expiration: block.timestamp + 1000,
            nonce: 0,
            feeRateBps: 0,
            side: Side.BUY,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        // Sign Taker Order
        bytes32 takerHash = exchange.hashOrder(takerOrder);
        (uint8 tv, bytes32 tr, bytes32 ts) = vm.sign(takerPk, takerHash);
        takerOrder.signature = abi.encodePacked(tr, ts, tv);

        // Sign Maker Order
        bytes32 makerHash = exchange.hashOrder(makerOrder);
        (uint8 mv, bytes32 mr, bytes32 ms) = vm.sign(makerPk, makerHash);
        makerOrder.signature = abi.encodePacked(mr, ms, mv);

        Order[] memory makerOrders = new Order[](1);
        makerOrders[0] = makerOrder;

        uint256[] memory makerFillAmounts = new uint256[](1);
        makerFillAmounts[0] = makerAmountCollateral; // fill 40 USDC worth of maker order

        uint256 takerCollateralBefore = collateral.balanceOf(taker);
        uint256 makerCollateralBefore = collateral.balanceOf(maker);
        
        // Match Engine acts as Operator
        vm.prank(taker); // 'taker' acts as registered operator in setup
        exchange.matchOrders(
            takerOrder,
            makerOrders,
            takerAmountCollateral, // fill 60 USDC worth of taker order
            makerFillAmounts
        );

        // Verify Balances
        // Taker paid 60 USDC, got 100 YES
        assertEq(collateral.balanceOf(taker), takerCollateralBefore - 60 ether);
        assertEq(ctf.balanceOf(taker, tokenId), 100 ether);

        // Maker paid 40 USDC, got 100 NO
        assertEq(collateral.balanceOf(maker), makerCollateralBefore - 40 ether);
        assertEq(ctf.balanceOf(maker, tokenId1), 100 ether);
        
        // Exchange should have 100 USDC locked as collateral for the CTF tokens
        assertEq(collateral.balanceOf(address(ctf)), 100 ether);
    }
}
