// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import { Invariants } from "./utils/Invariants.sol";

contract TestInvariants is Invariants {
	function setUp() public {}

	/*
	 * Test that the invariant is preserved by the depositUnderlying operation
	 *
	 * Values defined as uint96 to restrict the range that the inputs can be
	 * fuzzed over: inputs close to 2^128 can cause arithmetic overflows
	 */
	function testInvariantsOnDeposit(
		address caller,
		address proxyOwner,
		address[] calldata userList,
		uint96[] calldata debtList,
		uint96[] calldata overCollateralList,
		uint96 amount
	) public {
		// Discard an input if it violates assumptions
		ensureConsistency(proxyOwner, userList, debtList, overCollateralList);
		cheats.assume(0 < amount);

		// Initialize contracts, tokens and user CDPs
		setScenario(caller, proxyOwner, userList, debtList, overCollateralList);

		uint256 minted;

		for (uint256 i = 0; i < userList.length; ++i) {
			minted += debtList[i];
		}

		// Check that invariant holds before interaction
		invariantA1(userList, fakeYield, minted, 0, 0);
		invariantA2(userList, fakeYield);
		invariantA3(userList, fakeYield);
		invariantA7(userList, fakeYield);
		invariantA8(userList, fakeYield, fakeUnderlying);

		// Perform an interaction as the first user in the list
		cheats.startPrank(userList[0], userList[0]);

		// Deposit underlying tokens to a user
		assignToUser(userList[0], fakeUnderlying, amount);

		alchemist.depositUnderlying(fakeYield, amount, userList[0], minimumAmountOut(amount, fakeYield));

		cheats.stopPrank();

		// Perform an interaction as the second user in the list
		cheats.startPrank(userList[1], userList[1]);

		// Assign yield tokens to a user
		assignToUser(userList[1], fakeUnderlying, amount);
		assignYieldTokenToUser(userList[1], fakeYield, amount);

		alchemist.deposit(fakeYield, amount, userList[1]);

		cheats.stopPrank();

		// Check that invariant holds after interaction
		invariantA1(userList, fakeYield, minted, 0, 0);
		invariantA2(userList, fakeYield);
		invariantA3(userList, fakeYield);
		invariantA7(userList, fakeYield);
		invariantA8(userList, fakeYield, fakeUnderlying);
	}

	function testInvariantsOnWithdraw(
		address caller,
		address proxyOwner,
		address[] calldata userList,
		uint96[] calldata debtList,
		uint96[] calldata overCollateralList,
		uint96 amount,
		address recipient
	) public {
		ensureConsistency(proxyOwner, userList, debtList, overCollateralList);
		cheats.assume(0 < amount);
		cheats.assume(recipient != address(0));
		// Ensure first user has enough collateral to withdraw
		cheats.assume(amount <= overCollateralList[0]);

		setScenario(caller, proxyOwner, userList, debtList, overCollateralList);

		uint256 minted;

		for (uint256 i = 0; i < userList.length; ++i) {
			minted += debtList[i];
		}

		invariantA1(userList, fakeYield, minted, 0, 0);
		invariantA2(userList, fakeYield);
		invariantA3(userList, fakeYield);
		invariantA7(userList, fakeYield);
		invariantA8(userList, fakeYield, fakeUnderlying);

		// Calculate how many shares the amount corresponds to
		(uint256 totalShares, ) = alchemist.positions(userList[0], fakeYield);
		uint256 totalBalance = calculateBalance(debtList[0], overCollateralList[0], fakeUnderlying);
		uint256 shares = (totalShares * amount) / totalBalance;

		cheats.startPrank(userList[0], userList[0]);

		alchemist.withdrawUnderlying(fakeYield, shares, recipient, minimumAmountOut(amount, fakeYield));

		// Deposit additional underlying tokens to test withdraw
		assignToUser(userList[0], fakeUnderlying, amount);
		alchemist.depositUnderlying(fakeYield, amount, userList[0], minimumAmountOut(amount, fakeYield));

		alchemist.withdraw(fakeYield, shares, recipient);

		cheats.stopPrank();

		invariantA1(userList, fakeYield, minted, 0, 0);
		invariantA2(userList, fakeYield);
		invariantA3(userList, fakeYield);
		invariantA7(userList, fakeYield);
		invariantA8(userList, fakeYield, fakeUnderlying);
	}

	function testInvariantsOnWithdrawUnderlyingFrom(
		address caller,
		address proxyOwner,
		address[] calldata userList,
		uint96[] calldata debtList,
		uint96[] calldata overCollateralList,
		uint96 amount,
		address recipient
	) public {
		ensureConsistency(proxyOwner, userList, debtList, overCollateralList);
		cheats.assume(0 < amount);
		cheats.assume(recipient != address(0));
		// Ensure first user has enough collateral to withdraw
		cheats.assume(amount <= overCollateralList[0]);

		setScenario(caller, proxyOwner, userList, debtList, overCollateralList);

		uint256 minted;

		for (uint256 i = 0; i < userList.length; ++i) {
			minted += debtList[i];
		}

		invariantA1(userList, fakeYield, minted, 0, 0);
		invariantA2(userList, fakeYield);
		invariantA3(userList, fakeYield);
		invariantA7(userList, fakeYield);
		invariantA8(userList, fakeYield, fakeUnderlying);

		cheats.startPrank(userList[0], userList[0]);

		// Calculate how many shares the amount corresponds to
		(uint256 totalShares, ) = alchemist.positions(userList[0], fakeYield);
		uint256 totalBalance = calculateBalance(debtList[0], overCollateralList[0], fakeUnderlying);
		uint256 shares = (totalShares * amount) / totalBalance;

		// Approve an account to withdraw
		alchemist.approveWithdraw(userList[1], fakeYield, shares);

		cheats.stopPrank();

		// Withdraw underlying token from an owners account
		cheats.startPrank(userList[1], userList[1]);

		alchemist.withdrawUnderlyingFrom(
			userList[0],
			fakeYield,
			shares,
			recipient,
			minimumAmountOut(amount, fakeYield)
		);

		cheats.stopPrank();

		invariantA1(userList, fakeYield, minted, 0, 0);
		invariantA2(userList, fakeYield);
		invariantA3(userList, fakeYield);
		invariantA7(userList, fakeYield);
		invariantA8(userList, fakeYield, fakeUnderlying);
	}

	function testInvariantsOnWithdrawFrom(
		address caller,
		address proxyOwner,
		address[] calldata userList,
		uint96[] calldata debtList,
		uint96[] calldata overCollateralList,
		uint96 amount,
		address recipient
	) public {
		ensureConsistency(proxyOwner, userList, debtList, overCollateralList);
		cheats.assume(0 < amount);
		cheats.assume(recipient != address(0));
		// Ensure first user has enough collateral to withdraw
		cheats.assume(amount <= overCollateralList[0]);

		setScenario(caller, proxyOwner, userList, debtList, overCollateralList);

		uint256 minted;

		for (uint256 i = 0; i < userList.length; ++i) {
			minted += debtList[i];
		}

		invariantA1(userList, fakeYield, minted, 0, 0);
		invariantA2(userList, fakeYield);
		invariantA3(userList, fakeYield);
		invariantA7(userList, fakeYield);
		invariantA8(userList, fakeYield, fakeUnderlying);

		// Approve an account to withdraw
		cheats.startPrank(userList[0], userList[0]);

		// Calculate how many shares the amount corresponds to
		(uint256 totalShares, ) = alchemist.positions(userList[0], fakeYield);
		uint256 totalBalance = calculateBalance(debtList[0], overCollateralList[0], fakeUnderlying);
		uint256 shares = (totalShares * amount) / totalBalance;

		alchemist.approveWithdraw(userList[1], fakeYield, shares);

		cheats.stopPrank();

		// Withdraw yield token from an owners account
		cheats.startPrank(userList[1], userList[1]);

		alchemist.withdrawFrom(userList[0], fakeYield, shares, recipient);

		cheats.stopPrank();

		invariantA1(userList, fakeYield, minted, 0, 0);
		invariantA2(userList, fakeYield);
		invariantA3(userList, fakeYield);
		invariantA7(userList, fakeYield);
		invariantA8(userList, fakeYield, fakeUnderlying);
	}

	function testInvariantsOnMintBurnRepayLiquidate(
		address caller,
		address proxyOwner,
		address[] calldata userList,
		uint96[] calldata debtList,
		uint96[] calldata overCollateralList,
		uint96 amount,
		address recipient
	) public {
		// Discard an input if it violates assumptions
		ensureConsistency(proxyOwner, userList, debtList, overCollateralList);
		cheats.assume(10 < amount);
		cheats.assume(recipient != address(0));

		// Initialize contracts, tokens and user CDPs
		setScenario(caller, proxyOwner, userList, debtList, overCollateralList);

		uint256 minted;
		uint256 burned;
		uint256 sentToTransmuter;
		uint256 maximum;

		for (uint256 i = 0; i < userList.length; ++i) {
			minted += debtList[i];
		}

		// Check that invariant holds before interaction
		invariantA1(userList, fakeYield, minted, 0, 0);
		invariantA2(userList, fakeYield);
		invariantA3(userList, fakeYield);
		invariantA7(userList, fakeYield);
		invariantA8(userList, fakeYield, fakeUnderlying);

		// Mint and burn from an account
		cheats.startPrank(userList[0], userList[0]);

		assignToUser(userList[0], fakeUnderlying, amount);
		alchemist.depositUnderlying(fakeYield, amount, userList[0], minimumAmountOut(amount, fakeYield));

		alchemist.mint((amount / 4), userList[0]);
		minted += (amount / 4);

		alchemist.approveMint(userList[1], (amount / 4));
		alchemist.approveMint(address(transmuterBuffer), (amount / 4));

		alToken.approve(address(alchemist), amount);
		alchemist.burn((amount / 8), userList[0]);
		burned += (amount / 8);

		(, , maximum) = alchemist.getRepayLimitInfo(fakeUnderlying);

		assignToUser(userList[0], fakeUnderlying, amount);

		// Repay either maximum or remaining amount of debt
		maximum = (amount / 8) > maximum ? maximum : (amount / 8);
		alchemist.repay(fakeUnderlying, maximum, userList[0]);
		sentToTransmuter += maximum;

		cheats.stopPrank();

		// Mint from an owner's account
		cheats.startPrank(userList[1], userList[1]);

		// Mint from owner to user
		alchemist.mintFrom(userList[0], (amount / 4), userList[1]);
		minted += (amount / 4);

		cheats.stopPrank();

		// Liquidate a users debt
		cheats.startPrank(userList[0], userList[0]);

		// Set the amount to liquidate
		(, , maximum) = alchemist.getLiquidationLimitInfo(fakeUnderlying);
		maximum = (amount / 4) > maximum ? maximum : (amount / 4);

		alchemist.liquidate(fakeYield, maximum, minimumAmountOut(maximum, fakeYield));
		sentToTransmuter += maximum;

		cheats.stopPrank();

		invariantA1(userList, fakeYield, minted, burned, sentToTransmuter);
		invariantA2(userList, fakeYield);
		invariantA3(userList, fakeYield);
		invariantA7(userList, fakeYield);
		invariantA8(userList, fakeYield, fakeUnderlying);
	}
}
