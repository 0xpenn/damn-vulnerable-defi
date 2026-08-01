# Challenge 3 — Truster

## What happened with git first
PAT token expired so had to create a new one. Also discovered I wasn't documenting properly — pushed solutions 1 and 2 to GitHub properly after fixing this.

## The Bug
`flashLoan()` accepts arbitrary `target` + `data` and executes with the pool's own identity. No whitelist, no restriction on what can be called.

## Attack Plan
Call flashLoan with amount=0, target=token, data=approve(attacker, max) → pool approves attacker → transferFrom drains pool to recovery.

## Attempt 1 — direct calls from test
```solidity
pool.flashLoan(0, player, address(token), abi.encodeCall(token.approve, (player, TOKENS_IN_POOL)));
token.transferFrom(address(pool), recovery, TOKENS_IN_POOL);
```
Error: `Player executed more than one tx: 0 != 1`
Reason: direct calls from test don't increment vm.getNonce — counted as 0 transactions.

## Attempt 2 — TrusterAttack helper contract
Created `src/truster/TrusterAttack.sol` — constructor does flashLoan approve + transferFrom in one deployment. Test deploys it with `new TrusterAttack(...)` = 1 transaction.

First run error: `panic: arithmetic underflow or overflow`
Trace showed: attack contract constructor succeeded (tokens transferred to recovery ✓) BUT test function still had old direct `transferFrom` call — tried to drain already-empty pool → underflow.

Fix: removed old calls from test, left only `new TrusterAttack(...)`.

Second run error: still `panic: arithmetic underflow or overflow`
Found stray `token.transferFrom()` still on line 56 of the test file. Removed it. Only `new TrusterAttack(...)` remains.

## Auditor Checklist Addition
- Does function accept arbitrary target + data and execute with contract's own identity?
- Is target restricted to a whitelist?
- Could caller use this to make contract approve(), transfer(), or self-authorize?
- Even a 0-value flash loan is dangerous if the side-effect call is unrestricted
