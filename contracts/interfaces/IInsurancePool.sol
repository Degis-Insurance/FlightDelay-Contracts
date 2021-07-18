// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IInsurancePool {
    event Stake(address indexed userAddress, uint256 amount);
    event Unstake(address indexed userAddress, uint256 amount);
    event ChangeCollateralFactor(address indexed onwerAddress, uint256 factor);
    event BuyNewPolicy(address userAddress, uint256 premium, uint256 payout);

    function getTotalLocked() external view returns (uint256);

    function getAvailableCapacity() external view returns (uint256);

    function getStakeAmount(address _userAddress)
        external
        view
        returns (uint256);

    function updateWhenBuy(uint256, uint256) external returns (bool);
}