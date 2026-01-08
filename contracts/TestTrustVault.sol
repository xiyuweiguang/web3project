// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title TrustVault
 * @dev A non-custodial savings vault for RewardTrust Pay.
 *      Users deposit stablecoins triggered by real-world behaviors (e.g., tuition payment).
 *      Funds are released according to time-based or goal-based rules.
 */
contract TrustVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ===== Events =====
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event EmergencyWithdrawal(address indexed user, uint256 amount);
    event MonthlyReleaseSet(address indexed user, uint256 monthlyAmount);
    event LockUntilSet(address indexed user, uint256 lockUntilTimestamp);

    // ===== Structs =====
    struct Vault {
        uint256 totalDeposited;     // Total stablecoins deposited
        uint256 lockUntil;          // Timestamp until which full withdrawal is locked
        uint256 monthlyRelease;     // Max amount user can withdraw per month
        uint256 lastWithdrawalTime; // Last time user withdrew (for monthly limit)
        bool emergencyEnabled;      // Can user trigger emergency withdrawal? (KYC verified)
    }

    // ===== Storage =====
    mapping(address => Vault) public userVaults;
    address public immutable rewardToken; // e.g., HKD Stablecoin or USDC

    // ===== Modifiers =====
    modifier onlyIfEmergencyEnabled() {
        require(userVaults[msg.sender].emergencyEnabled, "Emergency not enabled");
        _;
    }

    // ===== Constructor =====
    constructor(address _rewardToken, address initialOwner) Ownable(initialOwner) {
        require(_rewardToken != address(0), "Invalid token");
        require(initialOwner != address(0), "Invalid owner");
        rewardToken = _rewardToken;
    }

    // ===== External Functions =====

    /**
     * @notice Called by RewardTrust Pay backend AFTER verifying real-world behavior (e.g., tuition paid)
     * @dev Only the contract owner (RewardTrust Pay system) can trigger deposits
     */
    function depositReward(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Amount must be > 0");

        Vault storage vault = userVaults[msg.sender];
        vault.totalDeposited += amount;

        // Transfer stablecoin from owner (RewardTrust Pay treasury) to this contract
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, rewardToken, amount);
    }

    /**
     * @notice Regular withdrawal (subject to monthly limit and lock period)
     */
    function withdraw(uint256 amount) external nonReentrant {
        Vault storage vault = userVaults[msg.sender];
        require(vault.totalDeposited >= amount, "Insufficient balance");

        // Check lock period
        if (block.timestamp < vault.lockUntil) {
            // If locked, only allow up to monthlyRelease
            require(amount <= vault.monthlyRelease, "Exceeds monthly release limit");

            // Enforce monthly cooldown
            uint256 monthsSinceLast = (block.timestamp - vault.lastWithdrawalTime) / 30 days;
            if (monthsSinceLast == 0) {
                revert("Already withdrew this month");
            }
        }

        // Update state
        vault.totalDeposited -= amount;
        vault.lastWithdrawalTime = block.timestamp;

        // Send tokens to user
        IERC20(rewardToken).safeTransfer(msg.sender, amount);

        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @notice Emergency withdrawal (e.g., medical crisis) – requires KYC verification
     */
    function emergencyWithdraw() external onlyIfEmergencyEnabled nonReentrant {
        Vault storage vault = userVaults[msg.sender];
        uint256 amount = vault.totalDeposited;
        require(amount > 0, "No funds to withdraw");

        vault.totalDeposited = 0;
        vault.lastWithdrawalTime = block.timestamp;

        IERC20(rewardToken).safeTransfer(msg.sender, amount);

        emit EmergencyWithdrawal(msg.sender, amount);
    }

    // ===== Configuration (Owner-only) =====

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
    }

    // ===== View Functions =====

    function getVault(address user) external view returns (
        uint256 totalDeposited,
        uint256 lockUntil,
        uint256 monthlyRelease,
        uint256 lastWithdrawalTime,
        bool emergencyEnabled
    ) {
        Vault memory v = userVaults[user];
        return (
            v.totalDeposited,
            v.lockUntil,
            v.monthlyRelease,
            v.lastWithdrawalTime,
            v.emergencyEnabled
        );
    }

    function getTokenBalance() external view returns (uint256) {
        return IERC20(rewardToken).balanceOf(address(this));
    }
}