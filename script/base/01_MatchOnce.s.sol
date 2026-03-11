// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2, Script} from "forge-std/Script.sol";
import {CTFExchange} from "src/exchange/CTFExchange.sol";
import {ConditionalTokens} from "src/token/ConditionalTokens.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {Order, Side, SignatureType, ORDER_TYPEHASH} from "src/exchange/libraries/OrderStructs.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title MatchOnce — Base Sepolia Hackathon Demo
 * @notice Sends ONE `matchOrders` transaction to CTFExchange on Base Sepolia.
 *         Auto-refills maker/taker balances via MockUSDC mint() when running low.
 *         Called in a loop by demo_loop.sh to simulate continuous matching.
 *
 * Prerequisites (run 00_DeployAll.s.sol first, then set .env):
 *   CTF_EXCHANGE, COLLATERAL, TOKEN_ID_YES, CONDITION_ID
 *   PRI_KEY (operator/deployer)
 *   MAKER_PRIVATE_KEY, TAKER_PRIVATE_KEY
 *
 * Single manual run:
 *   forge script script/base/01_MatchOnce.s.sol:MatchOnce \
 *     --rpc-url $BASE_SEPOLIA_RPC \
 *     --broadcast \
 *     --private-key $PRI_KEY \
 *     -vv
 *
 * Loop (see demo_loop.sh):
 *   bash script/base/demo_loop.sh
 */
