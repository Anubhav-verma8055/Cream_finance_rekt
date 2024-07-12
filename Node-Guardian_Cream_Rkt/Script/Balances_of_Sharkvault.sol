// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";

import {ReentrancyAttack} from "../Src/Contracts/ReentrancyAttack.sol";

import {SharkVault, IERC20} from "../Src/Contracts/FlashLoan.sol";

contract POC is Script {
    function run() external {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address INSTANCE = vm.envAddress("INSTANCE");

        vm.startBroadcast(deployerPrivateKey);


        SharkVault vault = SharkVault(INSTANCE);

        IERC20 gold = IERC20(vault.gold());
        IERC20 seagold = IERC20(vault.seagold());

        console.logAddress(address(gold)); // logs the gold token address
        console.logAddress(address(seagold)); // logs the seagold token address
        console.logUint(gold.balanceOf(address(vault))); // logs the amount gold in the vault
        console.logUint(seagold.balanceOf(address(vault))); // logs the amount of seagold in the vault


        vm.stopBroadcast();
    }
}