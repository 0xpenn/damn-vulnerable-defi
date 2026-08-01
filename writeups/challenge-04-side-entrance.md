# Challenge 4 — Side Entrance

## Process
First checked SideEntrance.t.sol to understand the setup, then checked SideEntranceLenderPool.sol to find the bug.

## The Bug
Two functions: deposit() and flashLoan(). The vulnerability is in the repayment check:

    if (address(this).balance < balanceBefore) revert RepayFailed();

It only checks raw ETH balance — not the internal balances mapping. So you can repay a flash loan by calling deposit() with the borrowed ETH. The pool gets its ETH back (check passes) but also records you as a depositor. Then you withdraw that balance and drain the pool.

## The Trick
Deposit IS the repayment. Pool can't tell the difference between "loan repaid" and "new deposit made."

Attack steps:
1. Call flashLoan(1000 ETH) — pool sends ETH, calls your execute()
2. Inside execute() — call deposit(1000 ETH) — repays loan AND registers you as depositor
3. Call withdraw() — drain your balance to recovery

## Solution
Needed a helper contract with execute() since pool calls IFlashLoanEtherReceiver(msg.sender).execute().

Created SideEntranceAttack.sol with three functions:
- attack() — triggers the flash loan
- execute() — called by pool during flash loan, deposits the ETH back
- withdraw() — pulls registered balance out to recovery

In the test file, imported SideEntranceAttack and added:

    SideEntranceAttack attacker = new SideEntranceAttack(address(pool), recovery);
    attacker.attack();
    attacker.withdraw();

Verified with: forge test --match-contract SideEntrance -vv
