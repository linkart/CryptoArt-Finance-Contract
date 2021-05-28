//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import './Ownable.sol';
import './ReentrancyGuard.sol';
import './interface/IERC20.sol';
import './interface/IERC721.sol';
import './interface/IFarmbCart.sol';

interface ERC721Receiver {
  function onERC721Received(
    address _operator,
    address _from,
    uint256 _tokenId,
    bytes calldata _data
  ) external returns(bytes4);
}

contract FarmNFT is Ownable, ReentrancyGuard, ERC721Receiver {
  enum Rerity {Unkown, Common, Rare, Lengendary}

  IERC20 private immutable cart;
  IERC721 private immutable cartNFT;
  
  IFarmbCart public farmbCart;

  // 挖出的数量
  uint16 commonMinted;
  uint16 rareMinted;
  uint16 lengendaryMinted;

  // 赎回的数量
  uint16 commonRedeemed;
  uint16 rareRedeemed;
  uint16 lengendaryRedeemed;

  struct NFTInfo {
    address mintUser; 
    Rerity rerity;
    bool redeemed;   
  }

  mapping(Rerity => uint[]) nfts;
  // tokenId => NFTInfo
  mapping(uint => NFTInfo) public nftInfos;

  mapping(address => uint[]) userNfts;

  event Redeem(address indexed user, uint tokenId, uint cartAmount);
  event Mint(address indexed user, uint tokenId);

  constructor(IERC20 _cart, IERC721 _nft, address owner) Ownable(owner) {
    cart = _cart;
    cartNFT = _nft;
  }

  function initFarmbCart(address _bcart) external {
    require(address(farmbCart) == address(0), "aleady inited");
    farmbCart = IFarmbCart(_bcart);
  }

  // for frontend.
  function numInfo()  external view returns (uint16, uint16, uint16, uint16, uint16, uint16){ 
    return(commonMinted, rareMinted, lengendaryMinted, commonRedeemed, rareRedeemed, lengendaryRedeemed) ;
  }

  function onERC721Received(address ,
    address _from,
    uint256 _tokenId,
    bytes calldata 
  ) external override returns(bytes4) {
    require(msg.sender == address(cartNFT), "ill caller");

    redeem(_from, _tokenId);

    return 0x150b7a02;
  }

  function redeem(address user, uint256 _tokenId) internal {
    NFTInfo storage info = nftInfos[_tokenId];
    require(info.mintUser == user, "Not NFT Miner");
    require(!info.redeemed, "aleady Redeemed");
    
    info.redeemed = true;

    Rerity r = nftInfos[_tokenId].rerity;
    uint amount = random(r)  + lastAward(r);
    cart.transfer(user, amount);

    emit Redeem(user, _tokenId, amount);
  }

  // common : 150 - 380
  // rare :   300 - 470
  // lengendary: 1200 - 2000
  function random(Rerity rerity) internal view returns (uint) {
    bytes32 rand = keccak256(abi.encodePacked(block.number + block.timestamp));
    if (rerity== Rerity.Common) {
      return (150 + uint(rand) % 230) * 1e18;
    }

    if (rerity== Rerity.Rare) {
      return (300 + uint(rand) % 170) * 1e18;
    }

    if (rerity== Rerity.Lengendary) {
      return (1200 + uint(rand) % 800) * 1e18;
    }
  }

  // 尾单奖励
  function lastAward(Rerity rerity) internal returns (uint) {
    if (rerity == Rerity.Common) {
      commonRedeemed += 1;
    } else if (rerity == Rerity.Rare) {
      rareRedeemed += 1;
    } else if (rerity == Rerity.Lengendary) {
      lengendaryRedeemed += 1;
    } else {
      revert("Unkown Rerity");
    }

    uint redeemed = commonRedeemed + rareRedeemed + lengendaryRedeemed;
    if (redeemed >= 357) {
      if(redeemed == 357) {
        return 1000e18; //   20000 * 0.05;
      } else if (redeemed == 358) {
        return 3000e18;  //  20000 * 0.15;
      } else if (redeemed == 359) {
        return 6000e18;  //  20000 * 0.3;
      } else if(redeemed == 360) {
        return 10000e18; //  20000 * 0.5;
      } 
    } 

  }

  // return nums and bcats
  function nFTConfig(Rerity rerity) internal pure returns(uint, uint) {
    if (rerity == Rerity.Common) {
      return (300, 75e18);
    } else if(rerity == Rerity.Rare) {
      return (50, 150e18);
    } else if (rerity == Rerity.Lengendary) {
      return (10, 450e18);
    }
  }

  function tokenIds(Rerity rerity) external view returns(uint[] memory ) {
    return nfts[rerity];
  }

  function myNfts(address user) external view returns(uint[] memory ) {
    return userNfts[user];
  }

  function initNFTs(uint[] calldata _tokenIds, Rerity rerity, address nftOwner) external onlyOwner {
    uint[] storage reritys = nfts[rerity];
    (uint maxLen, ) = nFTConfig(rerity);

    require(_tokenIds.length + reritys.length <= maxLen, "mismatch NFT len");
    
    for (uint i = 0; i < _tokenIds.length; i++) {
      uint tokenId = _tokenIds[i];

      NFTInfo storage info = nftInfos[tokenId];
      require(info.rerity == Rerity.Unkown, "tokenId inited");

      info.rerity = rerity;
      cartNFT.transferFrom(nftOwner, address(this), tokenId);
      reritys.push(tokenId);
    }
  }

  function withdraw(uint[] calldata _tokenIds, address to) external onlyOwner {
    for (uint i = 0; i < _tokenIds.length; i++) {
      cartNFT.safeTransferFrom(address(this), to, _tokenIds[i]);
    }
  }

  function withdrawCart(uint amount,address to) external onlyOwner {
    cart.transfer(to, amount);
  }

  function mintNFT(uint tokenId, uint needbCarts, address user) internal {
    require(farmbCart.consume(user, needbCarts), "may no enough bCarts");
    NFTInfo storage info = nftInfos[tokenId];
    info.mintUser = user;

    uint[] storage _myNfts = userNfts[user];
    _myNfts.push(tokenId);

    cartNFT.safeTransferFrom(address(this), user, tokenId);
    emit Mint(user, tokenId);
  }

  function mint(Rerity rerity) external nonReentrant {
    (, uint bcarts ,) = farmbCart.myStake(msg.sender);

    (uint len, uint needbCarts) = nFTConfig(rerity);
    require(bcarts >= needbCarts, "bCard not enough");
    
    if(rerity == Rerity.Lengendary && lengendaryMinted < len) {
      uint tokenId = nfts[Rerity.Lengendary][lengendaryMinted];
      mintNFT(tokenId, needbCarts, msg.sender);
      
      lengendaryMinted += 1;
      return ;
    }

    if(rerity == Rerity.Rare && rareMinted < len) {
      uint tokenId = nfts[Rerity.Rare][rareMinted];
      mintNFT(tokenId,needbCarts, msg.sender);
      rareMinted += 1;
      return ;
    }

    if(rerity == Rerity.Common && commonMinted < len) {
      uint tokenId = nfts[Rerity.Common][commonMinted];
      mintNFT(tokenId,needbCarts, msg.sender);
      commonMinted += 1;
      return ;
    }
  }
}