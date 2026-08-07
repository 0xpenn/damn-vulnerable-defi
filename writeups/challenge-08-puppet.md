# Challenge 8 — Puppet

## Vulnerability
Oracle spot-price manipulation. The lending pool prices DVT by reading a Uniswap V1 exchange's raw ETH/token balance ratio, live, with no TWAP or external feed to smooth it out.

## Attack Path
1. Compute the future address of an attack contract before deploying it, using `vm.computeCreateAddress(player, vm.getNonce(player))`.
2. Transfer player's DVT tokens to that precomputed address (funding the contract before it exists).
3. Deploy `PuppetAttack`, passing it the lending pool, the V1 exchange, the token, `recovery`, and the token amount — sending player's full ETH balance along with the deployment.
4. Inside the attack contract's constructor: dump the received DVT into the Uniswap V1 exchange, crashing the token's apparent ETH price.
5. With the price crushed, borrow the pool's entire token supply for a small fraction of ETH as collateral.
6. Send the drained tokens to `recovery`.

## Key Insight
Uniswap V1's price is just `ETH balance / token balance` on the exchange contract — no protection against one large trade moving it. Because the pool checks this ratio *at the moment of borrowing*, in the same transaction as the manipulation, there's no delay or averaging to defend against it.

## Why the Precomputed Address
Same one-transaction constraint as Truster — the exploit needs to fund an address with tokens *before* deploying the contract at that address, so the attack contract can immediately use those tokens in its constructor without a separate funding transaction bumping the nonce count.

## Auditor Checklist Addition
- Is price derived live from a DEX pair/exchange's raw balances rather than a TWAP or external oracle?
- Can a single large trade or direct balance manipulation move that price meaningfully?
- Is the manipulated price trusted for collateral or borrow calculations in the same transaction, with no averaging or delay?
