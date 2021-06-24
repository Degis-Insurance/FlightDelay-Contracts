// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./InsuranceMain.sol"; //不对--=-=-
//import "./interfaces/IERC20.sol";
import "./DegisToken.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";


contract InsurancePool {
    // the onwer address of this contract
    address public owner;
    // UserInfo.rewardDebt: the pending reward(degis token)
    // UserInfo.assetBalance: the asset balance of each user
    struct UserInfo {
        uint256 rewardDebt;
        uint256 assetBalance;
    }
    //mapping(uint256 => mapping(address => UserInfo)) userInfo;
    mapping(address => UserInfo) userInfo;

    // the contract instance of degis token
    DegisToken public immutable DEGIS;

    // current total staking balance of the pool
    uint256 currentStakingBalance;
    // real staking balance = current staking balance - sum(unstake request)
    uint256 realStakingBalance;
    // locked balance is for potiential payoff
    uint256 lockedBalance;
    // locked relation = locked balance / currentStakingBalance
    fixed lockedRatio;
    // available capacity is the current available asset balance
    uint256 availableCapacity;
    // active premiums = premiums have been paid but the policies haven't expired
    uint256 activePremiums;
    // collateral factor = asset / max risk exposure, initially need to be >100%
    uint256 public collateralFactor;
    // poolInfo: the information about this pool
    struct poolInfo {
        string poolName;
        uint256 poolId;
        uint256 degisPerShare;
        uint256 lastRewardBlock;
        uint256 degisPerBlock;
    }

    event Stake(address indexed userAddress, uint256 amount);
    event Unstake(address indexed userAddress, uint256 amount);
    event ChangeCollateralFactor(address indexed onwerAddress, uint256 factor);

    // @constructor
    constructor(uint256 factor, DegisToken _degis) {
        owner = msg.sender;
        collateralFactor = factor;
        lockedRatio = 0;
        DEGIS = _degis;
    }

    // @modifier onlyOwner: only the owner can call some functions
    modifier onlyOwner() {
        require(owner == msg.sender, 
                "only the owner can call this function");
        _;
    }

    // @function setCollateralFactor: change the collateral factor only by the owner
    // @param factor: the new collateral factor
    function setCollateralFactor(uint256 _factor) public onlyOwner {
        collateralFactor = _factor;
        emit ChangeCollateralFactor(owner, _factor);
    }

    // @function checkWhenBuy: check the conditions when buying policies
    // @param payoff: the payoff of the policy to be bought
    function checkWhenBuy(uint256 payoff) external {
        require(availableCapacity >= payoff,
                "not sufficient risk capacity for this policy");
    }

    // @function updateWhenBuy: update the pool variables when buying policies
    // @param premium: the premium of the policy just sold
    // @param payoff: the payoff of the policy just sold
    function updateWhenBuy(uint256 _premium, uint256 _payoff) external {
        lockedBalance += _payoff;
        activePremiums += _premium;
        availableCapacity -= _payoff;
        lockedRatio = lockedBalance / currentStakingBalance;
    }

    // @function stake: a user want to stake some amount of asset
    // @param userAddress: user's address
    // @param amount: the amount that the user want to stake
    function stake(address userAddress, uint256 amount) public {
        _deposit(userAddress, amount);
        emit Stake(userAddress, amount);
    }

    // @function getUnlockedfor: get the balance that one user can unlock
    // @param userAddress: user's address
    // @return _amount: the amount that the user can unlock
    function getUnlockedfor(address userAddress) public returns(uint256 _amount) {
        uint256 user_balance = userInfo[userAddress];
        return (1 - lockedRatio) * user_balance;
    }

    // @function unstake: a user want to unstake some amount
    // @param userAddress: user's address
    // @param amount: the amount that the user want to unstake
    function unstake(address userAddress, uint256 amount) public {
        require(amount < getUnlockedfor(userAddress),
                "not enough balance to be unlocked, please wait");
        _withdraw(userAddress, amount);
        emit Unstake(userAddress, amount);
    }

    // @function _deposit: finish the deposit action
    // @param userAddress: address of the user who deposits
    // @param balance: the amount he deposits
    function _deposit(address userAddress, uint256 _balance) internal {
        currentStakingBalance += _balance;
        userInfo[userAddress].assetBalance += _balance;
        lockedRatio = lockedBalance / currentStakingBalance;
    }

    // @function _withdraw: finish the withdraw action, only when meeting the conditions
    // @param userAddress: address of the user who withdraws
    // @param balance: the amount he withdraws
    function _withdraw(address userAddress, uint256 balance) internal {
        currentStakingBalance -= balance;
        userInfo[userAddress] -= balance;
        lockedRatio = lockedBalance / currentStakingBalance;
    }

    function payClaim() {

    }

    function recievePremium() {

    }
}