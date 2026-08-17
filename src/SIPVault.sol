// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "./interfaces/IERC20.sol";

interface ISwap {
    function swap(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut);
}

/// @title SIPVault
/// @notice On-chain recurring buy plan (crypto SIP / DCA).
///         User locks up tokenIn upfront for N intervals. Anyone can call
///         executeInterval() once an interval is due, triggering a swap
///         into tokenOut and earning a small keeper reward for doing so.
contract SIPVault {
    struct Plan {
        address user;
        address tokenIn;
        address tokenOut;
        uint256 amountPerInterval;
        uint256 interval;          // seconds between executions
        uint256 nextExecution;     // timestamp of next allowed execution
        uint256 totalIntervals;
        uint256 executedIntervals;
        uint256 totalInvested;     // tokenIn actually spent so far
        uint256 totalReceived;     // tokenOut accumulated so far
        uint256 withdrawn;         // tokenOut already withdrawn by user
        bool active;
    }

    ISwap public immutable swapRouter;

    /// @dev keeper reward in basis points, taken out of tokenOut received per swap
    uint256 public constant KEEPER_FEE_BPS = 20; // 0.2%
    uint256 public constant BPS_DENOM = 10_000;

    uint256 public nextPlanId;
    mapping(uint256 => Plan) public plans;

    event PlanCreated(
        uint256 indexed planId,
        address indexed user,
        address tokenIn,
        address tokenOut,
        uint256 amountPerInterval,
        uint256 interval,
        uint256 totalIntervals
    );
    event IntervalExecuted(
        uint256 indexed planId,
        uint256 indexed intervalNumber,
        uint256 amountIn,
        uint256 amountOut,
        address indexed keeper,
        uint256 keeperReward
    );
    event Withdrawn(uint256 indexed planId, address indexed user, uint256 amount);
    event PlanCancelled(uint256 indexed planId, uint256 refundedAmount);

    modifier onlyPlanOwner(uint256 planId) {
        require(plans[planId].user == msg.sender, "not plan owner");
        _;
    }

    constructor(address _swapRouter) {
        swapRouter = ISwap(_swapRouter);
    }

    /// @notice Create a new SIP plan. Pulls the full amount
    ///         (amountPerInterval * totalIntervals) into escrow upfront,
    ///         so later intervals never depend on live allowance/balance.
    function createPlan(
        address tokenIn,
        address tokenOut,
        uint256 amountPerInterval,
        uint256 interval,
        uint256 totalIntervals
    ) external returns (uint256 planId) {
        require(amountPerInterval > 0, "amount = 0");
        require(interval > 0, "interval = 0");
        require(totalIntervals > 0, "intervals = 0");

        uint256 totalAmount = amountPerInterval * totalIntervals;
        require(
            IERC20(tokenIn).transferFrom(msg.sender, address(this), totalAmount),
            "transferFrom failed"
        );

        planId = nextPlanId++;
        plans[planId] = Plan({
            user: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountPerInterval: amountPerInterval,
            interval: interval,
            nextExecution: block.timestamp + interval,
            totalIntervals: totalIntervals,
            executedIntervals: 0,
            totalInvested: 0,
            totalReceived: 0,
            withdrawn: 0,
            active: true
        });

        emit PlanCreated(planId, msg.sender, tokenIn, tokenOut, amountPerInterval, interval, totalIntervals);
    }

    /// @notice Execute the next due interval of a plan. Callable by anyone
    ///         (a keeper bot, or you manually for a demo) once nextExecution
    ///         has passed. Caller earns a small cut of the swap output.
    function executeInterval(uint256 planId) external {
        Plan storage plan = plans[planId];
        require(plan.active, "plan not active");
        require(block.timestamp >= plan.nextExecution, "interval not due yet");
        require(plan.executedIntervals < plan.totalIntervals, "plan complete");

        IERC20(plan.tokenIn).approve(address(swapRouter), plan.amountPerInterval);
        uint256 amountOut = swapRouter.swap(plan.tokenIn, plan.tokenOut, plan.amountPerInterval);

        uint256 keeperReward = (amountOut * KEEPER_FEE_BPS) / BPS_DENOM;
        uint256 userAmount = amountOut - keeperReward;

        plan.totalInvested += plan.amountPerInterval;
        plan.totalReceived += userAmount;
        plan.executedIntervals += 1;
        plan.nextExecution += plan.interval;

        if (plan.executedIntervals == plan.totalIntervals) {
            plan.active = false;
        }

        if (keeperReward > 0) {
            IERC20(plan.tokenOut).transfer(msg.sender, keeperReward);
        }

        emit IntervalExecuted(planId, plan.executedIntervals, plan.amountPerInterval, userAmount, msg.sender, keeperReward);
    }

    /// @notice Withdraw accumulated tokenOut from a plan.
    function withdraw(uint256 planId) external onlyPlanOwner(planId) {
        Plan storage plan = plans[planId];
        uint256 available = plan.totalReceived - plan.withdrawn;
        require(available > 0, "nothing to withdraw");

        plan.withdrawn += available;
        IERC20(plan.tokenOut).transfer(plan.user, available);

        emit Withdrawn(planId, plan.user, available);
    }

    /// @notice Cancel a plan early and refund unspent tokenIn.
    function cancelPlan(uint256 planId) external onlyPlanOwner(planId) {
        Plan storage plan = plans[planId];
        require(plan.active, "already inactive");

        plan.active = false;

        uint256 remainingIntervals = plan.totalIntervals - plan.executedIntervals;
        uint256 refund = remainingIntervals * plan.amountPerInterval;

        if (refund > 0) {
            IERC20(plan.tokenIn).transfer(plan.user, refund);
        }

        emit PlanCancelled(planId, refund);
    }

    /// @notice View helper: average cost basis (tokenIn spent per tokenOut received), scaled 1e18.
    function averageCostBasis(uint256 planId) external view returns (uint256) {
        Plan storage plan = plans[planId];
        if (plan.totalReceived == 0) return 0;
        return (plan.totalInvested * 1e18) / plan.totalReceived;
    }

    function getPlan(uint256 planId) external view returns (Plan memory) {
        return plans[planId];
    }
}
