// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// test setup
import {TestSetup} from "../TestSetup.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AdapterTest is TestSetup {
    event Deposit(address indexed signer, uint256 amount, uint256 timestamp);
    event Redeem(address indexed signer, uint256 amount, uint256 timestamp);

    uint256 TRILLION = 1_000_000_000_000e18;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(users.owner);
        debtToken.setLendingVaultAdapterAddress(address(lendingVaultAdapter));
    }

    function test_initial_setup() external view {
        assertEq(lendingVaultAdapter.owner(), users.owner);
        assertEq(address(lendingVaultAdapter.underlying()), address(debtToken));
        assertEq(address(lendingVaultAdapter.vault()), address(mockVault));
    }

    function test_deposit(uint256 _amount) external {
        vm.startPrank(users.owner);

        uint256 initialUnderlyingSupply = debtToken.totalSupply();
        uint256 initialVaultSupply = mockVault.totalSupply();

        vm.expectEmit(true, true, true, true);
        emit Deposit(users.owner, _amount, block.timestamp);
        lendingVaultAdapter.deposit(_amount);

        assertEq(debtToken.totalSupply(), initialUnderlyingSupply + _amount);
        assertEq(debtToken.balanceOf(address(lendingVaultAdapter)), 0);
        assertEq(debtToken.balanceOf(address(this)), 0);

        assertEq(mockVault.totalAssets(), initialVaultSupply + _amount);
    }

    function test_redeem(uint256 _depositAmount, uint256 _redeemAmount) external {
        vm.assume(_depositAmount <= TRILLION);
        vm.assume(_depositAmount >= _redeemAmount);

        vm.startPrank(users.owner);

        uint256 initialUnderlyingSupply = debtToken.totalSupply();
        uint256 initialVaultSupply = mockVault.totalSupply();

        lendingVaultAdapter.deposit(_depositAmount);

        vm.expectEmit(true, true, true, true);
        emit Redeem(users.owner, _redeemAmount, block.timestamp);
        lendingVaultAdapter.redeem(mockVault.convertToShares(_redeemAmount));

        assertEq(debtToken.totalSupply(), initialUnderlyingSupply + _depositAmount - _redeemAmount);
        assertEq(debtToken.balanceOf(address(lendingVaultAdapter)), 0);
        assertEq(debtToken.balanceOf(address(this)), 0);

        assertEq(mockVault.totalAssets(), initialVaultSupply + _depositAmount - _redeemAmount);
    }

    function test_deposit_redeem_on_active_vault(
        uint256 _existingDepositedAmount,
        uint256 _depositAmount,
        uint256 _redeemAmount
    ) external {
        vm.assume(_existingDepositedAmount <= TRILLION);
        vm.assume(_depositAmount <= TRILLION);
        vm.assume(_depositAmount >= _redeemAmount);

        // Deposit into vault as a random user
        address activeDepositor = address(1);
        deal(address(debtToken), activeDepositor, _existingDepositedAmount, true);
        vm.startPrank(activeDepositor);

        debtToken.approve(address(mockVault), _existingDepositedAmount);
        mockVault.deposit(_existingDepositedAmount, activeDepositor);

        vm.stopPrank();

        vm.startPrank(users.owner);

        uint256 initialUnderlyingSupply = debtToken.totalSupply();
        uint256 initialVaultSupply = mockVault.totalSupply();

        lendingVaultAdapter.deposit(_depositAmount);

        assertEq(debtToken.totalSupply(), initialUnderlyingSupply + _depositAmount);
        assertEq(mockVault.totalAssets(), initialVaultSupply + _depositAmount);
        assertEq(debtToken.balanceOf(address(lendingVaultAdapter)), 0);
        assertEq(debtToken.balanceOf(address(this)), 0);

        lendingVaultAdapter.redeem(mockVault.convertToShares(_redeemAmount));

        assertEq(debtToken.totalSupply(), initialUnderlyingSupply + _depositAmount - _redeemAmount);
        assertEq(mockVault.totalAssets(), initialVaultSupply + _depositAmount - _redeemAmount);
        assertEq(debtToken.balanceOf(address(lendingVaultAdapter)), 0);
        assertEq(debtToken.balanceOf(address(this)), 0);
    }

    function test_deposit_unauthorized(address _user, uint256 _amount) external {
        vm.assume(_user != lendingVaultAdapter.owner());

        vm.startPrank(_user);

        vm.expectRevert();
        lendingVaultAdapter.deposit(_amount);
    }

    function test_redeem_unauthorized(address _user, uint256 _amount) external {
        vm.assume(_user != lendingVaultAdapter.owner());

        vm.startPrank(_user);

        vm.expectRevert();
        lendingVaultAdapter.redeem(_amount);
    }

    function test_recover(uint256 _amount) external {
        ERC20 testToken = new ERC20("Test Token", "TTT");

        deal(address(testToken), address(lendingVaultAdapter), _amount);

        vm.startPrank(users.owner);

        assertEq(testToken.balanceOf(users.owner), 0);
        assertEq(testToken.balanceOf(address(lendingVaultAdapter)), _amount);

        lendingVaultAdapter.recover(address(testToken));

        assertEq(testToken.balanceOf(users.owner), _amount);
        assertEq(testToken.balanceOf(address(lendingVaultAdapter)), 0);
    }

    function test_recover_as_non_owner(address user) external {
        vm.assume(user != lendingVaultAdapter.owner());

        vm.startPrank(user);

        vm.expectRevert();
        lendingVaultAdapter.recover(address(debtToken));
    }
}
