// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2, Script} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {CTFExchange} from "src/exchange/CTFExchange.sol";

/**
 * @title DeployCTFExchange
 * @notice Deploy CTFExchange on Unichain Testnet
 * @dev Usage:
 *   forge script script/unichain/06_DeployCTFExchange.s.sol:DeployCTFExchange \
 *     --rpc-url $UNICHAIN_TESTNET_RPC \
 *     --broadcast \
 *     --verify \
 *     -vvvv
 */
contract DeployCTFExchange is BaseScript {
    // ============ Contract Addresses on Unichain Testnet ============
    // USDC token (Mock or real testnet USDC)
    address constant COLLATERAL = 0xE5687DB12c99F99bCbC165643d7FeF2C0139aa92;

    // ConditionalTokens Framework
    address constant CTF = 0x9d8E5bC640338E1054C540668712De69Fe39f057;

    // Proxy Factory (set to 0 if not using proxy wallets)
    address constant PROXY_FACTORY = address(0);

    // Safe Factory (set to 0 if not using Gnosis safes)
    address constant SAFE_FACTORY = address(0);

    // Deployed exchange address (will be set after deployment)
    address public exchange;

    function run() external  {
        console2.log("=== Deploying CTFExchange on Unichain Testnet ===\n");
        console2.log("Deployer:", msg.sender);
        console2.log("Chain ID:", block.chainid);
        console2.log("");

        // Validate addresses
        require(COLLATERAL != address(0), "COLLATERAL address not set");
        require(CTF != address(0), "CTF address not set");

        // Deploy CTFExchange
        console2.log("Deploying CTFExchange...");
        CTFExchange exchangeContract = new CTFExchange(
            COLLATERAL,
            CTF,
            PROXY_FACTORY,
            SAFE_FACTORY
        );

        exchange = address(exchangeContract);

        console2.log("");
        console2.log("=== Deployment Successful ===");
        console2.log("CTFExchange deployed at:", exchange);
        console2.log("");
        console2.log("Configuration:");
        console2.log("  Collateral (USDC):", COLLATERAL);
        console2.log("  CTF:", CTF);
        console2.log("  Proxy Factory:", PROXY_FACTORY);
        console2.log("  Safe Factory:", SAFE_FACTORY);
        console2.log("  Deployer (Admin):", msg.sender);
        console2.log("");

        console2.log("=== Next Steps ===");
        console2.log("1. Add operator:");
        console2.log("   cast send", exchange);
        console2.log("     'addOperator(address)' <OPERATOR_ADDRESS>");
        console2.log("     --rpc-url $UNICHAIN_TESTNET_RPC --private-key $PRIVATE_KEY");
        console2.log("");
        console2.log("2. Register tokens:");
        console2.log("   cast send", exchange);
        console2.log("     'registerToken(uint256,uint256,bytes32)' <TOKEN0> <TOKEN1> <CONDITION_ID>");
        console2.log("     --rpc-url $UNICHAIN_TESTNET_RPC --private-key $PRIVATE_KEY");
        console2.log("");
        console2.log("3. Match orders using MatchOrders script:");
        console2.log("   forge script script/unichain/MatchOrders.s.sol:MatchOrders \\");
        console2.log("     --rpc-url $UNICHAIN_TESTNET_RPC \\");
        console2.log("     --broadcast -vvvv");
        console2.log("");
    }

    /**
     * @notice Setup exchange after deployment (optional)
     * @dev Call this after deployment to setup operator and initial configuration
     */
    function setupExchange(address operator) external  {
        require(exchange != address(0), "Deploy exchange first");
        require(operator != address(0), "Invalid operator");

        CTFExchange exchangeContract = CTFExchange(exchange);

        console2.log("=== Setting Up Exchange ===");
        console2.log("Exchange:", exchange);
        console2.log("Adding operator:", operator);

        exchangeContract.addOperator(operator);

        console2.log("Operator added successfully");
        console2.log("");
        console2.log("Exchange is ready for trading!");
    }
}
