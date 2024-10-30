// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";

import {MorphoAdapter} from "../../contracts/core/MorphoAdapter.sol";
import {IMorphoAdapter} from "../../contracts/interfaces/IMorphoAdapter.sol";

// contract MockERC20 is ERC20 {
//     constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

//     function mint(address to, uint256 amount) external {
//         _mint(to, amount);
//     }

//     function burn(uint256 amount) external {
//         _burn(msg.sender, amount);
//     }
// }

// contract MetaMorpho is ERC4626 {
//     constructor(IERC20 token) ERC4626(token) ERC20("Vault Share", "VLT") {}
// }

contract AdapterTest is Test {
    // MockERC20 public underlying;
    // ERC4626 public vault;
    // Adapter public adapter;

    // uint256 public TRILLION = 1_000_000_000_000e18;

    function setUp() public {
        // underlying = new MockERC20("US Bitcoin Dollar", "USBD");
        // vault = new MetaMorpho(IERC20(underlying));
        // adapter = new Adapter(address(this), address(vault), address(underlying));
        // adapter.acceptOwnership();
    }

    // function test_initial_setup() external view {
    //     assertEq(adapter.owner(), address(this));

    //     assertEq(address(adapter.underlying()), address(underlying));
    //     assertEq(address(adapter.vault()), address(vault));
    // }

    // function test_deposit(uint256 _amount) external {
    //     uint256 initialUnderlyingSupply = underlying.totalSupply();
    //     uint256 initialVaultSupply = vault.totalSupply();

    //     vm.expectEmit(true, true, true, true);
    //     emit IAdapter.Deposit(address(this), _amount, block.timestamp);
    //     adapter.deposit(_amount);

    //     assertEq(underlying.totalSupply(), initialUnderlyingSupply + _amount);
    //     assertEq(vault.totalAssets(), initialVaultSupply + _amount);
    //     assertEq(underlying.balanceOf(address(adapter)), 0);
    //     assertEq(underlying.balanceOf(address(this)), 0);
    // }

    // function test_redeem(uint256 _depositAmount, uint256 _redeemAmount) external {
    //     vm.assume(_depositAmount <= TRILLION);
    //     vm.assume(_depositAmount >= _redeemAmount);

    //     uint256 initialUnderlyingSupply = underlying.totalSupply();
    //     uint256 initialVaultSupply = vault.totalSupply();

    //     adapter.deposit(_depositAmount);

    //     vm.expectEmit(true, true, true, true);
    //     emit IAdapter.Redeem(address(this), _redeemAmount, block.timestamp);
    //     adapter.redeem(vault.convertToShares(_redeemAmount));

    //     assertEq(underlying.totalSupply(), initialUnderlyingSupply + _depositAmount - _redeemAmount);
    //     assertEq(vault.totalAssets(), initialVaultSupply + _depositAmount - _redeemAmount);
    //     assertEq(underlying.balanceOf(address(adapter)), 0);
    //     assertEq(underlying.balanceOf(address(this)), 0);
    // }

    // function test_deposit_redeem_on_active_vault(
    //     uint256 _existingDepositedAmount,
    //     uint256 _depositAmount,
    //     uint256 _redeemAmount
    // ) external {
    //     vm.assume(_existingDepositedAmount <= TRILLION);
    //     vm.assume(_depositAmount <= TRILLION);
    //     vm.assume(_depositAmount >= _redeemAmount);

    //     // Deposit into vault as a random user
    //     address activeDepositor = address(1);
    //     deal(address(underlying), activeDepositor, _existingDepositedAmount, true);
    //     vm.startPrank(activeDepositor);

    //     underlying.approve(address(vault), _existingDepositedAmount);
    //     vault.deposit(_existingDepositedAmount, activeDepositor);

    //     vm.stopPrank();

    //     uint256 initialUnderlyingSupply = underlying.totalSupply();
    //     uint256 initialVaultSupply = vault.totalSupply();

    //     adapter.deposit(_depositAmount);

    //     assertEq(underlying.totalSupply(), initialUnderlyingSupply + _depositAmount);
    //     assertEq(vault.totalAssets(), initialVaultSupply + _depositAmount);
    //     assertEq(underlying.balanceOf(address(adapter)), 0);
    //     assertEq(underlying.balanceOf(address(this)), 0);

    //     adapter.redeem(vault.convertToShares(_redeemAmount));

    //     assertEq(underlying.totalSupply(), initialUnderlyingSupply + _depositAmount - _redeemAmount);
    //     assertEq(vault.totalAssets(), initialVaultSupply + _depositAmount - _redeemAmount);
    //     assertEq(underlying.balanceOf(address(adapter)), 0);
    //     assertEq(underlying.balanceOf(address(this)), 0);
    // }

    // function test_deposit_unauthorized(address _user, uint256 _amount) external {
    //     vm.assume(_user != adapter.owner());

    //     vm.startPrank(_user);

    //     vm.expectRevert();
    //     adapter.deposit(_amount);
    // }

    // function test_redeem_unauthorized(address _user, uint256 _amount) external {
    //     vm.assume(_user != adapter.owner());

    //     vm.startPrank(_user);

    //     vm.expectRevert();
    //     adapter.redeem(_amount);
    // }

    // function test_recover(uint256 _amount) external {
    //     ERC20 testToken = new MockERC20("Test Token", "TTT");

    //     deal(address(testToken), address(adapter), _amount);

    //     assertEq(testToken.balanceOf(address(this)), 0);
    //     assertEq(testToken.balanceOf(address(adapter)), _amount);

    //     adapter.recover(address(testToken));

    //     assertEq(testToken.balanceOf(address(this)), _amount);
    //     assertEq(testToken.balanceOf(address(adapter)), 0);
    // }

    // function test_recover_as_non_owner(address user) external {
    //     vm.assume(user != adapter.owner());

    //     vm.startPrank(user);

    //     vm.expectRevert();
    //     adapter.recover(address(underlying));
    // }
}
