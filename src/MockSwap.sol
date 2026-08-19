// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title MockSwap
/// @notice A fake "DEX" with an admin-settable exchange rate.
///         Lets us test SIPVault's swap logic without depending on
///         real Uniswap liquidity on a testnet. Swap it for a real
///         router later (Uniswap V2 Router) once the SIP logic is solid.
contract MockSwap {
    using SafeERC20 for IERC20;

    /// @dev price expressed as: 1 tokenIn = rate tokenOut, scaled by 1e18
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

    function setRate(address tokenIn, address tokenOut, uint256 _rate) external onlyOwner {
        rate[tokenIn][tokenOut] = _rate;
        emit RateSet(tokenIn, tokenOut, _rate);
    }

    /// @notice Swap tokenIn for tokenOut at the fixed rate.
    /// @param minAmountOut reverts if the computed output is below this —
    ///        mirrors the slippage check a real router/aggregator would enforce.
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut)
        external
        returns (uint256 amountOut)
    {
        uint256 r = rate[tokenIn][tokenOut];
        require(r > 0, "rate not set");

        amountOut = (amountIn * r) / 1e18;
        require(amountOut >= minAmountOut, "MockSwap: slippage");

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        emit Swapped(tokenIn, tokenOut, amountIn, amountOut);
    }
}
