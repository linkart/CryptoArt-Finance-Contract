pragma solidity 0.8.0;

interface IFarmbCart {
    function consume(address user, uint bcartUsed) external returns (bool);
    function myStake(address user) external view returns (uint128, uint96, uint32);

}
