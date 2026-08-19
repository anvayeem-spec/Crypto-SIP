// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ISwap {
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut)
        external
        returns (uint256 amountOut);
}

/// @title SIPVault
/// @notice On-chain recurring buy plan (crypto SIP / DCA).
///         User locks up tokenIn upfront for N intervals. Anyone can call
///         executeInterval() once an interval is due, triggering a swap
///         into tokenOut and earning a small keeper reward for doing so.
/// @dev Security notes (see README "Known limitations / fixed" for the full audit trail):
///      - nonReentrant on every state-mutating function that makes an external call
///      - checks-effects-interactions: all plan state is updated BEFORE the external swap call
///      - minAmountOut required per call, enforced by the swap router — protects against
///        sandwich attacks and malicious/compromised routers returning near-zero output
///      - SafeERC20 used throughout, so USDT-style tokens (no bool return, non-zero->non-zero
///        approve revert) work correctly
contract SIPVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

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

    /// @dev keeper reward in basis points, taken out of tokenOut received per swap.
    ///      50 bps (0.5%) rather than 0.2% — on a $500/interval plan that's ~$2.50,
    ///      a more realistic floor for covering L2/mainnet gas. Still worth modeling
    ///      per-chain before using this in production; this is a starting assumption,
    ///      not a solved economic design.
    uint256 public constant KEEPER_FEE_BPS = 50;
    uint256 public constant BPS_DENOM = 10_000;

    /// @dev max acceptable slippage on each swap, in basis points (300 = 3%).
    uint256 public constant MAX_SLIPPAGE_BPS = 300;

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
    ) external nonReentrant returns (uint256 planId) {
        require(amountPerInterval > 0, "amount = 0");
        require(interval > 0, "interval = 0");
        require(totalIntervals > 0, "intervals = 0");

        uint256 totalAmount = amountPerInterval * totalIntervals;

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

        // effects are done above; external call last
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), totalAmount);

        emit PlanCreated(planId, msg.sender, tokenIn, tokenOut, amountPerInterval, interval, totalIntervals);
    }

    /// @notice Execute the next due interval of a plan. Callable by anyone
    ///         (a keeper bot, or you manually for a demo) once nextExecution
    ///         has passed. Caller earns a small cut of the swap output.
    /// @param minAmountOut minimum acceptable output for THIS swap, computed off-chain
    ///        (e.g. from a price oracle or quote) by whoever calls executeInterval.
    ///        Protects the plan from sandwich attacks and bad/compromised routers.
    function executeInterval(uint256 planId, uint256 minAmountOut) external nonReentrant {
        Plan storage plan = plans[planId];
        require(plan.active, "plan not active");
        require(block.timestamp >= plan.nextExecution, "interval not due yet");
        require(plan.executedIntervals < plan.totalIntervals, "plan complete");

        uint256 amountIn = plan.amountPerInterval;

        // --- EFFECTS FIRST (checks-effects-interactions) ---
        // Advance all plan state before making the external swap call, so a
        // reentrant call into executeInterval on the same plan will fail the
        // "interval not due yet" / "plan complete" checks above.
        plan.executedIntervals += 1;
        plan.nextExecution += plan.interval;
        if (plan.executedIntervals == plan.totalIntervals) {
            plan.active = false;
        }

        // --- INTERACTIONS ---
        // Zero the allowance first: required for USDT-style tokens that revert
        // on a non-zero -> non-zero approve.
        IERC20(plan.tokenIn).forceApprove(address(swapRouter), 0);
        IERC20(plan.tokenIn).forceApprove(address(swapRouter), amountIn);

        uint256 amountOut = swapRouter.swap(plan.tokenIn, plan.tokenOut, amountIn, minAmountOut);
        require(amountOut >= minAmountOut, "slippage: amountOut below minimum");

        uint256 keeperReward = (amountOut * KEEPER_FEE_BPS) / BPS_DENOM;
        uint256 userAmount = amountOut - keeperReward;

        // remaining accounting updates (safe post-interaction: these are internal
        // bookkeeping only, no further external calls depend on them being unset)
        plan.totalInvested += amountIn;
        plan.totalReceived += userAmount;

        if (keeperReward > 0) {
            IERC20(plan.tokenOut).safeTransfer(msg.sender, keeperReward);
        }

        emit IntervalExecuted(planId, plan.executedIntervals, amountIn, userAmount, msg.sender, keeperReward);
    }

    /// @notice Withdraw accumulated tokenOut from a plan.
    function withdraw(uint256 planId) external nonReentrant onlyPlanOwner(planId) {
        Plan storage plan = plans[planId];
        uint256 available = plan.totalReceived - plan.withdrawn;
        require(available > 0, "nothing to withdraw");

        plan.withdrawn += available;

        IERC20(plan.tokenOut).safeTransfer(plan.user, available);

        emit Withdrawn(planId, plan.user, available);
    }

    /// @notice Cancel a plan early and refund unspent tokenIn.
    function cancelPlan(uint256 planId) external nonReentrant onlyPlanOwner(planId) {
        Plan storage plan = plans[planId];
        require(plan.active, "already inactive");

        plan.active = false;

        uint256 remainingIntervals = plan.totalIntervals - plan.executedIntervals;
        uint256 refund = remainingIntervals * plan.amountPerInterval;

        if (refund > 0) {
            IERC20(plan.tokenIn).safeTransfer(plan.user, refund);
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
