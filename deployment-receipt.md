# TOKEN-001 Deployment Receipt — BuyrToken + SellrToken

> **Status:** PENDING DEPLOYMENT
> **Chain:** Base Mainnet (chainId 8453)
> **Deployer:** shulam.base.eth (0x123675EcF5524433B71616C57bDe130fE21156d8)
> **Tool:** Remix IDE + Coinbase Smart Wallet
> **Compiler:** Solidity 0.8.20, optimizer 200 runs
> **OpenZeppelin:** v5.1.0

## Deployed Contracts

| Contract | Address | Tx Hash | Block |
|----------|---------|---------|-------|
| BuyrToken ($BUYR) | `[FILL AFTER DEPLOY]` | `[FILL]` | `[FILL]` |
| SellrToken ($SELLR) | `[FILL AFTER DEPLOY]` | `[FILL]` | `[FILL]` |

## Owner

`0x123675EcF5524433B71616C57bDe130fE21156d8` (shulam.base.eth)

Both "Created by" and `owner()` point to this address.

## Basescan Verification

| Contract | Verification URL |
|----------|-----------------|
| BuyrToken | `https://basescan.org/address/[ADDR]#code` |
| SellrToken | `https://basescan.org/address/[ADDR]#code` |

## Post-Deployment Verification

```
BuyrToken:
  [ ] name()                    → "Shulam Buyer Token"
  [ ] symbol()                  → "BUYR"
  [ ] decimals()                → 18
  [ ] totalSupply()             → 0
  [ ] MAX_SUPPLY()              → 10000000000000000000000000000
  [ ] emissionOracle()          → 0x0000000000000000000000000000000000000000
  [ ] pendingEmissionOracle()   → 0x0000000000000000000000000000000000000000
  [ ] emissionOracleLocked()    → false
  [ ] owner()                   → 0x123675EcF5524433B71616C57bDe130fE21156d8

SellrToken:
  [ ] name()                    → "Shulam Seller Token"
  [ ] symbol()                  → "SELLR"
  [ ] decimals()                → 18
  [ ] totalSupply()             → 0
  [ ] MAX_SUPPLY()              → 1000000000000000000000000000
  [ ] emissionOracle()          → 0x0000000000000000000000000000000000000000
  [ ] pendingEmissionOracle()   → 0x0000000000000000000000000000000000000000
  [ ] emissionOracleLocked()    → false
  [ ] owner()                   → 0x123675EcF5524433B71616C57bDe130fE21156d8
```

## Deployment Date

`[FILL AFTER DEPLOY]`

## Constructor Arguments (ABI-encoded)

Both contracts use the same constructor arg:

```
0x000000000000000000000000123675EcF5524433B71616C57bDe130fE21156d8
```

## Next Steps (Do NOT Execute Now)

1. Deploy EmissionOracle (with `configureTokens()` that calls `acceptEmissionOracle()`)
2. Call `setEmissionOracle(oracleAddr)` on BuyrToken from shulam.base.eth
3. Call `setEmissionOracle(oracleAddr)` on SellrToken from shulam.base.eth
4. Call `configureTokens(buyrAddr, sellrAddr)` on EmissionOracle
5. Verify `emissionOracleLocked() == true` on both tokens
