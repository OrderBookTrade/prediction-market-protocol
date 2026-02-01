// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ConditionalTokens} from "src/token/ConditionalTokens.sol";
import {MockERC20} from "src/token/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ConditionalTokensTest is Test {
    ConditionalTokens public ctf;
    MockERC20 public collateral;

    address public oracle = address(0x1);
    address public user = address(0x2);
    bytes32 public questionId = keccak256("Will ETH reach $10k?");
    uint256 public constant OUTCOME_COUNT = 2; // Binary market (YES/NO)

    function setUp() public {
        ctf = new ConditionalTokens();
        collateral = new MockERC20();

        // Mint collateral to user
        collateral.mint(user, 1000 ether);

        // User approves CTF to spend collateral
        vm.prank(user);
        collateral.approve(address(ctf), type(uint256).max);
    }

    function testPrepareCondition() public {
        vm.prank(oracle);
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);

        bytes32 conditionId = ctf.getConditionId(oracle, questionId, OUTCOME_COUNT);
        uint256 outcomeSlotCount = ctf.getOutcomeSlotCount(conditionId);
        // console2.log("outcomeSlotCount", outcomeSlotCount);

        assertEq(outcomeSlotCount, OUTCOME_COUNT);
    }

    function testCannotPrepareSameConditionTwice() public {
        vm.startPrank(oracle);
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);

        vm.expectRevert("condition already prepared");
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);
        vm.stopPrank();
    }

    function testReportPayouts() public {
        vm.prank(oracle);
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);

        bytes32 conditionId = ctf.getConditionId(oracle, questionId, OUTCOME_COUNT);

        // Oracle reports YES won (payout = [1, 0])
        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1; // YES wins
        payouts[1] = 0; // NO loses

        vm.prank(oracle);
        ctf.reportPayouts(questionId, payouts);

        // Check payout denominator is set (condition resolved)
        uint256 denominator = ctf.payoutDenominator(conditionId);
        assertEq(denominator, 1);
    }

    function testCannotReportPayoutsBeforePrepare() public {
        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1;
        payouts[1] = 0;

        vm.prank(oracle);
        vm.expectRevert("condition not prepared or found");
        ctf.reportPayouts(questionId, payouts);
    }

    function testOnlyOracleCanReport() public {
        vm.prank(oracle);
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);

        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1;
        payouts[1] = 0;

        // Non-oracle tries to report
        vm.prank(user);
        vm.expectRevert("condition not prepared or found");
        ctf.reportPayouts(questionId, payouts);
    }

    function testGetConditionId() public view {
        bytes32 conditionId = ctf.getConditionId(oracle, questionId, OUTCOME_COUNT);
        assertNotEq(conditionId, bytes32(0));
    }

    function testCannotPrepareWithTooManyOutcomes() public {
        vm.prank(oracle);
        vm.expectRevert("too many outcome slots");
        ctf.prepareCondition(oracle, questionId, 257);
    }

    function testCannotPrepareWithSingleOutcome() public {
        vm.prank(oracle);
        vm.expectRevert("there should be more than one outcome slot");
        ctf.prepareCondition(oracle, questionId, 1);
    }

    function testCannotReportAllZeroPayouts() public {
        vm.prank(oracle);
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);

        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 0;
        payouts[1] = 0;

        vm.prank(oracle);
        vm.expectRevert("payout is all zeroes");
        ctf.reportPayouts(questionId, payouts);
    }

    function testCannotReportPayoutsTwice() public {
        vm.prank(oracle);
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);

        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1;
        payouts[1] = 0;

        vm.startPrank(oracle);
        ctf.reportPayouts(questionId, payouts);

        vm.expectRevert("payout denominator already set");
        ctf.reportPayouts(questionId, payouts);
        vm.stopPrank();
    }

    // ============ Split Position Tests ============

    function testSplitPosition() public {
        // Prepare condition
        vm.prank(oracle);
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);

        bytes32 conditionId = ctf.getConditionId(oracle, questionId, OUTCOME_COUNT);
        uint256 amount = 100 ether;

        // Create partition: [0b01, 0b10] for 2 outcomes
        uint256[] memory partition = new uint256[](2);
        partition[0] = 1; // 0b01 - outcome 0
        partition[1] = 2; // 0b10 - outcome 1

        uint256 balanceBefore = collateral.balanceOf(user);

        vm.prank(user);
        ctf.splitPosition(IERC20(address(collateral)), bytes32(0), conditionId, partition, amount);

        // Verify collateral was transferred
        assertEq(collateral.balanceOf(user), balanceBefore - amount, "Collateral should be transferred");

        // Verify user received both outcome tokens
        bytes32 collection0 = ctf.getCollectionId(bytes32(0), conditionId, 1);
        bytes32 collection1 = ctf.getCollectionId(bytes32(0), conditionId, 2);
        uint256 tokenId0 = ctf.getPositionId(IERC20(address(collateral)), collection0);
        uint256 tokenId1 = ctf.getPositionId(IERC20(address(collateral)), collection1);

        assertEq(ctf.balanceOf(user, tokenId0), amount, "User should have outcome 0 tokens");
        assertEq(ctf.balanceOf(user, tokenId1), amount, "User should have outcome 1 tokens");
    }

    function testSplitPositionEmitsEvent() public {
        vm.prank(oracle);
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);

        bytes32 conditionId = ctf.getConditionId(oracle, questionId, OUTCOME_COUNT);
        uint256 amount = 100 ether;

        uint256[] memory partition = new uint256[](2);
        partition[0] = 1;
        partition[1] = 2;

        bytes32 collection0 = ctf.getCollectionId(bytes32(0), conditionId, 1);
        bytes32 collection1 = ctf.getCollectionId(bytes32(0), conditionId, 2);
        uint256 tokenId0 = ctf.getPositionId(IERC20(address(collateral)), collection0);
        uint256 tokenId1 = ctf.getPositionId(IERC20(address(collateral)), collection1);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit PositionSplit(user, address(collateral), bytes32(0), conditionId, partition, amount);
        ctf.splitPosition(IERC20(address(collateral)), bytes32(0), conditionId, partition, amount);
    }

    function testCannotSplitWithInvalidPartition() public {
        vm.prank(oracle);
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);

        bytes32 conditionId = ctf.getConditionId(oracle, questionId, OUTCOME_COUNT);

        // Empty partition
        uint256[] memory emptyPartition = new uint256[](0);

        vm.prank(user);
        vm.expectRevert();
        ctf.splitPosition(IERC20(address(collateral)), bytes32(0), conditionId, emptyPartition, 100 ether);
    }

    // ============ Merge Position Tests ============

    function testMergePositions() public {
        // First split
        vm.prank(oracle);
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);

        bytes32 conditionId = ctf.getConditionId(oracle, questionId, OUTCOME_COUNT);
        uint256 amount = 100 ether;

        uint256[] memory partition = new uint256[](2);
        partition[0] = 1;
        partition[1] = 2;

        vm.startPrank(user);
        uint256 balanceBefore = collateral.balanceOf(user);

        ctf.splitPosition(IERC20(address(collateral)), bytes32(0), conditionId, partition, amount);

        // Then merge back
        ctf.mergePositions(IERC20(address(collateral)), bytes32(0), conditionId, partition, amount);

        // Verify collateral was returned
        assertEq(collateral.balanceOf(user), balanceBefore, "Collateral should be returned");

        // Verify tokens are burned
        bytes32 collection0 = ctf.getCollectionId(bytes32(0), conditionId, 1);
        bytes32 collection1 = ctf.getCollectionId(bytes32(0), conditionId, 2);
        uint256 tokenId0 = ctf.getPositionId(IERC20(address(collateral)), collection0);
        uint256 tokenId1 = ctf.getPositionId(IERC20(address(collateral)), collection1);

        assertEq(ctf.balanceOf(user, tokenId0), 0, "Outcome 0 tokens should be burned");
        assertEq(ctf.balanceOf(user, tokenId1), 0, "Outcome 1 tokens should be burned");
        vm.stopPrank();
    }

    function testMergePositionsEmitsEvent() public {
        vm.prank(oracle);
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);

        bytes32 conditionId = ctf.getConditionId(oracle, questionId, OUTCOME_COUNT);
        uint256 amount = 100 ether;

        uint256[] memory partition = new uint256[](2);
        partition[0] = 1;
        partition[1] = 2;

        vm.startPrank(user);
        ctf.splitPosition(IERC20(address(collateral)), bytes32(0), conditionId, partition, amount);

        vm.expectEmit(true, true, true, true);
        emit PositionsMerge(user, address(collateral), bytes32(0), conditionId, partition, amount);
        ctf.mergePositions(IERC20(address(collateral)), bytes32(0), conditionId, partition, amount);
        vm.stopPrank();
    }

    function testCannotMergeWithoutTokens() public {
        vm.prank(oracle);
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);

        bytes32 conditionId = ctf.getConditionId(oracle, questionId, OUTCOME_COUNT);

        uint256[] memory partition = new uint256[](2);
        partition[0] = 1;
        partition[1] = 2;

        // Try to merge without having split first
        vm.prank(user);
        vm.expectRevert();
        ctf.mergePositions(IERC20(address(collateral)), bytes32(0), conditionId, partition, 100 ether);
    }

    // ============ Redeem Position Tests ============

    function testRedeemPositions() public {
        // Setup: prepare, split, and resolve
        vm.prank(oracle);
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);

        bytes32 conditionId = ctf.getConditionId(oracle, questionId, OUTCOME_COUNT);
        uint256 amount = 100 ether;

        uint256[] memory partition = new uint256[](2);
        partition[0] = 1;
        partition[1] = 2;

        uint256 balanceBefore = collateral.balanceOf(user);

        vm.prank(user);
        ctf.splitPosition(IERC20(address(collateral)), bytes32(0), conditionId, partition, amount);

        // Oracle resolves: outcome 0 wins
        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1; // outcome 0 wins
        payouts[1] = 0; // outcome 1 loses

        vm.prank(oracle);
        ctf.reportPayouts(questionId, payouts);

        // User redeems winning tokens
        uint256[] memory indexSets = new uint256[](1);
        indexSets[0] = 1; // outcome 0

        vm.prank(user);
        ctf.redeemPositions(IERC20(address(collateral)), bytes32(0), conditionId, indexSets);

        // Verify collateral was returned (full amount since outcome 0 won 100%)
        assertEq(collateral.balanceOf(user), balanceBefore, "Should receive full collateral for winning outcome");

        // Verify winning tokens are burned
        bytes32 collection0 = ctf.getCollectionId(bytes32(0), conditionId, 1);
        uint256 tokenId0 = ctf.getPositionId(IERC20(address(collateral)), collection0);
        assertEq(ctf.balanceOf(user, tokenId0), 0, "Winning tokens should be redeemed");
    }

    function testRedeemPositionsEmitsEvent() public {
        vm.prank(oracle);
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);

        bytes32 conditionId = ctf.getConditionId(oracle, questionId, OUTCOME_COUNT);
        uint256 amount = 100 ether;

        uint256[] memory partition = new uint256[](2);
        partition[0] = 1;
        partition[1] = 2;

        vm.prank(user);
        ctf.splitPosition(IERC20(address(collateral)), bytes32(0), conditionId, partition, amount);

        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1;
        payouts[1] = 0;

        vm.prank(oracle);
        ctf.reportPayouts(questionId, payouts);

        uint256[] memory indexSets = new uint256[](1);
        indexSets[0] = 1;

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit PayoutRedemption(user, address(collateral), bytes32(0), conditionId, indexSets, amount);
        ctf.redeemPositions(IERC20(address(collateral)), bytes32(0), conditionId, indexSets);
    }

    function testCannotRedeemBeforeResolution() public {
        vm.prank(oracle);
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);

        bytes32 conditionId = ctf.getConditionId(oracle, questionId, OUTCOME_COUNT);

        uint256[] memory indexSets = new uint256[](1);
        indexSets[0] = 1;

        vm.prank(user);
        vm.expectRevert("result for condition not received yet");
        ctf.redeemPositions(IERC20(address(collateral)), bytes32(0), conditionId, indexSets);
    }

    function testRedeemLosingPosition() public {
        // Setup
        vm.prank(oracle);
        ctf.prepareCondition(oracle, questionId, OUTCOME_COUNT);

        bytes32 conditionId = ctf.getConditionId(oracle, questionId, OUTCOME_COUNT);
        uint256 amount = 100 ether;

        uint256[] memory partition = new uint256[](2);
        partition[0] = 1;
        partition[1] = 2;

        uint256 balanceBefore = collateral.balanceOf(user);

        vm.prank(user);
        ctf.splitPosition(IERC20(address(collateral)), bytes32(0), conditionId, partition, amount);

        // Oracle resolves: outcome 0 wins, outcome 1 loses
        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1;
        payouts[1] = 0;

        vm.prank(oracle);
        ctf.reportPayouts(questionId, payouts);

        // Try to redeem losing tokens (outcome 1)
        uint256[] memory indexSets = new uint256[](1);
        indexSets[0] = 2; // outcome 1 (losing)

        vm.prank(user);
        ctf.redeemPositions(IERC20(address(collateral)), bytes32(0), conditionId, indexSets);

        // Should receive nothing
        assertEq(collateral.balanceOf(user), balanceBefore - amount, "Should receive nothing for losing outcome");
    }

    // ============ Event Declarations ============
    event PositionSplit(
        address indexed stakeholder,
        address collateralToken,
        bytes32 indexed parentCollectionId,
        bytes32 indexed conditionId,
        uint256[] partition,
        uint256 amount
    );

    event PositionsMerge(
        address indexed stakeholder,
        address collateralToken,
        bytes32 indexed parentCollectionId,
        bytes32 indexed conditionId,
        uint256[] partition,
        uint256 amount
    );

    event PayoutRedemption(
        address indexed redeemer,
        address indexed collateralToken,
        bytes32 indexed parentCollectionId,
        bytes32 conditionId,
        uint256[] indexSets,
        uint256 payout
    );
}
