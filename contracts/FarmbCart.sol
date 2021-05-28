//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import './interface/IERC2612.sol';
import './interface/IERC20.sol';
import './interface/IFarmNFT.sol';
import "./Address.sol";

import './FractionalExponents.sol';

interface TokenRecipient {
  function tokensReceived(
      address from,
      uint amount,
      bytes calldata exData
  ) external returns (bool);
}

contract FarmbCart is TokenRecipient, FractionalExponents  {
  using Address for address;
  address private immutable cart;
  address private immutable farmNFT;

  struct UserInfo {
      uint128 amount;      // How many token locked;
      uint96  bcart;       // Rewarded bcart
      uint32  depositTs;   // deposit Timestamp
  }

  event Stake(address indexed user, uint indexed amount);
  event Withdraw(address indexed user, uint indexed amount);

  mapping(address => UserInfo) userInfo;

  constructor(address _cart, address _farmNFT) {
    cart = _cart;
    IFarmNFT(_farmNFT).initFarmbCart(address(this));
    farmNFT = _farmNFT;
  }

  function tokensReceived(address from, uint amount, bytes calldata data) external override returns (bool) {
    require(msg.sender == cart, "must from cart");
    doStake(from, amount);
    return true;
  }

  function permitStake(address user, uint amount, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
    IERC2612(cart).permit(msg.sender, address(this), amount, deadline, v, r, s);
    stake(user, amount);
  }

  function stake(address user, uint amount) public {
    require(IERC20(cart).transferFrom(msg.sender, address(this), amount), "Transfer from error");
    doStake(user, amount);
  }

  function consume(address user, uint bcartUsed) external returns (bool) {
    require(msg.sender == farmNFT, "must from farmNFT");
    require(!user.isContract(), "not for robot");
    UserInfo storage info = userInfo[user];
    info.bcart = info.bcart + safe96(pending(info.amount, info.depositTs)) - safe96(bcartUsed);
    info.depositTs = safe32(block.timestamp);
    return true;
  }

  function withdraw(uint128 amount) external {
    UserInfo storage info = userInfo[msg.sender];
    info.bcart += safe96(pending(info.amount, info.depositTs));
    info.amount -= amount;

    require(info.amount >= 1000e18 || info.amount == 0, "invalid amount");
    info.depositTs = safe32(block.timestamp);

    IERC20(cart).transfer(msg.sender, amount);
    emit Withdraw(msg.sender, amount);
  }
  
  // If robot stake when construct, Trap will for you. 
  // Haha... Don't try it. 
  function doStake(address user, uint amount) internal {
    require(!user.isContract(), "not for robot");
    UserInfo storage info = userInfo[user];
    require(info.amount + amount >= 1000e18, "too low");

    emit Stake(user, amount);
    
    info.bcart += safe96(pending(info.amount, info.depositTs));
    info.amount += safe128(amount);
    info.depositTs = safe32(block.timestamp);

  }

  function myStake(address user) public view returns (uint128, uint96, uint32) {
    UserInfo memory info = userInfo[user];
    uint96 bcart = info.bcart + safe96(pending(info.amount, info.depositTs));

    return (info.amount, bcart, info.depositTs);
  }


  // pending = passed * 0.675 * (amount / 30) ^ 0.25 / 86400 
  function pending(uint amount, uint depositTs) internal view returns (uint) {
    uint256 blockTime = block.timestamp;
    if (amount == 0 || blockTime <= depositTs) {
      return 0;
    }

    (uint256 mantissa, uint8 exponent) = power(amount / 30, uint256(1e18), 1, 4);
		uint256 noCoefficient = mantissa * uint256(1 ether) / (uint256(1) << uint256(exponent));
		return (blockTime - depositTs ) * noCoefficient * 675 / 86400000;
  }


  function safe32(uint n) internal pure returns (uint32) {
    require(n < 2**32, "over uint32");
    return uint32(n);
  }

  function safe96(uint n) internal pure returns (uint96) {
    require(n < 2**96, "over uint96");
    return uint96(n);
  }

  function safe128(uint n) internal pure returns (uint128) {
    require(n < 2**128, "over uint128");
    return uint128(n);
  }

}