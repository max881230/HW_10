// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISimpleSwap } from "./interface/ISimpleSwap.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract SimpleSwap is ISimpleSwap, ERC20 {
    // Implement core logic here
    address public tokenA_;
    address public tokenB_;

    constructor(address tokenA, address tokenB) ERC20("LiquidityProvider", "LP") {
        // check if the token address is a contract or not
        require(tokenA.code.length > 0, "SimpleSwap: TOKENA_IS_NOT_CONTRACT");
        require(tokenB.code.length > 0, "SimpleSwap: TOKENB_IS_NOT_CONTRACT");
        // check if address of token A & B are identical or not
        require(tokenA != tokenB, "SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");

        // sort the address of token to make sure address A's order is ahead of address B
        (tokenA_, tokenB_) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut) {
        // check tokenIn and tokenOut address are : tokenA or tokenB and are not identical
        require(tokenIn == tokenA_ || tokenIn == tokenB_, "SimpleSwap: INVALID_TOKEN_IN");
        require(tokenOut == tokenA_ || tokenOut == tokenB_, "SimpleSwap: INVALID_TOKEN_OUT");
        require(tokenIn != tokenOut, "SimpleSwap: IDENTICAL_ADDRESS");
        require(amountIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

        (uint256 _reserveA, uint256 _reserveB) = this.getReserves();

        if (tokenIn == tokenA_) {
            ERC20(tokenA_).transferFrom(msg.sender, address(this), amountIn);
            amountOut = (amountIn * _reserveB) / (_reserveA + amountIn);
            ERC20(tokenB_).approve(address(this), amountOut);
            ERC20(tokenB_).transferFrom(address(this), msg.sender, amountOut);
        } else if (tokenIn == tokenB_) {
            ERC20(tokenB_).transferFrom(msg.sender, address(this), amountIn);
            amountOut = (_reserveA * amountIn) / (amountIn + _reserveB);
            ERC20(tokenA_).approve(address(this), amountOut);
            ERC20(tokenA_).transferFrom(address(this), msg.sender, amountOut);
        }

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function addLiquidity(
        uint256 amountAIn,
        uint256 amountBIn
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // check amountA or amountB is not zero
        require(amountAIn > 0 && amountBIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

        // add liquidity
        (uint256 _reserveA, uint256 _reserveB) = this.getReserves();
        uint256 _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amountAIn * amountBIn);
            amountA = amountAIn;
            amountB = amountBIn;
        } else {
            liquidity = Math.min((amountAIn * _totalSupply) / _reserveA, (amountBIn * _totalSupply) / _reserveB);
            if (_totalSupply == 0) {
                liquidity = Math.sqrt(amountAIn * amountBIn);
                amountA = amountAIn;
                amountB = amountBIn;
            } else {
                if (amountAIn * _reserveB <= amountBIn * _reserveA) {
                    amountA = amountAIn;
                    amountB = (amountAIn * _reserveB) / _reserveA;
                } else {
                    amountA = (amountBIn * _reserveA) / _reserveB;
                    amountB = amountBIn;
                }
            }
        }
        ERC20(tokenA_).transferFrom(msg.sender, address(this), amountA);
        ERC20(tokenB_).transferFrom(msg.sender, address(this), amountB);

        _mint(msg.sender, liquidity);

        emit AddLiquidity(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED");

        // remove liquidity
        (uint256 _reserveA, uint256 _reserveB) = this.getReserves();
        uint256 _totalSupply = totalSupply();

        amountA = (liquidity * _reserveA) / _totalSupply;
        ERC20(tokenA_).approve(address(this), amountA);
        ERC20(tokenA_).transferFrom(address(this), msg.sender, amountA);

        amountB = (liquidity * _reserveB) / _totalSupply;
        ERC20(tokenB_).approve(address(this), amountB);
        ERC20(tokenB_).transferFrom(address(this), msg.sender, amountB);

        _transfer(msg.sender, address(this), liquidity);
        _burn(address(this), liquidity);

        emit RemoveLiquidity(msg.sender, amountA, amountB, liquidity);
    }

    function getReserves() external view returns (uint256 reserveA, uint256 reserveB) {
        reserveA = ERC20(tokenA_).balanceOf(address(this));
        reserveB = ERC20(tokenB_).balanceOf(address(this));
    }

    function getTokenA() external view returns (address) {
        return tokenA_;
    }

    function getTokenB() external view returns (address) {
        return tokenB_;
    }
}
