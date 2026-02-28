# TOKEN-001 Deployment Receipt — BuyrToken + SellrToken

> **Status:** DEPLOYED + VERIFIED
> **Date:** 2026-02-28
> **Chain:** Base Mainnet (chainId 8453)
> **Owner:** Shulam.base.eth (`0x123675EcF5524433B71616C57bDe130fE21156d8`)
> **Deployer:** CDP shulam-super-admin (`0xC4BBD4D2F3aac66aB39e74e7369C711073E43908`)
> **Method:** CREATE2 via Nick's Factory (`0x4e59b44847b379578588920cA78FbF26c0B4956C`)
> **Compiler:** Solidity 0.8.24, optimizer 200 runs
> **OpenZeppelin:** v5.1.0 (upgradeable)
> **Pattern:** UUPS Proxy (ERC1967)

## Deployed Contracts

| Contract | Address | TX Hash |
|----------|---------|---------|
| $BUYR proxy | `0x3cF16cEf57fE43e792bD161aA4fa3c44682640b2` | `0xddd9c6f5f2e738c7cac4cf8fc930091a092b52d106d46463741c850efc05a310` |
| $BUYR impl | `0xfcCFf36627f5B003A46a04aEFbbf9dEdaBC0c238` | `0xf29182a8efa9d6e5e2c4373e3311bacccb1720653275731303c7a5ce7437fedc` |
| $SELLR proxy | `0xCe0AC85Cc16C9570fDf52D8C97177CBc6ec7c698` | `0x2f934e02ceea1a37b12b1f13f2f4125f0ab292c7628bb800c9a7418ea81a2d59` |
| $SELLR impl | `0x3b044ce24a24059395AeDd775E728361FaAdE7fE` | `0x9c2d567f6c0a109b21b6cca9ac8fe5c0a3e90b455c4ea04f90dc153c4e16c57c` |

## Owner

`0x123675EcF5524433B71616C57bDe130fE21156d8` (Shulam.base.eth)

Both proxies' `owner()` returns this address. Deployer has zero post-deploy privileges.

## Verification

| Verifier | Status |
|----------|--------|
| Sourcify | All 4 contracts: `exact_match` |
| Blockscout | All 4 contracts: verified |
| BaseScan | All 4 contracts: verified (via Etherscan API V2) |

- BaseScan: `https://basescan.org/address/0x3cF16cEf57fE43e792bD161aA4fa3c44682640b2`
- BaseScan: `https://basescan.org/address/0xCe0AC85Cc16C9570fDf52D8C97177CBc6ec7c698`

## Post-Deployment Verification

```
BuyrToken (via proxy 0x3cF16c...):
  [x] name()                    → "Shulam Buyer Token"
  [x] symbol()                  → "BUYR"
  [x] decimals()                → 18
  [x] totalSupply()             → 0
  [x] MAX_SUPPLY()              → 10,000,000,000 × 10^18
  [x] emissionOracle()          → 0x0000000000000000000000000000000000000000
  [x] emissionOracleLocked()    → false
  [x] owner()                   → 0x123675EcF5524433B71616C57bDe130fE21156d8

SellrToken (via proxy 0xCe0AC8...):
  [x] name()                    → "Shulam Seller Token"
  [x] symbol()                  → "SELLR"
  [x] decimals()                → 18
  [x] totalSupply()             → 0
  [x] MAX_SUPPLY()              → 1,000,000,000 × 10^18
  [x] emissionOracle()          → 0x0000000000000000000000000000000000000000
  [x] emissionOracleLocked()    → false
  [x] owner()                   → 0x123675EcF5524433B71616C57bDe130fE21156d8
```

## Environment Variables

```env
BUYR_TOKEN_ADDRESS=0x3cF16cEf57fE43e792bD161aA4fa3c44682640b2
SELLR_TOKEN_ADDRESS=0xCe0AC85Cc16C9570fDf52D8C97177CBc6ec7c698
BUYR_IMPL_ADDRESS=0xfcCFf36627f5B003A46a04aEFbbf9dEdaBC0c238
SELLR_IMPL_ADDRESS=0x3b044ce24a24059395AeDd775E728361FaAdE7fE
```

## Gas Cost

- Total gas spent: ~0.0000215 ETH (~$0.05)
- Deployer ETH remaining: ~0.00996 ETH

## Next Steps (Do NOT Execute Now)

1. Deploy EmissionOracle
2. Call `setEmissionOracle(oracleAddr)` on BuyrToken from Shulam.base.eth
3. Call `setEmissionOracle(oracleAddr)` on SellrToken from Shulam.base.eth
4. EmissionOracle calls `acceptEmissionOracle()` on both tokens
5. Verify `emissionOracleLocked() == true` on both tokens
