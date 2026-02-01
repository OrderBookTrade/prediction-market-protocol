// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test, console2} from "forge-std/Test.sol";
import {UmaCtfAdapter} from "src/oracle/IUmaCtfAdapterEE.sol";
import {UmaCompatibleOptimisticOracle} from "src/oracle/UmaCompatibleOptimisticOracle.sol";
import {ConditionalTokens} from "src/token/ConditionalTokens.sol";
import {MockERC20} from "src/token/MockERC20.sol";
import {Finder} from "src/oracle/Finder.sol";
import {SimpleAddressWhitelist} from "src/oracle/SimpleAddressWhitelist.sol";
import {QuestionData, IUmaCtfAdapterEE} from "src/oracle/interfaces/IIUmaCtfAdapterEE.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UmaCtfAdapterTest is Test {
    UmaCtfAdapter public adapter;
    UmaCompatibleOptimisticOracle public oracle;
    ConditionalTokens public ctf;
    MockERC20 public rewardToken;
    Finder public finder;
    SimpleAddressWhitelist public whitelist;

    address public admin = address(this);
    address public user = address(0x1);
    address public proposer = address(0x2);

    bytes32 public constant YES_OR_NO_IDENTIFIER = "YES_OR_NO_QUERY";
    uint256 public constant DEFAULT_LIVENESS = 7200; // 2 hours
    uint256 public constant SAFETY_PERIOD = 1 hours;

    event QuestionInitialized(
        bytes32 indexed questionID,
        uint256 indexed requestTimestamp,
        address indexed creator,
        bytes ancillaryData,
        address rewardToken,
        uint256 reward,
        uint256 proposalBond
    );
    event QuestionResolved(bytes32 indexed questionID, int256 settledPrice, uint256[] payouts);
    event QuestionFlagged(bytes32 indexed questionID);
    event QuestionUnflagged(bytes32 indexed questionID);
    event QuestionPaused(bytes32 indexed questionID);
    event QuestionUnpaused(bytes32 indexed questionID);
    event QuestionReset(bytes32 indexed questionID);
    event QuestionManuallyResolved(bytes32 indexed questionID, uint256[] payouts);

    function setUp() public {
        // Deploy core contracts
        ctf = new ConditionalTokens();
        oracle = new UmaCompatibleOptimisticOracle(DEFAULT_LIVENESS, admin);
        rewardToken = new MockERC20();

        // Deploy Finder and Whitelist
        finder = new Finder();
        whitelist = new SimpleAddressWhitelist(false); // Start with whitelist mode

        // Register CollateralWhitelist in Finder
        finder.changeImplementationAddress(keccak256(abi.encodePacked("CollateralWhitelist")), address(whitelist));

        // Deploy UmaCtfAdapter
        adapter = new UmaCtfAdapter(address(ctf), address(finder), address(oracle));

        // Whitelist reward token
        whitelist.addToWhitelist(address(rewardToken));

        // Whitelist proposer in oracle
        oracle.whitelistProposer(proposer, true);

        // Mint tokens to user
        rewardToken.mint(user, 1000 ether);

        // User approves adapter
        vm.prank(user);
        rewardToken.approve(address(adapter), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testConstructor() public {
        assertEq(address(adapter.ctf()), address(ctf));
        assertEq(address(adapter.optimisticOracle()), address(oracle));
        assertEq(address(adapter.collateralWhitelist()), address(whitelist));
    }

    function testInitializeQuestion() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k by 2025?");
        uint256 reward = 100 ether;
        uint256 proposalBond = 50 ether;
        uint256 liveness = 3600;

        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), reward, proposalBond, liveness);

        // Verify question data
        QuestionData memory question = adapter.getQuestion(questionID);
        assertEq(question.requestTimestamp, block.timestamp);
        assertEq(question.reward, reward);
        assertEq(question.proposalBond, proposalBond);
        assertEq(question.liveness, liveness);
        assertEq(question.rewardToken, address(rewardToken));
        assertEq(question.creator, user);
        assertFalse(question.resolved);
        assertFalse(question.paused);

        // Verify condition is prepared on CTF
        bytes32 conditionId = ctf.getConditionId(address(adapter), questionID, 2);
        assertEq(ctf.getOutcomeSlotCount(conditionId), 2);
    }

    function testInitializeWithUnsupportedToken() public {
        MockERC20 unsupportedToken = new MockERC20();
        bytes memory ancillaryData = abi.encodePacked("Q: Test question?");

        vm.prank(user);
        vm.expectRevert(IUmaCtfAdapterEE.UnsupportedToken.selector);
        adapter.initialize(ancillaryData, address(unsupportedToken), 100 ether, 50 ether, 3600);
    }

    function testInitializeWithEmptyAncillaryData() public {
        bytes memory ancillaryData = "";

        vm.prank(user);
        vm.expectRevert(IUmaCtfAdapterEE.InvalidAncillaryData.selector);
        adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);
    }

    function testCannotInitializeSameQuestionTwice() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");

        vm.startPrank(user);
        adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        vm.expectRevert(IUmaCtfAdapterEE.Initialized.selector);
        adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            RESOLUTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testResolveQuestionYes() public {
        // Initialize question
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        QuestionData memory question = adapter.getQuestion(questionID);

        // Propose price (YES = 1 ether)
        vm.prank(proposer);
        oracle.proposePrice(address(adapter), YES_OR_NO_IDENTIFIER, question.requestTimestamp, question.ancillaryData, 1 ether);

        // Wait for liveness
        vm.warp(block.timestamp + 3601);

        // Resolve
        adapter.resolve(questionID);

        // Verify resolution
        QuestionData memory resolvedQuestion = adapter.getQuestion(questionID);
        assertTrue(resolvedQuestion.resolved);
    }

    function testResolveQuestionNo() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        QuestionData memory question = adapter.getQuestion(questionID);

        // Propose price (NO = 0)
        vm.prank(proposer);
        oracle.proposePrice(address(adapter), YES_OR_NO_IDENTIFIER, question.requestTimestamp, question.ancillaryData, 0);

        // Wait for liveness
        vm.warp(block.timestamp + 3601);

        adapter.resolve(questionID);

        QuestionData memory resolvedQuestion = adapter.getQuestion(questionID);
        assertTrue(resolvedQuestion.resolved);
    }

    function testCannotResolveUninitializedQuestion() public {
        bytes32 fakeQuestionID = keccak256("fake");
        vm.expectRevert(IUmaCtfAdapterEE.NotInitialized.selector);
        adapter.resolve(fakeQuestionID);
    }

    function testCannotResolveWithoutPrice() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        vm.expectRevert(IUmaCtfAdapterEE.NotReadyToResolve.selector);
        adapter.resolve(questionID);
    }

    function testCannotResolveAlreadyResolvedQuestion() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        QuestionData memory question = adapter.getQuestion(questionID);

        vm.prank(proposer);
        oracle.proposePrice(address(adapter), YES_OR_NO_IDENTIFIER, question.requestTimestamp, question.ancillaryData, 1 ether);

        vm.warp(block.timestamp + 3601);
        adapter.resolve(questionID);

        vm.expectRevert(IUmaCtfAdapterEE.Resolved.selector);
        adapter.resolve(questionID);
    }

    function testCannotResolvePausedQuestion() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        adapter.pause(questionID);

        QuestionData memory question = adapter.getQuestion(questionID);

        vm.prank(proposer);
        oracle.proposePrice(address(adapter), YES_OR_NO_IDENTIFIER, question.requestTimestamp, question.ancillaryData, 1 ether);

        vm.warp(block.timestamp + 3601);

        vm.expectRevert(IUmaCtfAdapterEE.Paused.selector);
        adapter.resolve(questionID);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function testFlag() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        adapter.flag(questionID);

        QuestionData memory question = adapter.getQuestion(questionID);
        assertTrue(question.paused);
        assertEq(question.manualResolutionTimestamp, block.timestamp + SAFETY_PERIOD);
        assertTrue(adapter.isFlagged(questionID));
    }

    function testUnflag() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        adapter.flag(questionID);
        adapter.unflag(questionID);

        QuestionData memory question = adapter.getQuestion(questionID);
        assertFalse(question.paused);
        assertEq(question.manualResolutionTimestamp, 0);
        assertFalse(adapter.isFlagged(questionID));
    }

    function testCannotUnflagAfterSafetyPeriod() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        adapter.flag(questionID);
        vm.warp(block.timestamp + SAFETY_PERIOD + 1);

        vm.expectRevert(IUmaCtfAdapterEE.SafetyPeriodPassed.selector);
        adapter.unflag(questionID);
    }

    function testPause() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        adapter.pause(questionID);

        QuestionData memory question = adapter.getQuestion(questionID);
        assertTrue(question.paused);
    }

    function testUnpause() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        adapter.pause(questionID);
        adapter.unpause(questionID);

        QuestionData memory question = adapter.getQuestion(questionID);
        assertFalse(question.paused);
    }

    function testResolveManually() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        adapter.flag(questionID);
        vm.warp(block.timestamp + SAFETY_PERIOD + 1);

        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1; // YES
        payouts[1] = 0; // NO

        adapter.resolveManually(questionID, payouts);

        QuestionData memory question = adapter.getQuestion(questionID);
        assertTrue(question.resolved);
    }

    function testCannotResolveManuallyWithoutFlag() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1;
        payouts[1] = 0;

        vm.expectRevert(IUmaCtfAdapterEE.NotFlagged.selector);
        adapter.resolveManually(questionID, payouts);
    }

    function testCannotResolveManuallyBeforeSafetyPeriod() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        adapter.flag(questionID);

        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1;
        payouts[1] = 0;

        vm.expectRevert(IUmaCtfAdapterEE.SafetyPeriodNotPassed.selector);
        adapter.resolveManually(questionID, payouts);
    }

    function testCannotResolveManuallyWithInvalidPayouts() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        adapter.flag(questionID);
        vm.warp(block.timestamp + SAFETY_PERIOD + 1);

        uint256[] memory payouts = new uint256[](3);
        payouts[0] = 1;
        payouts[1] = 0;
        payouts[2] = 0;

        vm.expectRevert(IUmaCtfAdapterEE.InvalidPayouts.selector);
        adapter.resolveManually(questionID, payouts);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER VIEW TESTS
    //////////////////////////////////////////////////////////////*/

    function testIsInitialized() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        assertTrue(adapter.isInitialized(questionID));

        bytes32 fakeQuestionID = keccak256("fake");
        assertFalse(adapter.isInitialized(fakeQuestionID));
    }

    function testIsFlagged() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        assertFalse(adapter.isFlagged(questionID));

        adapter.flag(questionID);
        assertTrue(adapter.isFlagged(questionID));
    }

    function testReady() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        // Not ready without price
        assertFalse(adapter.ready(questionID));

        QuestionData memory question = adapter.getQuestion(questionID);

        // Propose price
        vm.prank(proposer);
        oracle.proposePrice(address(adapter), YES_OR_NO_IDENTIFIER, question.requestTimestamp, question.ancillaryData, 1 ether);

        // Still not ready during liveness
        assertFalse(adapter.ready(questionID));

        // Ready after liveness
        vm.warp(block.timestamp + 3601);
        assertTrue(adapter.ready(questionID));
    }

    function testGetExpectedPayouts() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        QuestionData memory question = adapter.getQuestion(questionID);

        // Propose YES
        vm.prank(proposer);
        oracle.proposePrice(address(adapter), YES_OR_NO_IDENTIFIER, question.requestTimestamp, question.ancillaryData, 1 ether);

        vm.warp(block.timestamp + 3601);

        uint256[] memory payouts = adapter.getExpectedPayouts(questionID);
        assertEq(payouts.length, 2);
        assertEq(payouts[0], 1); // YES
        assertEq(payouts[1], 0); // NO
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL TESTS
    //////////////////////////////////////////////////////////////*/

    function testOnlyAdminCanFlag() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        vm.prank(user);
        vm.expectRevert(IUmaCtfAdapterEE.NotAdmin.selector);
        adapter.flag(questionID);
    }

    function testOnlyAdminCanPause() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        vm.prank(user);
        vm.expectRevert(IUmaCtfAdapterEE.NotAdmin.selector);
        adapter.pause(questionID);
    }

    function testOnlyAdminCanResolveManually() public {
        bytes memory ancillaryData = abi.encodePacked("Q: Will ETH reach $10k?");
        vm.prank(user);
        bytes32 questionID = adapter.initialize(ancillaryData, address(rewardToken), 100 ether, 50 ether, 3600);

        adapter.flag(questionID);
        vm.warp(block.timestamp + SAFETY_PERIOD + 1);

        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1;
        payouts[1] = 0;

        vm.prank(user);
        vm.expectRevert(IUmaCtfAdapterEE.NotAdmin.selector);
        adapter.resolveManually(questionID, payouts);
    }
}
