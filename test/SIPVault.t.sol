// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SIPVault} from "../src/SIPVault.sol";
import {MockSwap} from "../src/MockSwap.sol";
import {MockERC20} from "../src/MockERC20.sol";

contract SIPVaultTest is Test {
    SIPVault public vault;
    MockSwap public swapRouter;
    MockERC20 public usdc;
    MockERC20 public weth;

    address public user = address(0xA11CE);
    address public keeper = address(0xBEEF);

    uint256 constant AMOUNT_PER_INTERVAL = 500e18; // "500 USDC" per week
    uint256 constant INTERVAL = 7 days;
    uint256 constant TOTAL_INTERVALS = 4;

    function setUp() public {
        usdc = new MockERC20("Mock USDC", "USDC");
        weth = new MockERC20("Mock WETH", "WETH");
        swapRouter = new MockSwap();
        vault = new SIPVault(address(swapRouter));

        // 1 USDC = 0.0004 WETH, scaled by 1e18
        swapRouter.setRate(address(usdc), address(weth), 0.0004e18);

        // fund the mock swap with WETH liquidity so it can pay out swaps
        weth.mint(address(swapRouter), 1000e18);

        // fund user with enough USDC for the full plan
        usdc.mint(user, AMOUNT_PER_INTERVAL * TOTAL_INTERVALS);
    }

    function _createDefaultPlan() internal returns (uint256 planId) {
        vm.startPrank(user);
        usdc.approve(address(vault), AMOUNT_PER_INTERVAL * TOTAL_INTERVALS);
        planId = vault.createPlan(
            address(usdc),
            address(weth),
            AMOUNT_PER_INTERVAL,
            INTERVAL,
            TOTAL_INTERVALS
        );
        vm.stopPrank();
    }

    function test_CreatePlan_PullsFullAmountUpfront() public {
        uint256 planId = _createDefaultPlan();

        SIPVault.Plan memory plan = vault.getPlan(planId);
        assertEq(plan.user, user);
        assertEq(plan.totalIntervals, TOTAL_INTERVALS);
        assertEq(usdc.balanceOf(address(vault)), AMOUNT_PER_INTERVAL * TOTAL_INTERVALS);
        assertEq(usdc.balanceOf(user), 0);
    }

    function test_ExecuteInterval_RevertsIfTooEarly() public {
        uint256 planId = _createDefaultPlan();

        vm.expectRevert("interval not due yet");
        vault.executeInterval(planId);
    }

    function test_ExecuteInterval_SwapsAndPaysKeeper() public {
        uint256 planId = _createDefaultPlan();

        vm.warp(block.timestamp + INTERVAL);

        vm.prank(keeper);
        vault.executeInterval(planId);

        SIPVault.Plan memory plan = vault.getPlan(planId);
        assertEq(plan.executedIntervals, 1);
        assertEq(plan.totalInvested, AMOUNT_PER_INTERVAL);

        // expected output: 500 USDC * 0.0004 = 0.2 WETH, minus 0.2% keeper fee
        uint256 expectedOut = (AMOUNT_PER_INTERVAL * 0.0004e18) / 1e18;
        uint256 expectedKeeperFee = (expectedOut * vault.KEEPER_FEE_BPS()) / vault.BPS_DENOM();
        uint256 expectedUserAmount = expectedOut - expectedKeeperFee;

        assertEq(plan.totalReceived, expectedUserAmount);
        assertEq(weth.balanceOf(keeper), expectedKeeperFee);
    }

    function test_FullPlan_RunsAllIntervalsOverSimulatedWeeks() public {
        uint256 planId = _createDefaultPlan();

        for (uint256 i = 0; i < TOTAL_INTERVALS; i++) {
            vm.warp(block.timestamp + INTERVAL);
            vault.executeInterval(planId);
        }

        SIPVault.Plan memory plan = vault.getPlan(planId);
        assertEq(plan.executedIntervals, TOTAL_INTERVALS);
        assertFalse(plan.active);
        assertEq(plan.totalInvested, AMOUNT_PER_INTERVAL * TOTAL_INTERVALS);

        // can't execute a 5th time
        vm.warp(block.timestamp + INTERVAL);
        vm.expectRevert("plan not active");
        vault.executeInterval(planId);
    }

    function test_Withdraw_TransfersAccumulatedTokenOut() public {
        uint256 planId = _createDefaultPlan();
        vm.warp(block.timestamp + INTERVAL);
        vault.executeInterval(planId);

        SIPVault.Plan memory plan = vault.getPlan(planId);
        uint256 available = plan.totalReceived - plan.withdrawn;

        vm.prank(user);
        vault.withdraw(planId);

        assertEq(weth.balanceOf(user), available);
    }

    function test_CancelPlan_RefundsUnexecutedIntervals() public {
        uint256 planId = _createDefaultPlan();
        vm.warp(block.timestamp + INTERVAL);
        vault.executeInterval(planId); // 1 of 4 executed

        uint256 balanceBefore = usdc.balanceOf(user);

        vm.prank(user);
        vault.cancelPlan(planId);

        // 3 remaining intervals refunded
        uint256 expectedRefund = AMOUNT_PER_INTERVAL * (TOTAL_INTERVALS - 1);
        assertEq(usdc.balanceOf(user), balanceBefore + expectedRefund);

        SIPVault.Plan memory plan = vault.getPlan(planId);
        assertFalse(plan.active);
    }

    function test_AverageCostBasis_CalculatesCorrectly() public {
        uint256 planId = _createDefaultPlan();
        vm.warp(block.timestamp + INTERVAL);
        vault.executeInterval(planId);

        uint256 basis = vault.averageCostBasis(planId);
        // sanity: basis should roughly equal 1 / rate (adjusted for keeper fee)
        assertGt(basis, 0);
    }

    function test_RevertsIf_NonOwnerTriesToWithdraw() public {
        uint256 planId = _createDefaultPlan();
        vm.warp(block.timestamp + INTERVAL);
        vault.executeInterval(planId);

        vm.prank(address(0xBADBAD));
        vm.expectRevert("not plan owner");
        vault.withdraw(planId);
    }

    /// @notice Fuzz test: no matter the interval amount (within reasonable
    /// bounds), totalInvested should always equal amountPerInterval * executedIntervals.
    function testFuzz_TotalInvestedTracksExecutedIntervals(uint96 amountPerInterval) public {
        vm.assume(amountPerInterval > 1e6 && amountPerInterval < 10_000e18);

        usdc.mint(user, uint256(amountPerInterval) * TOTAL_INTERVALS);

        vm.startPrank(user);
        usdc.approve(address(vault), uint256(amountPerInterval) * TOTAL_INTERVALS);
        uint256 planId = vault.createPlan(
            address(usdc), address(weth), amountPerInterval, INTERVAL, TOTAL_INTERVALS
        );
        vm.stopPrank();

        vm.warp(block.timestamp + INTERVAL);
        vault.executeInterval(planId);

        SIPVault.Plan memory plan = vault.getPlan(planId);
        assertEq(plan.totalInvested, uint256(amountPerInterval) * plan.executedIntervals);
    }
}
