// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TrustVault is Ownable, ReentrancyGuard {
    error InvalidToken();
    error AmountZero();
    error InsufficientBalance();
    error ExceedsMonthlyLimit();
    error AlreadyWithdrewThisMonth();
    error EmergencyNotEnabled();

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event EmergencyWithdrawal(address indexed user, uint256 amount);
    event LockUntilSet(address indexed user, uint256 lockUntil);
    event MonthlyReleaseSet(address indexed user, uint256 monthlyAmount);
    event EmergencyEnabled(address indexed user);

    struct Vault {
        uint256 totalDeposited;
        uint256 lockUntil;
        uint256 monthlyRelease;
        uint256 lastWithdrawalTime;
        bool emergencyEnabled;
    }

    mapping(address => Vault) public userVaults;

    // No real token transfer in this design — rewards are "minted" by owner
    // In production, integrate with actual stablecoin via depositRewardFromTreasury()

    constructor(address initialOwner) Ownable(initialOwner) {}

    function depositReward(uint256 amount) external onlyOwner {
        if (amount == 0) revert AmountZero();
        userVaults[msg.sender].totalDeposited += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        Vault storage vault = userVaults[msg.sender];
        if (vault.totalDeposited < amount) revert InsufficientBalance();

        if (block.timestamp < vault.lockUntil) {
            if (amount > vault.monthlyRelease) revert ExceedsMonthlyLimit();
            if (vault.lastWithdrawalTime > 0) {
                uint256 monthsElapsed = (block.timestamp - vault.lastWithdrawalTime) / 30 days;
                if (monthsElapsed == 0) revert AlreadyWithdrewThisMonth();
            }
        }

        vault.totalDeposited -= amount;
        vault.lastWithdrawalTime = block.timestamp;
        emit Withdrawal(msg.sender, amount);
    }

    function emergencyWithdraw() external nonReentrant {
        Vault storage vault = userVaults[msg.sender];
        if (!vault.emergencyEnabled) revert EmergencyNotEnabled();
        if (vault.totalDeposited == 0) revert InsufficientBalance();

        uint256 amount = vault.totalDeposited;
        vault.totalDeposited = 0;
        vault.lastWithdrawalTime = block.timestamp;
        emit EmergencyWithdrawal(msg.sender, amount);
    }

    // --- Owner Config ---
    function setLockUntil(uint256 timestamp) external onlyOwner {
        userVaults[msg.sender].lockUntil = timestamp;
        emit LockUntilSet(msg.sender, timestamp);
    }

    function setMonthlyRelease(uint256 amount) external onlyOwner {
        userVaults[msg.sender].monthlyRelease = amount;
        emit MonthlyReleaseSet(msg.sender, amount);
    }

    function enableEmergencyWithdrawal() external onlyOwner {
        userVaults[msg.sender].emergencyEnabled = true;
        emit EmergencyEnabled(msg.sender);
    }

    function getVault(address user) external view returns (
        uint256 totalDeposited,
        uint256 lockUntil,
        uint256 monthlyRelease,
        uint256 lastWithdrawalTime,
        bool emergencyEnabled
    ) {
        Vault memory v = userVaults[user];
        return (v.totalDeposited, v.lockUntil, v.monthlyRelease, v.lastWithdrawalTime, v.emergencyEnabled);
    }
}