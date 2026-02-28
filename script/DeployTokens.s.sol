// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BuyrToken.sol";
import "../src/SellrToken.sol";

/// @title DeployTokens — Deploys $BUYR and $SELLR to Base Mainnet
/// @notice Standard CREATE deployment. No tokens minted. EmissionOracle not set.
/// @dev Usage:
///   PRIVATE_KEY=0x... TOKEN_OWNER=0x123675EcF5524433B71616C57bDe130fE21156d8 \
///     forge script script/DeployTokens.s.sol --rpc-url https://mainnet.base.org --broadcast
///
///   PRIVATE_KEY  = EOA that pays gas (tx sender)
///   TOKEN_OWNER  = Address that owns both contracts (Shulam.base.eth Smart Wallet)
contract DeployTokens is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address tokenOwner = vm.envAddress("TOKEN_OWNER");

        require(tokenOwner != address(0), "TOKEN_OWNER must not be zero address");

        console.log("=== Shulam Token Deployment ===");
        console.log("Chain ID:    ", block.chainid);
        console.log("Deployer:    ", deployer);
        console.log("Token Owner: ", tokenOwner);
        console.log("");

        vm.startBroadcast(deployerKey);

        BuyrToken buyr = new BuyrToken(tokenOwner);
        SellrToken sellr = new SellrToken(tokenOwner);

        vm.stopBroadcast();

        console.log("=== Deployment Summary ===");
        console.log("BuyrToken:   ", address(buyr));
        console.log("SellrToken:  ", address(sellr));
        console.log("Owner:       ", tokenOwner);
        console.log("");
        console.log("BUYR totalSupply:           ", buyr.totalSupply());
        console.log("BUYR MAX_SUPPLY:            ", buyr.MAX_SUPPLY());
        console.log("BUYR emissionOracle:        ", buyr.emissionOracle());
        console.log("BUYR emissionOracleLocked:  ", buyr.emissionOracleLocked());
        console.log("");
        console.log("SELLR totalSupply:          ", sellr.totalSupply());
        console.log("SELLR MAX_SUPPLY:           ", sellr.MAX_SUPPLY());
        console.log("SELLR emissionOracle:       ", sellr.emissionOracle());
        console.log("SELLR emissionOracleLocked: ", sellr.emissionOracleLocked());
        console.log("");
        console.log("Set in .env:");
        console.log("BUYR_TOKEN_ADDRESS=", address(buyr));
        console.log("SELLR_TOKEN_ADDRESS=", address(sellr));
    }
}
