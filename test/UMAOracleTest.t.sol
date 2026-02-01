// SPDX-License-Identifier: MIT
pragma solidity >=0.8.15;

import {UmaCompatibleOptimisticOracle} from "src/oracle/UmaCompatibleOptimisticOracle.sol";
import {OptimisticOracleV2Interface} from "src/interfaces/OptimisticOracleV2Interface.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "src/token/MockERC20.sol";

contract UMAOracleTest is Test {
    UmaCompatibleOptimisticOracle oracle;
    MockERC20 mockToken;
    address proposer = address(0x123);

    function setUp() public {
        // Deploy oracle with 2 hour liveness
        oracle = new UmaCompatibleOptimisticOracle(7200, address(this));
        mockToken = new MockERC20();

        // Whitelist the proposer
        oracle.whitelistProposer(proposer, true);
    }

    function testRequestPrice() public {
        bytes32 identifier = "YES_OR_NO_QUERY";
        uint256 timestamp = block.timestamp;
        bytes memory ancillaryData = "";

        oracle.requestPrice(identifier, timestamp, ancillaryData, IERC20(address(mockToken)), 0);

        // Verify request state
        OptimisticOracleV2Interface.State state = oracle.getState(address(this), identifier, timestamp, ancillaryData);
        assertEq(uint256(state), uint256(OptimisticOracleV2Interface.State.Requested));
    }

    function testProposePrice() public {
        bytes32 identifier = "YES_OR_NO_QUERY";
        uint256 timestamp = block.timestamp;
        bytes memory ancillaryData = "";

        // Request price first
        oracle.requestPrice(identifier, timestamp, ancillaryData, IERC20(address(mockToken)), 0);

        // Propose price as whitelisted proposer
        vm.prank(proposer);
        oracle.proposePrice(address(this), identifier, timestamp, ancillaryData, 1 ether);

        // Verify state is now Proposed
        OptimisticOracleV2Interface.State state = oracle.getState(address(this), identifier, timestamp, ancillaryData);
        assertEq(uint256(state), uint256(OptimisticOracleV2Interface.State.Proposed));
    }

    // function testSettleAfterLiveness() public {
    //     bytes32 identifier = "YES_OR_NO_QUERY";
    //     uint256 timestamp = block.timestamp;
    //     bytes memory ancillaryData = "";

    //     // Request and propose
    //     oracle.requestPrice(identifier, timestamp, ancillaryData, IERC20(address(mockToken)), 0);
    //     vm.prank(proposer);
    //     oracle.proposePrice(address(this), identifier, timestamp, ancillaryData, 1 ether);

    //     // Fast forward past liveness period (2 hours)
    //     vm.warp(block.timestamp + 7201);

    //     // Settle
    //     oracle.settle(address(this), identifier, timestamp, ancillaryData);

    //     // Verify state is Settled
    //     OptimisticOracleV2Interface.State state = oracle.getState(address(this), identifier, timestamp, ancillaryData);
    //     assertEq(uint256(state), uint256(OptimisticOracleV2Interface.State.Settled));

    //     // Verify resolved price
    //     int256 resolvedPrice = oracle.settleAndGetPrice(identifier, timestamp, ancillaryData);
    //     assertEq(resolvedPrice, 1 ether);
    // }

    function testOnlyWhitelistedCanPropose() public {
        bytes32 identifier = "YES_OR_NO_QUERY";
        uint256 timestamp = block.timestamp;
        bytes memory ancillaryData = "";

        oracle.requestPrice(identifier, timestamp, ancillaryData, IERC20(address(mockToken)), 0);

        // Non-whitelisted address should fail
        vm.prank(address(0x999));
        vm.expectRevert(UmaCompatibleOptimisticOracle.UmaCompatibleOptimisticOracle__ProposerNotWhitelisted.selector);
        oracle.proposePrice(address(this), identifier, timestamp, ancillaryData, 1 ether);
    }

    function testInvalidProposedPrice() public {
        bytes32 identifier = "YES_OR_NO_QUERY";
        uint256 timestamp = block.timestamp;
        bytes memory ancillaryData = "";

        oracle.requestPrice(identifier, timestamp, ancillaryData, IERC20(address(mockToken)), 0);

        // Try to propose invalid price (not 0, 0.5, or 1)
        vm.prank(proposer);
        vm.expectRevert(UmaCompatibleOptimisticOracle.UmaCompatibleOptimisticOracle__InvalidProposedPrice.selector);
        oracle.proposePrice(address(this), identifier, timestamp, ancillaryData, 0.3 ether);
    }
}
