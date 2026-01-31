// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import {BaseScript} from "../BaseScript.s.sol";
// import {AdminController} from "../../src/governance/AdminController.sol";
// import {OutcomeTokenFactory} from "../../src/outcome/OutcomeTokenFactory.sol";
// import {MarketRegistry} from "../../src/core/MarketRegistry.sol";
// import {MarketFactory} from "../../src/core/MarketFactory.sol";
// import {UmaCompatibleOptimisticOracle} from "../../src/oracle/UmaCompatibleOptimisticOracle.sol";
// import {console2} from "forge-std/Script.sol";

// /**
//  * @title DeployUnichain
//  * @notice Deployment script for Prediction Market Protocol on Unichain Sepolia
//  */
// contract DeployUnichain is BaseScript {
//     function run() external {
//         console2.log("Deploying Prediction Market Protocol to Unichain Sepolia...");

//         // --- Phase 1: Governance & Infrastructure ---

//         console2.log("Phase 1: Deploying Governance & Infrastructure...");

//         AdminController adminController = new AdminController(msg.sender);
//         console2.log("AdminController deployed at:", address(adminController));

//         OutcomeTokenFactory outcomeTokenFactory = new OutcomeTokenFactory();
//         console2.log("OutcomeTokenFactory deployed at:", address(outcomeTokenFactory));

//         MarketRegistry marketRegistry = new MarketRegistry(address(adminController));
//         console2.log("MarketRegistry deployed at:", address(marketRegistry));

//         // --- Phase 2: Core Logic & Orchestration ---

//         console2.log("Phase 2: Deploying Core Logic...");

//         MarketFactory marketFactory =
//             new MarketFactory(address(marketRegistry), address(outcomeTokenFactory), address(adminController));
//         console2.log("MarketFactory deployed at:", address(marketFactory));

//         console2.log("Configuring OutcomeTokenFactory...");
//         outcomeTokenFactory.setMarketFactory(address(marketFactory));
//         console2.log("MarketFactory authorized in OutcomeTokenFactory");

//         // --- Phase 3: External Integrations (UMA Oracle) ---

//         console2.log("Phase 3: Deploying Oracle Components...");

//         uint256 defaultLiveness = 7200; // 2 hours
//         UmaCompatibleOptimisticOracle oracle = new UmaCompatibleOptimisticOracle(
//             defaultLiveness,
//             msg.sender // Deployer as initial owner
//         );
//         console2.log("UmaCompatibleOptimisticOracle deployed at:", address(oracle));

//         vm.stopBroadcast();

//         console2.log("----------------------------------------------");
//         console2.log("Deployment Complete!");
//         console2.log("Summary of addresses:");
//         console2.log("AdminController:", address(adminController));
//         console2.log("OutcomeTokenFactory:", address(outcomeTokenFactory));
//         console2.log("MarketRegistry:", address(marketRegistry));
//         console2.log("MarketFactory:", address(marketFactory));
//         console2.log("UMA Oracle:", address(oracle));
//     }
// }
