# Challenge 6 — Selfie

## Skipped Challenge 5 (The Rewarder)
Too complex for now - needs Merkle trees and bitmap accounting. Coming back after Challenge 8.

## Setup
Three contracts working together:
- DamnValuableVotes - token with voting power
- SimpleGovernance - governance contract, controls the pool
- SelfiePool - flash loan pool holding 1.5M tokens

Goal: drain 1.5M tokens to recovery.

## Finding the Bug
Checked SimpleGovernance.sol. To queue a governance action you need more than half the total supply in voting power. Total supply = 2,000,000. Need more than 1,000,000. Pool has 1,500,000 sitting in it. Player has 0.

Also found emergencyExit() in SelfiePool - only governance can call it. So the plan is to hijack governance.

## The Problem
2-day delay before governance action can execute. Fix: use vm.warp() to skip time in Foundry.

## Attack Plan
1. Flash loan 1,500,000 tokens from pool
2. Inside onFlashLoan(): delegate votes, queue emergencyExit(recovery), repay loan
3. vm.warp(block.timestamp + 2 days)
4. Execute queued action - pool drained to recovery

## Solution
Created SelfieAttack.sol. In test file:
- attacker.attack() - flash loan + queue governance action
- vm.warp(block.timestamp + 2 days) - skip delay
- attacker.executeAction() - drain pool

Verified with: forge test --match-contract Selfie -vv
