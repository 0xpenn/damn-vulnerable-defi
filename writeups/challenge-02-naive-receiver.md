# Challenge 2 — Naive Receiver

## Vulnerability
ERC-2771 meta-transaction sender spoofing, combined with a naive flash loan fee mechanism. Two separate weaknesses chained together.

## Attack Path
1. Drain the receiver's fees: batch 10 flash loan calls in a single transaction via `pool.multicall()`, each one forcing `FlashLoanReceiver` to pay a fixed fee it can't opt out of - draining its full 10 ETH balance into the pool.
2. Spoof the sender for withdrawal: the pool's `withdraw()` function uses `_msgSender()`, which reads the sender from the trailing 20 bytes of calldata rather than `msg.sender` directly - intended to let a trusted forwarder relay transactions on a user's behalf.
3. Append `deployer`'s address as the last 20 bytes of the `withdraw()` calldata, so `_msgSender()` resolves to `deployer` (who owns the full 1010 ETH in deposits) instead of `player`.
4. Wrap that spoofed `withdraw()` call inside `pool.multicall()` before sending it through `BasicForwarder.execute()`. Without this, the forwarder appends its own trailing address (`request.from`, which is `player`) on top of the manually appended `deployer` bytes, overwriting the spoof and causing an underflow revert.
5. Sign and execute the forwarder request. `multicall()`'s internal `delegatecall` isolates the inner calldata from the forwarder's outer append, preserving the spoofed `deployer` address.
6. Full 1010 ETH withdrawn to `recovery`, in exactly 2 player transactions, satisfying the `nonce <= 2` requirement.

## Key Insight
Any contract using the "trailing calldata bytes as sender" ERC-2771 pattern is vulnerable if anything else in the call chain also appends bytes after yours - the trusted forwarder isn't malicious here, but its own honest behavior collides with a manually crafted spoof unless that spoof is isolated inside a nested call.

## Why the Multicall Wrapping Was Necessary
Without it: trailing 20 bytes = player, spoof fails.
With it: the forwarder appends player to the outer multicall(...) calldata, but multicall executes calls[i] via delegatecall, using the inner bytes array exactly as constructed - untouched by what the outer call appended.

## Errors Encountered
- Initial attempt sent the spoofed withdraw() calldata directly as request.data - reverted with arithmetic underflow or overflow, since _msgSender() resolved to player (0 deposits) instead of deployer.
- Traced the issue via the raw calldata in the trace output, noticing the trailing 20 bytes matched player's address instead of deployer's.
- Root cause: the forwarder's own address-append behavior, not a mistake in the spoofing logic itself.

## Auditor Checklist Addition
- Does _msgSender() read trailing bytes of msg.data to determine sender (ERC-2771 pattern)?
- Is a trusted forwarder also appending an address to calldata before relaying?
- If calldata is manually crafted to spoof a sender for an inner/nested call, will an outer layer append additional bytes and clobber it?
- Fix/exploit pattern: wrap the inner call in multicall/delegatecall so its calldata is isolated from whatever the outer layer appends.
