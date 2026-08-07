# Challenge 1 — Unstoppable

## Vulnerability
Balance manipulation / donation attack. The vault's flash loan check compares its internal accounting (`totalSupply` from shares issued) against the actual token balance (`balanceOf(address(this))`). These two values are assumed to always match — but nothing enforces that assumption.

## Attack Path
1. Transfer 1e18 DVT tokens directly to the vault, outside of the normal deposit function — bypassing the share-minting logic entirely.
2. This inflates `token.balanceOf(address(vault))` without touching `totalSupply`.
3. The vault's `flashLoan()` function checks that these two values match before allowing a loan. Since they no longer match, every future flash loan call reverts.
4. Result: the vault is permanently bricked — no attacker profit needed, just denial of service.

## Key Insight
This isn't a reentrancy or arithmetic bug — it's a broken assumption. The vault trusted that its own `balanceOf()` would always equal its internal `totalSupply` bookkeeping, but any external actor can break that assumption with a single plain `transfer()`, since ERC20 tokens don't restrict who can send tokens to a given address.

## Why No Helper Contract Needed
Unlike Truster or Puppet, this exploit doesn't need a deployed contract or precomputed address — it's a single, direct `token.transfer()` call from the player. No nonce or transaction-count constraints applied here.

## Auditor Checklist Addition
- Are critical checks comparing `balanceOf(address(this))` against internal accounting variables (`totalSupply`, tracked deposits, etc.)?
- Can a plain, unsolicited token transfer break that comparison?
- Would such a mismatch cause a revert (DoS) or, worse, be exploitable for profit rather than just bricking?
- Fix pattern: track deposits via an internal state variable updated only through the deposit function, never trust `balanceOf()` directly for invariant checks.
