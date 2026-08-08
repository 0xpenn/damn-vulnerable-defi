# Challenge 7 — Compromised

## Vulnerability
Leaked private keys for a majority (2 of 3) of a trustful oracle's price-reporting sources. Not a smart contract logic bug at all - an operational security failure. TrustfulOracle computes the median of 3 reporters' submitted prices and trusts that median completely; if you control 2 of the 3 reporters, you control the median outright.

## Attack Path
1. Decode the leaked keys. Two odd-looking hex byte-strings were given in a "leaked HTTP response" narrative. Each decoded through a two-layer pipeline: hex to ASCII (using cast --to-ascii) produced a base64 string, and that base64 string decoded (base64 -d) into a raw 32-byte private key.
2. Confirm ownership. Ran cast wallet address <key> on each decoded key and matched the output against the three trusted source addresses in the test file - 2 of the 3 matched.
3. Crash the price. Using vm.prank() with each compromised source address, called oracle.postPrice("DVNFT", 1) from both - since the oracle takes the median of 3 values and 2 of them now say "1 wei," the median becomes 1 wei regardless of the third honest source.
4. Buy cheap. As player, called exchange.buyOne{value: 1}(), acquiring the NFT for effectively nothing.
5. Inflate the price. Same two compromised sources posted a new price equal to the exchange's full ETH balance (999 ETH), making the median spike to that value.
6. Sell high. As player, approved the exchange for the NFT and called exchange.sellOne(id), receiving the exchange's entire 999 ETH balance in return.
7. Restore the price. Posted INITIAL_NFT_PRICE (999 ETH) back from both compromised sources, since _isSolved() requires the oracle's median to end unchanged from where it started.
8. Send exact proceeds to recovery. Transferred EXCHANGE_INITIAL_ETH_BALANCE (999 ETH) to recovery - not player.balance, which would have also swept up player's untouched starting 0.1 ETH.

## Key Insight
A "trustful" oracle with a fixed small set of reporters is only as strong as its weakest majority. 2-of-3 median trust means compromising just two accounts gives full price control. This has nothing to do with Solidity code quality; the contracts themselves have no bug. The vulnerability is entirely in key management outside the chain.

## Errors Encountered
- First attempt sent player.balance (not EXCHANGE_INITIAL_ETH_BALANCE) to recovery in the final step. This swept up player's leftover starting 0.1 ETH balance, causing recovery.balance to be 999.1 ETH instead of the expected 999 ETH.
- Fixed by transferring the exact constant EXCHANGE_INITIAL_ETH_BALANCE instead of the player's full wallet balance.

## Auditor Checklist Addition
- Does a price oracle rely on a small, fixed set of trusted reporters with simple median/average aggregation?
- What's the minimum number of compromised reporters needed to control the aggregate (e.g. floor(n/2) + 1 for a median of n)?
- Is there any on/off-chain leakage risk for those reporters' credentials (leaked keys, exposed logs, predictable key generation)?
- When manually calculating a "drain to recovery" step, transfer the exact known amount, not a wallet's full balance - leftover/pre-existing funds can silently inflate the transferred amount and break exact-balance assertions.
