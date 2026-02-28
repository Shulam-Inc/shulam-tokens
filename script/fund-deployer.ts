/**
 * Fund the CDP deployer wallet from Shulam.base.eth Smart Wallet.
 *
 * Since Shulam.base.eth is a Smart Wallet (contract), we can't sign from CLI.
 * Instead, this script checks if CDP has a funded wallet or uses CDP's
 * fund/transfer capabilities.
 */
import { CdpClient } from "@coinbase/cdp-sdk";
import { createPublicClient, http, formatEther } from "viem";
import { base } from "viem/chains";
import { resolve } from "path";
import dotenv from "dotenv";

dotenv.config({ path: resolve(import.meta.dirname ?? ".", "../../facilitator/.env") });
dotenv.config();

async function main() {
  const cdp = new CdpClient({
    apiKeyId: process.env.CDP_API_KEY_ID!,
    apiKeySecret: process.env.CDP_API_KEY_SECRET!,
    walletSecret: process.env.CDP_WALLET_SECRET!,
  });

  const publicClient = createPublicClient({
    chain: base,
    transport: http("https://mainnet.base.org"),
  });

  // List all CDP accounts
  console.log("CDP Accounts on Base Mainnet:");
  const accounts = await cdp.evm.listAccounts();
  for (const a of (accounts.accounts as any[])) {
    const bal = await publicClient.getBalance({ address: a.address });
    console.log(`  ${a.name}: ${a.address} — ${formatEther(bal)} ETH`);
  }

  // Check Shulam.base.eth
  const smartWallet = "0x123675EcF5524433B71616C57bDe130fE21156d8";
  const swBal = await publicClient.getBalance({ address: smartWallet as `0x${string}` });
  console.log(`\n  Shulam.base.eth: ${smartWallet} — ${formatEther(swBal)} ETH`);

  // Try to request faucet (only works on testnet)
  console.log("\n  Attempting CDP fund request on base-mainnet...");
  try {
    const result = await cdp.evm.requestFaucet({
      address: "0xC4BBD4D2F3aac66aB39e74e7369C711073E43908",
      network: "base",
      token: "eth",
    });
    console.log("  Faucet result:", result);
  } catch (err: any) {
    console.log(`  Faucet not available on mainnet (expected): ${err.message?.slice(0, 100)}`);
  }
}

main().catch(console.error);
