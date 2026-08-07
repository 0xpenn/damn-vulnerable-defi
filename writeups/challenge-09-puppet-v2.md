# Challenge 9 — Puppet V2

## Vulnerability
Same class of bug as Puppet — spot-price oracle manipulation — but the pool now reads price via Uniswap **V2**'s `getReserves()` instead of a V1 exchange balance.

## Attack Path
1. Approve the Uniswap V2 router to spend player's full DVT balance.
2. Call `uniswapV2Router.swapExactTokensForTokens()`, swapping all of player's DVT for WETH. This floods the pair's token reserve and drains its WETH reserve.
3. Check `lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE)` — now tiny, since the reserve ratio has crashed.
4. Wrap enough ETH into WETH (topping up whatever WETH was already received from the swap) to cover the deposit requirement.
5. Approve the lending pool to pull that WETH, then call `borrow()` for the pool's entire token balance.
6. Transfer the borrowed tokens to `recovery`.

## Key Insight
Unlike V1, a Uniswap V2 pair's `getReserves()` doesn't move from a plain token donation — reserves only update through real `swap`/`mint`/`burn`/`sync` calls. So the manipulation has to go through the router's actual trade function, not a direct transfer, to actually shift the price the pool reads.

## Why No Nonce Trick Needed
Unlike Truster and Puppet, this one didn't require a helper contract or precomputed address — `checkSolvedByPlayer` here only requires the final token balances to match, with no transaction-count constraint like Naive Receiver's. So the whole exploit runs as plain sequential calls inside the test function.

## Auditor Checklist Addition
- Does the oracle read reserves via a proper AMM interface (`getReserves()`, router quote functions) rather than a raw token balance?
- Even if a direct donation wouldn't move the price, can a real swap through the router still manipulate reserves enough to break downstream borrow/collateral math?
- Compare against V1-style pools in scope — the fix for one style (e.g. TWAP) may not fully cover the other if implemented incorrectly.
