pragma solidity 0.8.0;
interface IERC721 {

  function transferFrom(address _from, address _to, uint256 _tokenId) external;
  function safeTransferFrom(address _from, address _to, uint256 _tokenId) external;
  function balanceOf(address _owner) external view returns (uint256 _balance);

  function approve(address _to, uint256 _tokenId) external;
  function ownerOf(uint256 _tokenId) external view returns (address _owner);


  function totalSupply() external view returns (uint256);
  function tokenOfOwnerByIndex(
    address _owner,
    uint256 _index
  ) external view returns (uint256 _tokenId);
  
  function tokenByIndex(uint256 _index) external view returns (uint256);

  function tokenURI(uint256 _tokenId) external view returns (string calldata);
}
