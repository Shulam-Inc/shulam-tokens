// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable@5.1.0/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable@5.1.0/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@5.1.0/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@5.1.0/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@5.1.0/proxy/utils/UUPSUpgradeable.sol";

/// @title SellrToken — $SELLR Supply Token (SHULAM-TOKEN-001)
/// @notice UUPS-upgradeable ERC-20 with emission-controlled minting. 1B max supply.
/// @dev Minting restricted to EmissionOracle only. Two-step oracle setting
///      mirrors Ownable2Step: owner proposes, oracle accepts. Once accepted,
///      the oracle is locked forever. Staking and slashing live on StakeManager.
contract SellrToken is ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PermitUpgradeable, Ownable2StepUpgradeable, UUPSUpgradeable {
    /// @notice Hard cap: 1 billion tokens with 18 decimals
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;

    /// @notice The EmissionOracle contract — sole entity authorized to mint
    address public emissionOracle;

    /// @notice Pending oracle awaiting acceptance (two-step pattern)
    address public pendingEmissionOracle;

    /// @notice Whether the emission oracle has been permanently locked
    bool public emissionOracleLocked;

    event EmissionOracleProposed(address indexed oracle);
    event EmissionOracleSet(address indexed oracle);

    error OnlyEmissionOracle();
    error EmissionOracleLocked();
    error ZeroAddress();
    error MaxSupplyExceeded(uint256 requested, uint256 available);
    error NotPendingOracle();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the token (replaces constructor for proxy pattern)
    /// @param initialOwner Initial owner (can later call setEmissionOracle)
    function initialize(address initialOwner) external initializer {
        __ERC20_init("Shulam Seller Token", "SELLR");
        __ERC20Burnable_init();
        __ERC20Permit_init("Shulam Seller Token");
        __Ownable_init(initialOwner);
        __Ownable2Step_init();
    }

    /// @notice Propose an EmissionOracle address. Can be called multiple times
    ///         until the oracle is accepted and locked.
    /// @param oracle Address of the EmissionOracle contract
    function setEmissionOracle(address oracle) external onlyOwner {
        if (emissionOracleLocked) revert EmissionOracleLocked();
        if (oracle == address(0)) revert ZeroAddress();
        pendingEmissionOracle = oracle;
        emit EmissionOracleProposed(oracle);
    }

    /// @notice Accept the EmissionOracle role. Must be called by the pending
    ///         oracle address. Locks the oracle permanently.
    function acceptEmissionOracle() external {
        if (msg.sender != pendingEmissionOracle) revert NotPendingOracle();
        if (emissionOracleLocked) revert EmissionOracleLocked();
        emissionOracle = pendingEmissionOracle;
        pendingEmissionOracle = address(0);
        emissionOracleLocked = true;
        emit EmissionOracleSet(msg.sender);
    }

    /// @notice Mint tokens. Only callable by the accepted EmissionOracle.
    /// @param to Recipient address
    /// @param amount Amount to mint (18 decimals)
    function mint(address to, uint256 amount) external {
        if (msg.sender != emissionOracle) revert OnlyEmissionOracle();
        if (emissionOracle == address(0)) revert OnlyEmissionOracle();
        uint256 available = MAX_SUPPLY - totalSupply();
        if (amount > available) revert MaxSupplyExceeded(amount, available);
        _mint(to, amount);
    }

    /// @notice Only the owner can authorize upgrades
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
