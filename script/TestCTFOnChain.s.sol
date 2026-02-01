// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ConditionalTokens} from "src/token/ConditionalTokens.sol";
import {MockERC20} from "src/token/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Test ConditionalTokens on Unichain Sepolia
 * @notice This script tests splitPosition on the deployed CTF contract
 * @dev Run with: forge script script/TestCTFOnChain.s.sol --rpc-url https://sepolia.unichain.org --broadcast
 */
contract TestCTFOnChain is Script {
    ConditionalTokens ctf = ConditionalTokens(0x9344c66bfB9ae35D6381BE26937f4388B84B01a0);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRI_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Testing CTF at:", address(ctf));
        console2.log("Deployer:", deployer);

        // Deploy collateral BEFORE broadcast to get a different address
        MockERC20 collateral = new MockERC20();
        console2.log("Deployed MockERC20 at:", address(collateral));

        // Mint to deployer
        collateral.mint(deployer, 1000 ether);

        vm.startBroadcast(deployerPrivateKey);

        // 2. Prepare condition
        bytes32 questionId = keccak256("Test: Will this work?");
        uint256 outcomeCount = 2;

        ctf.prepareCondition(deployer, questionId, outcomeCount);
        bytes32 conditionId = ctf.getConditionId(deployer, questionId, outcomeCount);
        console2.log("Prepared condition:");
        console2.logBytes32(conditionId);

        // 3. Approve CTF to spend collateral
        collateral.approve(address(ctf), type(uint256).max);
        console2.log("Approved CTF to spend collateral");

        // 4. Split position (THIS IS THE TEST!)
        uint256[] memory partition = new uint256[](2);
        partition[0] = 1; // outcome 0
        partition[1] = 2; // outcome 1
        uint256 amount = 100 ether;

        console2.log("Attempting splitPosition with amount:", amount);
        ctf.splitPosition(IERC20(address(collateral)), bytes32(0), conditionId, partition, amount);
        console2.log("SUCCESS! splitPosition worked on-chain!");

        // 5. Verify balances
        bytes32 collection0 = ctf.getCollectionId(bytes32(0), conditionId, 1);
        bytes32 collection1 = ctf.getCollectionId(bytes32(0), conditionId, 2);
        uint256 tokenId0 = ctf.getPositionId(IERC20(address(collateral)), collection0);
        uint256 tokenId1 = ctf.getPositionId(IERC20(address(collateral)), collection1);

        uint256 balance0 = ctf.balanceOf(deployer, tokenId0);
        uint256 balance1 = ctf.balanceOf(deployer, tokenId1);

        console2.log("Outcome 0 token balance:", balance0);
        console2.log("Outcome 1 token balance:", balance1);

        require(balance0 == amount, "Outcome 0 balance mismatch");
        require(balance1 == amount, "Outcome 1 balance mismatch");

        console2.log("All checks passed! CTF is fully functional on-chain.");

        vm.stopBroadcast();
    }
}
