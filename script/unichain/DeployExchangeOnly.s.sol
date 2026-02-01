// SPDX-License-Identifier: MIT
pragma solidity >=0.8.15;

import {console2, Script} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";

// CTF Exchange contracts only
import {ConditionalTokens} from "src/token/ConditionalTokens.sol";
import {CTFExchange} from "src/exchange/CTFExchange.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock collateral token for testing
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 10_000_000 * 10 ** 6); // 10M USDC
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Deploy CTFExchange and its dependencies ONLY
/// @dev This is the minimal deployment for the CTF Exchange
contract DeployExchangeOnly is BaseScript {
    function run() external {
        console2.log("=== Deploying CTF Exchange (Minimal) ===");
        console2.log("Deployer:", msg.sender);
        console2.log("");

        // 1. Deploy ConditionalTokens
        console2.log("1. Deploying ConditionalTokens...");
        ConditionalTokens ctf = new ConditionalTokens();
        console2.log("   ConditionalTokens:", address(ctf));
        console2.log("");

        // 2. Deploy Mock USDC (Collateral)
        console2.log("2. Deploying MockUSDC (Collateral)...");
        MockUSDC usdc = new MockUSDC();
        console2.log("   MockUSDC:", address(usdc));
        console2.log("   Initial Supply:", usdc.totalSupply() / 10 ** 6, "USDC");
        console2.log("");

        // 3. Deploy CTFExchange
        console2.log("3. Deploying CTFExchange...");
        // Note: ProxyFactory and SafeFactory set to address(0)
        // These are optional Polymarket-specific wallet features
        CTFExchange exchange = new CTFExchange(
            address(usdc), // collateral
            address(ctf), // conditional tokens
            address(0), // proxyFactory (not needed)
            address(0) // safeFactory (not needed)
        );
        console2.log("   CTFExchange:", address(exchange));
        console2.log("");

        // Summary
        console2.log("=== Deployment Summary ===");
        console2.log("ConditionalTokens:  ", address(ctf));
        console2.log("MockUSDC:           ", address(usdc));
        console2.log("CTFExchange:        ", address(exchange));
        console2.log("");

        console2.log("=== Next Steps ===");
        console2.log("1. Add operators to CTFExchange:");
        console2.log("   exchange.addOperator(operatorAddress)");
        console2.log("");
        console2.log("2. Register tokens for trading:");
        console2.log("   exchange.registerToken(tokenId, complementId, conditionId)");
        console2.log("");
        console2.log("3. Mint test USDC to users:");
        console2.log("   usdc.mint(userAddress, amount)");
        console2.log("");
        console2.log("=== Deployment Complete ===");
    }
}
