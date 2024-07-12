// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Interfaces/IERC3156FlashBorrower.sol";


contract FlashLoanReceiver is IERC3156FlashBorrower {
    IERC3156FlashLender public flashLender;
    address public owner;

    constructor(address _flashLender) {
        flashLender = IERC3156FlashLender(_flashLender);
        owner = msg.sender;
    }

    function executeFlashLoan(address token, uint256 amount) external {
        require(msg.sender == owner, "Only owner can execute flash loan");

        // Request a flash loan
        bytes memory data = ""; // You can pass additional data if needed
        flashLender.flashLoan(this, token, amount, data);
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        require(msg.sender == address(flashLender), "Untrusted lender");
        require(initiator == address(this), "Untrusted loan initiator");

        // Approve the flash loan repayment
        IERC20(token).approve(address(flashLender), amount + fee);

        // Perform your custom logic here
        // For example, arbitrage, collateral swap, etc.

        // Return the expected value
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function withdrawTokens(address token) external {
        require(msg.sender == owner, "Only owner can withdraw tokens");
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(owner, balance);
    }
}
