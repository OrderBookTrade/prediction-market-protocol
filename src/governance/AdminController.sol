// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AdminController
 * @notice Simplified administrative control for the protocol
 */
contract AdminController is Ownable {
    constructor(address initialOwner) Ownable(initialOwner) {}

    // Add additional admin roles or emergency controls here
}
