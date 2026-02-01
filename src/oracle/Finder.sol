// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {IFinder} from "./interfaces/IFinder.sol";

/**
 * @title Minimal Finder Implementation
 * @notice Simplified version of UMA's Finder to satisfy the registry requirements of the Adapter.
 */
contract Finder is IFinder {
    mapping(bytes32 => address) public interfaces;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function changeImplementationAddress(bytes32 interfaceName, address implementationAddress) external override {
        require(msg.sender == owner, "Not owner");
        interfaces[interfaceName] = implementationAddress;
    }

    function getImplementationAddress(bytes32 interfaceName) external view override returns (address) {
        return interfaces[interfaceName];
    }
}
