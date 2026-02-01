// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IAddressWhitelist} from "./interfaces/IAddressWhitelist.sol";

/**
 * @title Minimal Address Whitelist Implementation
 * @notice Simplified version for local/testnet development that allows all addresses or a specific subset.
 */
contract SimpleAddressWhitelist is IAddressWhitelist {
    mapping(address => bool) public whitelist;
    address public owner;
    bool public allowAll;

    constructor(bool _allowAll) {
        owner = msg.sender;
        allowAll = _allowAll;
    }

    function setAllowAll(bool _allowAll) external {
        require(msg.sender == owner, "Not owner");
        allowAll = _allowAll;
    }

    function addToWhitelist(address addr) external override {
        require(msg.sender == owner, "Not owner");
        whitelist[addr] = true;
    }

    function removeFromWhitelist(address addr) external override {
        require(msg.sender == owner, "Not owner");
        whitelist[addr] = false;
    }

    function isOnWhitelist(address addr) external view override returns (bool) {
        if (allowAll) return true;
        return whitelist[addr];
    }

    function getWhitelist() external view override returns (address[] memory) {
        // Not implemented for this simple version
        return new address[](0);
    }
}
