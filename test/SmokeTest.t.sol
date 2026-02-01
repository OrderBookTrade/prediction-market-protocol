// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

contract SmokeTest is Test {
    address public admin = address(0x1);
    address public oracle = address(0x2);
    address public collateral = address(0x3);

    function setUp() public {
        vm.startPrank(admin);

        vm.stopPrank();
    }
}
