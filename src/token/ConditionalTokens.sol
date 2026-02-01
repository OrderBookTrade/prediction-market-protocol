// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SimpleCTHelpers} from "src/library/SimpleCTHelpers.sol";

contract ConditionalTokens is ERC1155 {
    /// @dev Emitted upon the successful preparation of a condition.
    event ConditionPreparation(
        bytes32 indexed conditionId, address indexed oracle, bytes32 indexed questionId, uint256 outcomeSlotCount
    );

    event ConditionResolution(
        bytes32 indexed conditionId,
        address indexed oracle,
        bytes32 indexed questionId,
        uint256 outcomeSlotCount,
        uint256[] payoutNumerators
    );

    /// @dev Emitted when a position is successfully split.
    event PositionSplit(
        address indexed stakeholder,
        IERC20 collateralToken,
        bytes32 indexed parentCollectionId,
        bytes32 indexed conditionId,
        uint256[] partition,
        uint256 amount
    );
    /// @dev Emitted when positions are successfully merged.
    event PositionsMerge(
        address indexed stakeholder,
        IERC20 collateralToken,
        bytes32 indexed parentCollectionId,
        bytes32 indexed conditionId,
        uint256[] partition,
        uint256 amount
    );
    event PayoutRedemption(
        address indexed redeemer,
        IERC20 indexed collateralToken,
        bytes32 indexed parentCollectionId,
        bytes32 conditionId,
        uint256[] indexSets,
        uint256 payout
    );

    /// Mapping key is an condition ID. Value represents numerators of the payout vector associated with the condition.
    mapping(bytes32 => uint256[]) public payoutNumerators;
    /// Denominator is also used for checking if the condition has been resolved.
    mapping(bytes32 => uint256) public payoutDenominator;

    constructor() ERC1155("") {}

    /// @dev This function prepares a condition by initializing a payout vector associated with the condition.
    /// @param oracle The account assigned to report the result for the prepared condition.
    /// @param questionId An identifier for the question to be answered by the oracle.
    /// @param outcomeSlotCount The number of outcome slots which should be used for this condition. Must not exceed 256.
    function prepareCondition(address oracle, bytes32 questionId, uint256 outcomeSlotCount) external {
        // Limit of 256 because we use a partition array that is a number of 256 bits.
        require(outcomeSlotCount <= 256, "too many outcome slots");
        require(outcomeSlotCount > 1, "there should be more than one outcome slot");
        bytes32 conditionId = SimpleCTHelpers.getConditionId(oracle, questionId, outcomeSlotCount);
        require(payoutNumerators[conditionId].length == 0, "condition already prepared");
        payoutNumerators[conditionId] = new uint256[](outcomeSlotCount);
        emit ConditionPreparation(conditionId, oracle, questionId, outcomeSlotCount);
    }

    /// @dev Called by the oracle for reporting results of conditions.
    /// @param questionId The question ID the oracle is answering for
    /// @param payouts The oracle's answer
    function reportPayouts(bytes32 questionId, uint256[] calldata payouts) external {
        uint256 outcomeSlotCount = payouts.length;
        require(outcomeSlotCount > 1, "there should be more than one outcome slot");
        bytes32 conditionId = SimpleCTHelpers.getConditionId(msg.sender, questionId, outcomeSlotCount);
        require(payoutNumerators[conditionId].length == outcomeSlotCount, "condition not prepared or found");
        require(payoutDenominator[conditionId] == 0, "payout denominator already set");

        uint256 den = 0;
        for (uint256 i = 0; i < outcomeSlotCount; i++) {
            uint256 num = payouts[i];
            den += num;

            require(payoutNumerators[conditionId][i] == 0, "payout numerator already set");
            payoutNumerators[conditionId][i] = num;
        }
        require(den > 0, "payout is all zeroes");
        payoutDenominator[conditionId] = den;
        emit ConditionResolution(conditionId, msg.sender, questionId, outcomeSlotCount, payoutNumerators[conditionId]);
    }

    /// @dev This function splits a position.
    function splitPosition(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata partition,
        uint256 amount
    ) external {
        require(partition.length > 1, "got empty or singleton partition");
        uint256 outcomeSlotCount = payoutNumerators[conditionId].length;
        require(outcomeSlotCount > 0, "condition not prepared yet");

        uint256 fullIndexSet = (1 << outcomeSlotCount) - 1;
        uint256 freeIndexSet = fullIndexSet;
        uint256[] memory positionIds = new uint256[](partition.length);
        uint256[] memory amounts = new uint256[](partition.length);
        for (uint256 i = 0; i < partition.length; i++) {
            uint256 indexSet = partition[i];
            require(indexSet > 0 && indexSet < fullIndexSet, "got invalid index set");
            require((indexSet & freeIndexSet) == indexSet, "partition not disjoint");
            freeIndexSet ^= indexSet;
            positionIds[i] = SimpleCTHelpers.getPositionId(
                collateralToken, SimpleCTHelpers.getCollectionId(parentCollectionId, conditionId, indexSet)
            );
            amounts[i] = amount;
        }

        if (freeIndexSet == 0) {
            if (parentCollectionId == bytes32(0)) {
                require(
                    collateralToken.transferFrom(msg.sender, address(this), amount),
                    "could not receive collateral tokens"
                );
            } else {
                _burn(msg.sender, SimpleCTHelpers.getPositionId(collateralToken, parentCollectionId), amount);
            }
        } else {
            _burn(
                msg.sender,
                SimpleCTHelpers.getPositionId(
                    collateralToken,
                    SimpleCTHelpers.getCollectionId(parentCollectionId, conditionId, fullIndexSet ^ freeIndexSet)
                ),
                amount
            );
        }

        _mintBatch(msg.sender, positionIds, amounts, "");
        emit PositionSplit(msg.sender, collateralToken, parentCollectionId, conditionId, partition, amount);
    }

    function mergePositions(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata partition,
        uint256 amount
    ) external {
        require(partition.length > 1, "got empty or singleton partition");
        uint256 outcomeSlotCount = payoutNumerators[conditionId].length;
        require(outcomeSlotCount > 0, "condition not prepared yet");

        uint256 fullIndexSet = (1 << outcomeSlotCount) - 1;
        uint256 freeIndexSet = fullIndexSet;
        uint256[] memory positionIds = new uint256[](partition.length);
        uint256[] memory amounts = new uint256[](partition.length);
        for (uint256 i = 0; i < partition.length; i++) {
            uint256 indexSet = partition[i];
            require(indexSet > 0 && indexSet < fullIndexSet, "got invalid index set");
            require((indexSet & freeIndexSet) == indexSet, "partition not disjoint");
            freeIndexSet ^= indexSet;
            positionIds[i] = SimpleCTHelpers.getPositionId(
                collateralToken, SimpleCTHelpers.getCollectionId(parentCollectionId, conditionId, indexSet)
            );
            amounts[i] = amount;
        }
        _burnBatch(msg.sender, positionIds, amounts);

        if (freeIndexSet == 0) {
            if (parentCollectionId == bytes32(0)) {
                require(collateralToken.transfer(msg.sender, amount), "could not send collateral tokens");
            } else {
                _mint(msg.sender, SimpleCTHelpers.getPositionId(collateralToken, parentCollectionId), amount, "");
            }
        } else {
            _mint(
                msg.sender,
                SimpleCTHelpers.getPositionId(
                    collateralToken,
                    SimpleCTHelpers.getCollectionId(parentCollectionId, conditionId, fullIndexSet ^ freeIndexSet)
                ),
                amount,
                ""
            );
        }

        emit PositionsMerge(msg.sender, collateralToken, parentCollectionId, conditionId, partition, amount);
    }

    function redeemPositions(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata indexSets
    ) external {
        uint256 den = payoutDenominator[conditionId];
        require(den > 0, "result for condition not received yet");
        uint256 outcomeSlotCount = payoutNumerators[conditionId].length;
        require(outcomeSlotCount > 0, "condition not prepared yet");

        uint256 totalPayout = 0;

        uint256 fullIndexSet = (1 << outcomeSlotCount) - 1;
        for (uint256 i = 0; i < indexSets.length; i++) {
            uint256 indexSet = indexSets[i];
            require(indexSet > 0 && indexSet < fullIndexSet, "got invalid index set");
            uint256 positionId = SimpleCTHelpers.getPositionId(
                collateralToken, SimpleCTHelpers.getCollectionId(parentCollectionId, conditionId, indexSet)
            );

            uint256 payoutNumerator = 0;
            for (uint256 j = 0; j < outcomeSlotCount; j++) {
                if (indexSet & (1 << j) != 0) {
                    payoutNumerator += payoutNumerators[conditionId][j];
                }
            }

            uint256 payoutStake = balanceOf(msg.sender, positionId);
            if (payoutStake > 0) {
                totalPayout += (payoutStake * payoutNumerator) / den;
                _burn(msg.sender, positionId, payoutStake);
            }
        }

        if (totalPayout > 0) {
            if (parentCollectionId == bytes32(0)) {
                require(
                    collateralToken.transfer(msg.sender, totalPayout), "could not transfer payout to message sender"
                );
            } else {
                _mint(msg.sender, SimpleCTHelpers.getPositionId(collateralToken, parentCollectionId), totalPayout, "");
            }
        }
        emit PayoutRedemption(msg.sender, collateralToken, parentCollectionId, conditionId, indexSets, totalPayout);
    }

    function getOutcomeSlotCount(bytes32 conditionId) external view returns (uint256) {
        return payoutNumerators[conditionId].length;
    }

    function getConditionId(address oracle, bytes32 questionId, uint256 outcomeSlotCount)
        external
        pure
        returns (bytes32)
    {
        return SimpleCTHelpers.getConditionId(oracle, questionId, outcomeSlotCount);
    }

    function getCollectionId(bytes32 parentCollectionId, bytes32 conditionId, uint256 indexSet)
        external
        view
        returns (bytes32)
    {
        return SimpleCTHelpers.getCollectionId(parentCollectionId, conditionId, indexSet);
    }

    function getPositionId(IERC20 collateralToken, bytes32 collectionId) external pure returns (uint256) {
        return SimpleCTHelpers.getPositionId(collateralToken, collectionId);
    }
}
