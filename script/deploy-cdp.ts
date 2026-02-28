/**
 * Deploy $BUYR and $SELLR UUPS-upgradeable tokens to Base Mainnet via CDP Server Wallet.
 *
 * Uses Nick's CREATE2 factory (0x4e59b44847b379578588920cA78FbF26c0B4956C)
 * for deterministic addresses — same pattern as facilitator/scripts/deploy-cdp.ts.
 *
 * Architecture:
 *   - CDP Server Wallet (shulam-super-admin) = gas payer / transaction sender
 *   - Shulam.base.eth Smart Wallet = contract OWNER (passed to initialize())
 *
 * Usage:
 *   npx tsx script/deploy-cdp.ts --network base          # Base Mainnet
 *   npx tsx script/deploy-cdp.ts --network base-sepolia   # Testnet
 *   npx tsx script/deploy-cdp.ts --network base --dry-run # Simulate only
 */
import { CdpClient } from "@coinbase/cdp-sdk";
import {
  createPublicClient,
  http,
  encodeFunctionData,
  encodeAbiParameters,
  parseAbiParameters,
  getContractAddress,
  formatEther,
  type Hex,
  type Address,
  concat,
  pad,
  toHex,
} from "viem";
import { baseSepolia, base } from "viem/chains";
import { readFileSync } from "fs";
import { resolve } from "path";
import dotenv from "dotenv";

// Load .env from facilitator (where CDP creds live)
dotenv.config({ path: resolve(import.meta.dirname ?? ".", "../../facilitator/.env") });
dotenv.config();

// ── Config ───────────────────────────────────────────────────────

const DEPLOYER_WALLET_NAME = "shulam-super-admin";
const ARTIFACTS_DIR = resolve(import.meta.dirname ?? ".", "../out");

/** Shulam.base.eth Smart Wallet — owner of all deployed contracts. */
const CONTRACT_OWNER = "0x123675EcF5524433B71616C57bDe130fE21156d8" as Address;

/** Nick's canonical CREATE2 factory — deployed on all major EVM chains. */
const CREATE2_FACTORY = "0x4e59b44847b379578588920cA78FbF26c0B4956C" as Address;

const NETWORKS: Record<string, { chain: typeof baseSepolia; rpcUrl: string }> = {
  "base-sepolia": { chain: baseSepolia, rpcUrl: "https://sepolia.base.org" },
  "base": { chain: base, rpcUrl: "https://mainnet.base.org" },
};

// ── Helpers ──────────────────────────────────────────────────────

function loadBytecode(contractDir: string, contractName: string): Hex {
  const path = resolve(ARTIFACTS_DIR, `${contractDir}/${contractName}.json`);
  const json = JSON.parse(readFileSync(path, "utf-8"));
  return json.bytecode.object as Hex;
}

let deployCount = 1; // Salt 1 = BuyrToken impl (already deployed), continues from 2

// ── Main ─────────────────────────────────────────────────────────

