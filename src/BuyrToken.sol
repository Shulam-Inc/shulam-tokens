// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title BuyrToken — $BUYR Demand Token (SHULAM-TOKEN-001)
/// @notice ERC-20 with emission-controlled minting. 10B max supply.
/// @dev Minting restricted to EmissionOracle only. Two-step oracle setting
///      mirrors Ownable2Step: owner proposes, oracle accepts. Once accepted,
///      the oracle is locked forever.
contract BuyrToken is ERC20, ERC20Burnable, ERC20Permit, Ownable2Step {
    /// @notice Hard cap: 10 billion tokens with 18 decimals
    uint256 public constant MAX_SUPPLY = 10_000_000_000 * 10 ** 18;

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

    /// @param initialOwner Initial owner (can later call setEmissionOracle)
    constructor(address initialOwner)
        ERC20("Shulam Buyer Token", "BUYR")
        ERC20Permit("Shulam Buyer Token")
        Ownable(initialOwner)
    {}

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
}
