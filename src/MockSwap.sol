// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "./interfaces/IERC20.sol";

/// @title MockSwap
/// @notice A fake "DEX" with an admin-settable exchange rate.
///         Lets us test SIPVault's swap logic without depending on
///         real Uniswap liquidity on a testnet. Swap it for a real
///         router later (Uniswap V2 Router) once the SIP logic is solid.
contract MockSwap {
    /// @dev price expressed as: 1 tokenIn = rate tokenOut, scaled by 1e18
    /// e.g. if 1 USDC = 0.0004 WETH, rate = 0.0004e18
    mapping(address => mapping(address => uint256)) public rate;

    address public owner;

    event RateSet(address indexed tokenIn, address indexed tokenOut, uint256 rate);
    event Swapped(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Set the exchange rate between two tokens (owner/test only)
    function setRate(address tokenIn, address tokenOut, uint256 _rate) external onlyOwner {
        rate[tokenIn][tokenOut] = _rate;
        emit RateSet(tokenIn, tokenOut, _rate);
    }

    /// @notice Swap tokenIn for tokenOut at the fixed rate.
    /// @dev Caller must have approved this contract for amountIn.
    ///      This contract must be pre-funded with tokenOut liquidity for the demo.
    function swap(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut) {
        uint256 r = rate[tokenIn][tokenOut];
        require(r > 0, "rate not set");

        amountOut = (amountIn * r) / 1e18;
        require(amountOut > 0, "zero output");

        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "transferFrom failed");
        require(IERC20(tokenOut).transfer(msg.sender, amountOut), "transfer failed");

        emit Swapped(tokenIn, tokenOut, amountIn, amountOut);
    }
}
