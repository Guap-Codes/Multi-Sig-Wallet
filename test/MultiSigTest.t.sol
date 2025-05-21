// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "../src/factory/MultiSigFactory.sol";
import "../src/core/MultiSigWallet.sol";
import "../src/core/MultiSigTimeLock.sol";

/// @title MultiSig Wallet Test Suite
/// @notice Comprehensive tests for MultiSigWallet and MultiSigTimeLock contracts
contract MultiSigTest is Test {
    MultiSigFactory factory;
    MultiSigWallet wallet;
    MultiSigTimeLock timelockWallet;

    address[] owners;
    address owner1 = address(1);
    address owner2 = address(2);
    address owner3 = address(3);
    address nonOwner = address(4);

    uint256 requiredApprovals = 2;

    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed txId);
    event Approve(address indexed owner, uint256 indexed txId);
    event Execute(uint256 indexed txId);

    /// @notice Sets up the test environment with a standard 3-owner wallet
    /// @dev Deploys both regular and timelock wallets, funds them with 10 ETH each
    function setUp() public {
        // Setup owners
        owners.push(owner1);
        owners.push(owner2);
        owners.push(owner3);

        // Deploy factory and create wallet
        factory = new MultiSigFactory();
        wallet = MultiSigWallet(
            payable(factory.createWallet(owners, requiredApprovals))
        );

        // Deploy timelock wallet
        timelockWallet = new MultiSigTimeLock(owners, requiredApprovals);

        // Fund wallets
        vm.deal(address(wallet), 10 ether);
        vm.deal(address(timelockWallet), 10 ether);
    }

    /// @notice Verifies correct wallet initialization
    /// @dev Checks owner count, required approvals, and owner status
    function testWalletCreation() public view {
        assertEq(wallet.getOwners().length, 3);
        assertEq(wallet.required(), requiredApprovals);
        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertTrue(wallet.isOwner(owner3));
        assertFalse(wallet.isOwner(nonOwner));
    }

    /// @notice Tests the transaction submission process
    /// @dev Verifies transaction details are correctly stored and events are emitted
    function testSubmitTransaction() public {
        address to = address(5);
        uint256 value = 1 ether;
        bytes memory data = "";

        vm.prank(owner1);
        vm.expectEmit(true, false, false, true);
        emit Submit(0);
        wallet.submit(to, value, data);

        (
            address txTo,
            uint256 txValue,
            bytes memory txData,
            bool executed,
            uint256 approvals
        ) = wallet.getTransaction(0);
        assertEq(txTo, to);
        assertEq(txValue, value);
        assertEq(txData, data);
        assertFalse(executed);
        assertEq(approvals, 0);
    }

    /// @notice Tests the full transaction lifecycle: submit, approve, and execute
    /// @dev Verifies multiple approvals and successful ETH transfer
    function testApproveAndExecuteTransaction() public {
        address to = address(5);
        uint256 value = 1 ether;
        bytes memory data = "";

        // Submit transaction
        vm.prank(owner1);
        wallet.submit(to, value, data);

        // First approval
        vm.prank(owner1);
        vm.expectEmit(true, true, false, true);
        emit Approve(owner1, 0);
        wallet.approve(0);

        // Second approval
        vm.prank(owner2);
        wallet.approve(0);

        // Execute
        uint256 initialBalance = address(to).balance;
        vm.prank(owner1);
        vm.expectEmit(true, false, false, true);
        emit Execute(0);
        wallet.execute(0);

        assertEq(address(to).balance - initialBalance, value);
    }

    /// @notice Tests the timelock functionality of the TimeLock wallet
    /// @dev Verifies that execution is only possible after the timelock period
    function testTimelockWallet() public {
        address to = address(5);
        uint256 value = 1 ether;
        bytes memory data = "";

        // Submit and approve
        vm.prank(owner1);
        timelockWallet.submit(to, value, data);

        vm.prank(owner1);
        timelockWallet.approve(0);
        vm.prank(owner2);
        timelockWallet.approve(0);

        // Try to execute immediately (should fail)
        vm.prank(owner1);
        vm.expectRevert("timelock not expired");
        timelockWallet.execute(0);

        // Wait 24 hours
        skip(24 hours);

        // Now execute should work
        vm.prank(owner1);
        timelockWallet.execute(0);
    }

    /// @notice Tests the approval revocation mechanism
    /// @dev Verifies that approvals can be removed and approval count is updated
    function testRevokeApproval() public {
        address to = address(5);
        uint256 value = 1 ether;
        bytes memory data = "";

        vm.prank(owner1);
        wallet.submit(to, value, data);

        vm.prank(owner1);
        wallet.approve(0);

        vm.prank(owner1);
        wallet.revoke(0);

        (, , , , uint256 approvals) = wallet.getTransaction(0);
        assertEq(approvals, 0);
    }

    /// @notice Tests the owner management functionality
    /// @dev Verifies adding new owners through proposal, approval, and execution
    function testOwnerManagement() public {
        address newOwner = address(6);

        // Propose new owner
        vm.prank(owner1);
        wallet.proposeAddOwner(newOwner);

        // Approve owner addition
        vm.prank(owner1);
        wallet.approveOwnerChange(0);
        vm.prank(owner2);
        wallet.approveOwnerChange(0);

        // Execute owner addition
        vm.prank(owner1);
        wallet.executeOwnerChange(0);

        assertTrue(wallet.isOwner(newOwner));
        assertEq(wallet.getOwners().length, 4);
    }


    function test_RevertWhen_NonOwnerSubmitsTransaction() public {
        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        wallet.submit(address(5), 1 ether, "");
    }

    function test_RevertWhen_InsufficientApprovals() public {
        vm.startPrank(owner1);
        wallet.submit(address(5), 1 ether, "");
        wallet.approve(0);
        vm.expectRevert("approvals < required");
        wallet.execute(0);
        vm.stopPrank();
    }

    function test_RevertWhen_InsufficientBalance() public {
        vm.deal(address(wallet), 1 ether);
        vm.prank(owner1);
        vm.expectRevert("insufficient balance");
        wallet.submit(address(5), 100 ether, "");
    }

    function test_RevertWhen_DoubleApproval() public {
        vm.startPrank(owner1);
        wallet.submit(address(5), 1 ether, "");
        wallet.approve(0);
        vm.expectRevert("tx already approved");
        wallet.approve(0);
        vm.stopPrank();
    }

    function test_RevertWhen_ApprovingNonExistentTransaction() public {
        vm.prank(owner1);
        vm.expectRevert("tx does not exist");
        wallet.approve(999);
    }

    function test_RevertWhen_ExecutingAlreadyExecutedTx() public {
        address to = address(5);
        uint256 value = 1 ether;
        bytes memory data = "";

        // Submit and approve transaction
        vm.prank(owner1);
        wallet.submit(to, value, data);

        vm.prank(owner1);
        wallet.approve(0);
        vm.prank(owner2);
        wallet.approve(0);

        // Execute transaction
        vm.prank(owner1);
        wallet.execute(0);

        // Try to execute again
        vm.prank(owner1);
        vm.expectRevert("tx already executed");
        wallet.execute(0);

        // Verify final state
        (, , , bool executed, ) = wallet.getTransaction(0);
        assertTrue(executed, "Transaction should be marked as executed");
    }

// ----------------------------------------------------------------

    /// @notice Tests direct ETH deposits to the wallet
    /// @dev Verifies Deposit event emission
    function testReceiveEther() public {
        vm.expectEmit(true, false, false, true);
        emit Deposit(address(this), 1 ether);
        payable(address(wallet)).transfer(1 ether);
    }

    /// @notice Tests the pending transactions tracking
    /// @dev Verifies correct tracking of unexecuted transactions
    function testPendingTransactions() public {
        // Submit multiple transactions
        vm.startPrank(owner1);
        wallet.submit(address(5), 1 ether, "");
        wallet.submit(address(6), 2 ether, "");
        wallet.submit(address(7), 3 ether, "");
        vm.stopPrank();

        // Execute one transaction
        vm.prank(owner1);
        wallet.approve(0);
        vm.prank(owner2);
        wallet.approve(0);
        vm.prank(owner1);
        wallet.execute(0);

        // Check pending transactions
        uint256[] memory pending = wallet.getPendingTransactions();
        assertEq(pending.length, 2);
        assertEq(pending[0], 1);
        assertEq(pending[1], 2);
    }

    /// @notice Fallback function to receive ETH
    receive() external payable {}
}
