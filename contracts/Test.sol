// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TrustVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    struct Vault {
        uint256 totalDeposited;
        uint256 lockUntil;
        uint256 monthlyRelease;
        uint256 lastWithdrawalTime;
        bool emergencyEnabled;
    }

    mapping(address => Vault) public userVaults;
    address public immutable rewardToken;

    constructor(address _rewardToken, address initialOwner) Ownable(initialOwner) {
        require(_rewardToken != address(0), "Invalid token");
        rewardToken = _rewardToken;
    }

    function depositReward(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        userVaults[msg.sender].totalDeposited += amount;
        emit Deposit(msg.sender, rewardToken, amount);
    }

    function withdraw(uint256 amount) external {
        Vault storage vault = userVaults[msg.sender];
        require(vault.totalDeposited >= amount, "Insufficient balance");
        vault.totalDeposited -= amount;
        emit Withdrawal(msg.sender, amount);
    }

    function setLockUntil(uint256 timestamp) external onlyOwner {
        userVaults[msg.sender].lockUntil = timestamp;
    }

    function setMonthlyRelease(uint256 amount) external onlyOwner {
        userVaults[msg.sender].monthlyRelease = amount;
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