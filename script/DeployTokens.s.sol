// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BuyrToken.sol";
import "../src/SellrToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title DeployTokens — Deploys $BUYR and $SELLR UUPS proxies to Base Mainnet
/// @notice Deploys implementation + ERC1967Proxy for each token. No tokens minted. EmissionOracle not set.
/// @dev Usage:
///   PRIVATE_KEY=0x... TOKEN_OWNER=0x123675EcF5524433B71616C57bDe130fE21156d8 \
///     forge script script/DeployTokens.s.sol --rpc-url https://mainnet.base.org --broadcast --verify
///
///   PRIVATE_KEY  = EOA that pays gas (tx sender)
///   TOKEN_OWNER  = Address that owns both contracts (Shulam.base.eth Smart Wallet)
contract DeployTokens is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address tokenOwner = vm.envAddress("TOKEN_OWNER");

        require(tokenOwner != address(0), "TOKEN_OWNER must not be zero address");

        console.log("=== Shulam Token Deployment (UUPS Proxy) ===");
        console.log("Chain ID:    ", block.chainid);
        console.log("Deployer:    ", deployer);
        console.log("Token Owner: ", tokenOwner);
        console.log("");

        vm.startBroadcast(deployerKey);

        // Deploy BUYR implementation + proxy
        BuyrToken buyrImpl = new BuyrToken();
        ERC1967Proxy buyrProxy = new ERC1967Proxy(
            address(buyrImpl),
            abi.encodeCall(BuyrToken.initialize, (tokenOwner))
        );
        BuyrToken buyr = BuyrToken(address(buyrProxy));

        // Deploy SELLR implementation + proxy
        SellrToken sellrImpl = new SellrToken();
        ERC1967Proxy sellrProxy = new ERC1967Proxy(
            address(sellrImpl),
            abi.encodeCall(SellrToken.initialize, (tokenOwner))
        );
        SellrToken sellr = SellrToken(address(sellrProxy));

        vm.stopBroadcast();

        console.log("=== Deployment Summary ===");
        console.log("BuyrToken impl:  ", address(buyrImpl));
        console.log("BuyrToken proxy: ", address(buyrProxy));
        console.log("SellrToken impl: ", address(sellrImpl));
        console.log("SellrToken proxy:", address(sellrProxy));
        console.log("Owner:           ", tokenOwner);
        console.log("");
        console.log("BUYR name:                  ", buyr.name());
        console.log("BUYR symbol:                ", buyr.symbol());
        console.log("BUYR totalSupply:           ", buyr.totalSupply());
        console.log("BUYR MAX_SUPPLY:            ", buyr.MAX_SUPPLY());
        console.log("BUYR emissionOracleLocked:  ", buyr.emissionOracleLocked());
        console.log("");
        console.log("SELLR name:                 ", sellr.name());
        console.log("SELLR symbol:               ", sellr.symbol());
        console.log("SELLR totalSupply:          ", sellr.totalSupply());
        console.log("SELLR MAX_SUPPLY:           ", sellr.MAX_SUPPLY());
        console.log("SELLR emissionOracleLocked: ", sellr.emissionOracleLocked());
        console.log("");
        console.log("Set in .env:");
        console.log("BUYR_TOKEN_ADDRESS=", address(buyrProxy));
        console.log("SELLR_TOKEN_ADDRESS=", address(sellrProxy));
        console.log("BUYR_IMPL_ADDRESS=", address(buyrImpl));
        console.log("SELLR_IMPL_ADDRESS=", address(sellrImpl));
    }
}