async function deploy() {
  const args = process.argv.slice(2);
  const networkIdx = args.indexOf("--network");
  const networkName = networkIdx >= 0 ? args[networkIdx + 1] : "base-sepolia";
  const dryRun = args.includes("--dry-run");

  const networkConfig = NETWORKS[networkName];
  if (!networkConfig) {
    console.error(`Unknown network: ${networkName}. Use: base-sepolia | base`);
    process.exit(1);
  }

  console.log("╔══════════════════════════════════════════════════════╗");
  console.log("║   SHULAM TOKEN DEPLOYMENT — $BUYR & $SELLR (UUPS)  ║");
  console.log("║            via CREATE2 Factory + CDP                ║");
  console.log("╚══════════════════════════════════════════════════════╝");
  console.log(`  Network:        ${networkName}`);
  console.log(`  Contract Owner: ${CONTRACT_OWNER}`);
  console.log(`  CREATE2 Factory: ${CREATE2_FACTORY}`);
  console.log(`  Dry Run:        ${dryRun}`);
  console.log();

  // Initialize CDP
  const cdp = new CdpClient({
    apiKeyId: process.env.CDP_API_KEY_ID!,
    apiKeySecret: process.env.CDP_API_KEY_SECRET!,
    walletSecret: process.env.CDP_WALLET_SECRET!,
  });

  // Resolve deployer wallet
  console.log(`  Resolving CDP wallet: ${DEPLOYER_WALLET_NAME}...`);
  const account = await cdp.evm.getOrCreateAccount({ name: DEPLOYER_WALLET_NAME });
  const deployerAddr = account.address as Address;
  console.log(`  Deployer:       ${deployerAddr}`);

  // Check balance
  const publicClient = createPublicClient({
    chain: networkConfig.chain,
    transport: http(networkConfig.rpcUrl),
  });

  const balance = await publicClient.getBalance({ address: deployerAddr });
  console.log(`  Balance:        ${formatEther(balance)} ETH`);

  if (balance === 0n) {
    console.error("\n  Deployer has 0 ETH. Fund the wallet before deploying.");
    console.error(`     Send ETH to: ${deployerAddr}`);
    process.exit(1);
  }

  // Load bytecodes
  const buyrImplBytecode = loadBytecode("BuyrToken.sol", "BuyrToken");
  const sellrImplBytecode = loadBytecode("SellrToken.sol", "SellrToken");
  const proxyBytecode = loadBytecode("ERC1967Proxy.sol", "ERC1967Proxy");

  console.log(`  BuyrToken bytecode:    ${buyrImplBytecode.length} chars`);
  console.log(`  SellrToken bytecode:   ${sellrImplBytecode.length} chars`);
  console.log(`  ERC1967Proxy bytecode: ${proxyBytecode.length} chars`);

  // Encode initialize(address) calldata
  const initializeCalldata = encodeFunctionData({
    abi: [{
      name: "initialize",
      type: "function",
      inputs: [{ name: "initialOwner", type: "address" }],
      outputs: [],
      stateMutability: "nonpayable",
    }],
    functionName: "initialize",
    args: [CONTRACT_OWNER],
  });
  console.log(`  initialize() calldata: ${initializeCalldata}`);

  // Helper: deploy via CREATE2
  async function create2Deploy(initCode: Hex, label: string): Promise<Address> {
    const salt = pad(toHex(deployCount++), { size: 32 });
    const predicted = getContractAddress({
      bytecode: initCode,
      from: CREATE2_FACTORY,
      salt,
      opcode: "CREATE2",
    });

    // Check if already deployed (idempotent)
    const existingCode = await publicClient.getCode({ address: predicted });
    if (existingCode && existingCode !== "0x") {
      console.log(`    Already deployed at ${predicted} — skipping`);
      return predicted;
    }

    if (dryRun) {
      console.log(`    [DRY RUN] Would deploy ${label} to ${predicted}`);
      return predicted;
    }

    // CREATE2 factory calldata = salt || initCode
    const calldata = concat([salt, initCode]);

    const result = await cdp.evm.sendTransaction({
      address: deployerAddr,
      network: networkName as "base-sepolia" | "base",
      transaction: {
        to: CREATE2_FACTORY,
        data: calldata,
        value: 0n,
      } as any,
    });

    console.log(`    TX: ${result.transactionHash}`);

    // Wait for receipt
    const receipt = await publicClient.waitForTransactionReceipt({
      hash: result.transactionHash as Hex,
      timeout: 120_000,
    });

    if (receipt.status === "reverted") {
      throw new Error(`${label} deployment reverted: ${result.transactionHash}`);
    }

    // Brief delay then verify code deployed
    await new Promise(r => setTimeout(r, 3000));
    const code = await publicClient.getCode({ address: predicted });
    if (!code || code === "0x") {
      // Retry once more after a longer wait
      await new Promise(r => setTimeout(r, 5000));
      const code2 = await publicClient.getCode({ address: predicted });
      if (!code2 || code2 === "0x") {
        throw new Error(`${label} deployment succeeded but no code at ${predicted}`);
      }
    }

    console.log(`    Deployed: ${predicted}`);
    return predicted;
  }

  // ── Step 1: Deploy BuyrToken implementation ────────────────────

  console.log("\n  Step 1/4: Deploy BuyrToken implementation");
  const buyrImplAddr = await create2Deploy(buyrImplBytecode, "BuyrToken impl");

  // ── Step 2: Deploy BuyrToken ERC1967Proxy ──────────────────────

  console.log("\n  Step 2/4: Deploy BuyrToken ERC1967Proxy");
  const buyrProxyConstructorArgs = encodeAbiParameters(
    parseAbiParameters("address, bytes"),
    [buyrImplAddr, initializeCalldata as Hex]
  );
  const buyrProxyInitCode = concat([proxyBytecode, buyrProxyConstructorArgs]);
  const buyrProxyAddr = await create2Deploy(buyrProxyInitCode, "BuyrToken proxy");

  // ── Step 3: Deploy SellrToken implementation ───────────────────

  console.log("\n  Step 3/4: Deploy SellrToken implementation");
  const sellrImplAddr = await create2Deploy(sellrImplBytecode, "SellrToken impl");

  // ── Step 4: Deploy SellrToken ERC1967Proxy ─────────────────────

  console.log("\n  Step 4/4: Deploy SellrToken ERC1967Proxy");
  const sellrProxyConstructorArgs = encodeAbiParameters(
    parseAbiParameters("address, bytes"),
    [sellrImplAddr, initializeCalldata as Hex]
  );
  const sellrProxyInitCode = concat([proxyBytecode, sellrProxyConstructorArgs]);
  const sellrProxyAddr = await create2Deploy(sellrProxyInitCode, "SellrToken proxy");

  // ── Verify ownership ──────────────────────────────────────────

  if (!dryRun) {
    console.log("\n  Verifying ownership...");
    const ownerAbi = [{
      name: "owner",
      type: "function",
      inputs: [],
      outputs: [{ name: "", type: "address" }],
      stateMutability: "view",
    }] as const;

    const buyrOwner = await publicClient.readContract({
      address: buyrProxyAddr,
      abi: ownerAbi,
      functionName: "owner",
    });
    const sellrOwner = await publicClient.readContract({
      address: sellrProxyAddr,
      abi: ownerAbi,
      functionName: "owner",
    });

    console.log(`    $BUYR owner:  ${buyrOwner}`);
    console.log(`    $SELLR owner: ${sellrOwner}`);

    if (buyrOwner.toLowerCase() !== CONTRACT_OWNER.toLowerCase()) {
      console.error(`    BUYR owner mismatch! Expected ${CONTRACT_OWNER}`);
    }
    if (sellrOwner.toLowerCase() !== CONTRACT_OWNER.toLowerCase()) {
      console.error(`    SELLR owner mismatch! Expected ${CONTRACT_OWNER}`);
    }
  }

  // ── Summary ────────────────────────────────────────────────────

  const remaining = await publicClient.getBalance({ address: deployerAddr });

  console.log("\n╔══════════════════════════════════════════════════════════╗");
  console.log("║                 DEPLOYMENT COMPLETE                      ║");
  console.log("╠══════════════════════════════════════════════════════════╣");
  console.log(`║  Network:       ${networkName.padEnd(39)}║`);
  console.log(`║  Owner:         ${CONTRACT_OWNER}  ║`);
  console.log(`║                                                          ║`);
  console.log(`║  $BUYR proxy:   ${buyrProxyAddr}  ║`);
  console.log(`║  $BUYR impl:    ${buyrImplAddr}  ║`);
  console.log(`║  $SELLR proxy:  ${sellrProxyAddr}  ║`);
  console.log(`║  $SELLR impl:   ${sellrImplAddr}  ║`);
  console.log(`║                                                          ║`);
  console.log(`║  Gas spent:     ${formatEther(balance - remaining).padEnd(39)}║`);
  console.log(`║  ETH remaining: ${formatEther(remaining).padEnd(39)}║`);
  console.log("╚══════════════════════════════════════════════════════════╝");

  console.log("\n  Add to .env:");
  console.log(`  BUYR_TOKEN_ADDRESS=${buyrProxyAddr}`);
  console.log(`  SELLR_TOKEN_ADDRESS=${sellrProxyAddr}`);
  console.log(`  BUYR_IMPL_ADDRESS=${buyrImplAddr}`);
  console.log(`  SELLR_IMPL_ADDRESS=${sellrImplAddr}`);

  console.log("\n  Verify on BaseScan:");
  console.log(`  https://basescan.org/address/${buyrProxyAddr}`);
  console.log(`  https://basescan.org/address/${sellrProxyAddr}`);
}

deploy().catch((err) => {
  console.error("Deployment failed:", err);
  process.exit(1);
});