contract MatchOnce is Script {
    // ── Exchange params (read from env) ──────────────────────
    address public exchange;
    uint256 public tokenIdYes;

    // ── Accounts ─────────────────────────────────────────────
    uint256 public deployerKey;
    uint256 public makerKey;
    uint256 public takerKey;
    address public maker;
    address public taker;

    // ── Order size (realistic small fills for demo) ──────────
    /// Sell 100 YES tokens at 0.60 USDC each
    uint256 constant FILL_TOKENS = 100 * 1e6;   // 100 tokens (1e6 precision)
    uint256 constant FILL_USDC   =  60 * 1e6;   //  60 USDC  (6 decimals)

    /// Refill threshold / amount — restock when balance drops below FILL_* * 10
    uint256 constant REFILL_AMOUNT = 10_000 * 1e6;

    // ── Nonce counter (incremented each run via env) ─────────
    uint256 public runCounter;

    function run() external {
        // ── Read environment ──────────────────────────────────
        exchange   = vm.envAddress("CTF_EXCHANGE");
        tokenIdYes = vm.envUint("TOKEN_ID_YES");
        deployerKey = vm.envUint("PRI_KEY");
        makerKey    = vm.envOr("MAKER_PRIVATE_KEY", deployerKey);
        takerKey    = vm.envOr("TAKER_PRIVATE_KEY", deployerKey);
        maker       = vm.addr(makerKey);
        taker       = vm.addr(takerKey);
        runCounter  = vm.envOr("RUN_COUNTER", uint256(0));

        // ── Resolve collateral / CTF from exchange ────────────
        CTFExchange exchangeContract = CTFExchange(exchange);
        address collateral = exchangeContract.getCollateral();
        address ctf        = exchangeContract.getCtf();
        bytes32 conditionId = vm.envBytes32("CONDITION_ID");

        // ── Read on-chain nonces ──────────────────────────────
        uint256 makerNonce = exchangeContract.nonces(maker);
        uint256 takerNonce = exchangeContract.nonces(taker);

        // ── Pre-flight checks + auto-refill ──────────────────
        _ensureTakerReady(collateral, exchange, takerKey, taker);
        _ensureMakerReady(collateral, ctf, exchange, conditionId, makerKey, maker, tokenIdYes);

        console2.log("\n[MatchOnce] Block #", block.number, " | Run #", runCounter);
        console2.log("  Exchange  :", exchange);
        console2.log("  Maker     :", maker);
        console2.log("  Taker     :", taker);
        console2.log("  tokenIdYes:", tokenIdYes);
        console2.log("  Price     : 0.60 USDC / YES token");
        console2.log("  Fill size :", FILL_TOKENS / 1e6, "tokens");

        // ── Build maker order (SELL YES tokens) ──────────────
        Order memory makerOrder = Order({
            salt:          uint256(keccak256(abi.encodePacked(block.timestamp, maker, runCounter, "maker"))),
            maker:         maker,
            signer:        maker,
            taker:         address(0),
            tokenId:       tokenIdYes,
            makerAmount:   FILL_TOKENS,     // sell 100 YES tokens
            takerAmount:   FILL_USDC,       // receive 60 USDC
            expiration:    block.timestamp + 1 hours,
            nonce:         makerNonce,
            feeRateBps:    0,
            side:          Side.SELL,
            signatureType: SignatureType.EOA,
            signature:     ""
        });

        // ── Build taker order (BUY YES tokens) ───────────────
        Order memory takerOrder = Order({
            salt:          uint256(keccak256(abi.encodePacked(block.timestamp, taker, runCounter, "taker"))),
            maker:         taker,
            signer:        taker,
            taker:         address(0),
            tokenId:       tokenIdYes,
            makerAmount:   FILL_USDC,       // pay 60 USDC
            takerAmount:   FILL_TOKENS,     // receive 100 YES tokens
            expiration:    block.timestamp + 1 hours,
            nonce:         takerNonce,
            feeRateBps:    0,
            side:          Side.BUY,
            signatureType: SignatureType.EOA,
            signature:     ""
        });

        // ── Sign orders (EIP-712) ─────────────────────────────
        bytes32 makerHash = _hashTypedDataV4(_hashOrder(makerOrder));
        bytes32 takerHash = _hashTypedDataV4(_hashOrder(takerOrder));

        makerOrder.signature = _sign(makerKey, makerHash);
        takerOrder.signature = _sign(takerKey, takerHash);

        // ── Broadcast matchOrders as operator ────────────────
        Order[] memory makerOrders        = new Order[](1);
        uint256[] memory makerFillAmounts = new uint256[](1);
        makerOrders[0]        = makerOrder;
        makerFillAmounts[0]   = FILL_TOKENS;

        vm.startBroadcast(deployerKey);
        exchangeContract.matchOrders(takerOrder, makerOrders, FILL_USDC, makerFillAmounts);
        vm.stopBroadcast();

        console2.log("  >> matchOrders() SUCCESS");
    }

    // ─────────────────────────────────────────────────────────
    //  Auto-refill helpers
    // ─────────────────────────────────────────────────────────

    /**
     * @dev Ensures taker has enough USDC and has approved the exchange.
     *      Calls MockUSDC.mint() if balance is insufficient (testnet only).
     */
    function _ensureTakerReady(
        address collateral,
        address exch,
        uint256 takerPk,
        address takerAddr
    ) internal {
        uint256 bal  = IERC20(collateral).balanceOf(takerAddr);
        uint256 allw = IERC20(collateral).allowance(takerAddr, exch);

        if (bal < FILL_USDC) {
            console2.log("  [auto] taker USDC low, minting", REFILL_AMOUNT);
            vm.startBroadcast(takerPk);  // mint to self; MockUSDC allows any caller
            (bool ok,) = collateral.call(
                abi.encodeWithSignature("mint(address,uint256)", takerAddr, REFILL_AMOUNT)
            );
            vm.stopBroadcast();
            require(ok, "mint() failed - is COLLATERAL a MockUSDC?");
        }

        if (allw < FILL_USDC) {
            console2.log("  [auto] taker allowance low, approving exchange");
            vm.startBroadcast(takerPk);
            IERC20(collateral).approve(exch, type(uint256).max);
            vm.stopBroadcast();
        }
    }

    /**
     * @dev Ensures maker has enough YES tokens and CTF approval.
     *      Mints MockUSDC and splits into YES/NO if YES balance is insufficient.
     */
    function _ensureMakerReady(
        address collateral,
        address ctf,
        address exch,
        bytes32 conditionId,
        uint256 makerPk,
        address makerAddr,
        uint256 yesId
    ) internal {
        uint256 yesBal    = IERC1155(ctf).balanceOf(makerAddr, yesId);
        bool    approved  = IERC1155(ctf).isApprovedForAll(makerAddr, exch);

        if (yesBal < FILL_TOKENS) {
            console2.log("  [auto] maker YES low, minting + splitting", REFILL_AMOUNT);

            // 1. Mint MockUSDC to maker
            vm.startBroadcast(makerPk);
            (bool ok,) = collateral.call(
                abi.encodeWithSignature("mint(address,uint256)", makerAddr, REFILL_AMOUNT)
            );
            require(ok, "mint() failed - is COLLATERAL a MockUSDC?");

            // 2. Approve CTF to spend USDC
            IERC20(collateral).approve(ctf, REFILL_AMOUNT);

            // 3. Split USDC -> YES + NO tokens
            uint256[] memory partition = new uint256[](2);
            partition[0] = 1; // YES
            partition[1] = 2; // NO
            ConditionalTokens(ctf).splitPosition(
                IERC20(collateral), bytes32(0), conditionId, partition, REFILL_AMOUNT
            );
            vm.stopBroadcast();
        }

        if (!approved) {
            console2.log("  [auto] maker CTF not approved, approving exchange");
            vm.startBroadcast(makerPk);
            IERC1155(ctf).setApprovalForAll(exch, true);
            vm.stopBroadcast();
        }
    }

    // ── Helpers ───────────────────────────────────────────────

    function _sign(uint256 privateKey, bytes32 finalHash)
        internal
        pure
        returns (bytes memory sig)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, finalHash);
        sig = abi.encodePacked(r, s, v);
    }

    function _hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_buildDomainSeparator(), structHash);
    }

    function _buildDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Polymarket CTF Exchange")),
                keccak256(bytes("1")),
                block.chainid,
                exchange
            )
        );
    }

    function _hashOrder(Order memory o) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            ORDER_TYPEHASH,
            o.salt, o.maker, o.signer, o.taker,
            o.tokenId, o.makerAmount, o.takerAmount,
            o.expiration, o.nonce, o.feeRateBps,
            uint8(o.side), uint8(o.signatureType)
        ));
    }
}
