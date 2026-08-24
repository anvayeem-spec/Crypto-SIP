// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISIPVault {
    function executeInterval(uint256 planId, uint256 minAmountOut) external;
}

/// @notice A malicious "swap router" that tries to reenter SIPVault.executeInterval
///         mid-swap, simulating a compromised or malicious router. Used only in tests
///         to prove the checks-effects-interactions fix actually blocks the reentrant
///         drain the original review flagged.
contract MaliciousRouter {
    ISIPVault public vault;
    uint256 public targetPlanId;
    bool public attack;

    function setTarget(address _vault, uint256 _planId) external {
        vault = ISIPVault(_vault);
        targetPlanId = _planId;
        attack = true;
    }

    /// @dev Matches ISwap's signature so SIPVault can call it like a real router.
    function swap(address, address, uint256, uint256) external returns (uint256 amountOut) {
        if (attack) {
            attack = false; // prevent infinite recursion in the test itself
            // Attempt to re-enter the vault on the same plan, before SIPVault's
            // own state updates would (in the vulnerable version) have advanced.
            vault.executeInterval(targetPlanId, 0);
        }
        // Return 0 — this mock never actually pays out, it only exists to test
        // that the reentrant call reverts.
        return 0;
    }
}
