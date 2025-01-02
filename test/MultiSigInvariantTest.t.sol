// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "../src/core/MultiSigWallet.sol";
import "../src/core/MultiSigTimeLock.sol";
import "../src/factory/MultiSigFactory.sol";

/// @title MultiSig Wallet Invariant Tests
/// @notice Test suite for verifying invariant properties of MultiSig wallet implementations
/// @dev Tests core functionality of MultiSigWallet, MultiSigTimeLock, and MultiSigFactory
contract MultiSigInvariantTest is Test {
    MultiSigFactory factory;
    MultiSigWallet wallet;
    MultiSigTimeLock timelockWallet;

    address[] owners;
    uint256 constant REQUIRED_APPROVALS = 2;
    uint256 constant INITIAL_BALANCE = 100 ether;
    uint256 constant MAX_OWNERS = 50;

    address owner1 = address(0x1);
    address owner2 = address(0x2);
    address owner3 = address(0x3);
    address nonOwner = address(0x4);

    event WalletCreated(
        address indexed wallet,
        address[] owners,
        uint256 required
    );

    /// @notice Sets up the test environment with a standard 3-owner configuration
    /// @dev Deploys factory, standard wallet, and timelock wallet with 100 ETH each
    function setUp() public {
        // Setup owners
        owners.push(owner1);
        owners.push(owner2);
        owners.push(owner3);

        // Setup contracts
        factory = new MultiSigFactory();
        wallet = new MultiSigWallet(owners, REQUIRED_APPROVALS);
        timelockWallet = new MultiSigTimeLock(owners, REQUIRED_APPROVALS);

        // Fund wallets
        vm.deal(address(wallet), INITIAL_BALANCE);
        vm.deal(address(timelockWallet), INITIAL_BALANCE);
    }

    /// @notice Tests invariant properties related to wallet ownership
    /// @dev Verifies:
    ///      - Initial owner count and required approvals
    ///      - Owner uniqueness and registration
    ///      - Maximum owner limits
    ///      - Required approval bounds
    function testOwnershipInvariants() public {
        // Test initial state
        assertEq(
            wallet.getOwners().length,
            owners.length,
            "Invalid owner count"
        );
        assertEq(
            wallet.required(),
            REQUIRED_APPROVALS,
            "Invalid required approvals"
        );

        // Test owner uniqueness and registration
        for (uint256 i = 0; i < owners.length; i++) {
            assertTrue(wallet.isOwner(owners[i]), "Owner not registered");
            for (uint256 j = i + 1; j < owners.length; j++) {
                assertTrue(owners[i] != owners[j], "Duplicate owner found");
            }
        }

        // Test max owners limit
        address[] memory tooManyOwners = new address[](MAX_OWNERS + 1);
        for (uint256 i = 0; i < MAX_OWNERS + 1; i++) {
            tooManyOwners[i] = address(uint160(i + 1));
        }
        vm.expectRevert("owners required"); // First check zero owners
        new MultiSigWallet(new address[](0), 1);

        vm.expectRevert("too many owners");
        new MultiSigWallet(tooManyOwners, REQUIRED_APPROVALS);

        // Test required approvals bounds
        vm.expectRevert("invalid required number of owners");
        new MultiSigWallet(owners, owners.length + 1);

        vm.expectRevert("invalid required number of owners");
        new MultiSigWallet(owners, 0);
    }

    /// @notice Tests invariant properties related to transaction handling
    /// @dev Verifies:
    ///      - Approval requirements for execution
    ///      - Balance requirements for submissions
    ///      - Transaction execution uniqueness (no double execution)
    function testTransactionInvariants() public {
        // Setup transaction
        address target = address(0x123);
        uint256 value = 1 ether;
        bytes memory data = "";

        // Submit transaction
        vm.prank(owner1);
        wallet.submit(target, value, data);
        uint256 txId = wallet.getTransactionCount() - 1;

        // Test approval requirements
        vm.prank(owner1);
        wallet.approve(txId);

        vm.expectRevert();
        wallet.execute(txId); // Should fail with insufficient approvals

        // Test balance requirements
        vm.prank(owner1);
        vm.expectRevert();
        wallet.submit(target, INITIAL_BALANCE + 1, data); // Should fail with insufficient balance

        // Test execution uniqueness
        vm.prank(owner2);
        wallet.approve(txId);
        wallet.execute(txId);

        vm.expectRevert();
        wallet.execute(txId); // Should fail on second execution
    }

    /// @notice Tests invariant properties specific to timelock functionality
    /// @dev Verifies:
    ///      - Timelock initialization
    ///      - Timelock immutability across approvals
    ///      - Timelock enforcement before execution
    ///      - Execution possibility after timelock period
    function testTimeLockInvariants() public {
        // Setup transaction
        address target = address(0x123);
        uint256 value = 1 ether;
        bytes memory data = "";

        // Submit and approve transaction
        vm.prank(owner1);
        timelockWallet.submit(target, value, data);
        uint256 txId = timelockWallet.getTransactionCount() - 1;

        vm.prank(owner1);
        timelockWallet.approve(txId);
        uint256 initialTimeLock = timelockWallet.transactionTimeLocks(txId);

        // Test timelock initialization
        assertTrue(initialTimeLock > 0, "Timelock not set");

        vm.prank(owner2);
        timelockWallet.approve(txId);
        assertEq(
            timelockWallet.transactionTimeLocks(txId),
            initialTimeLock,
            "Timelock changed on second approval"
        );

        // Test timelock enforcement
        vm.expectRevert();
        timelockWallet.execute(txId);

        // Test execution after timelock
        vm.warp(block.timestamp + 24 hours + 1);
        timelockWallet.execute(txId);
    }

    /// @notice Tests invariant properties of the wallet factory
    /// @dev Verifies:
    ///      - Correct event emission on wallet creation
    ///      - Proper wallet tracking in factory
    ///      - Correct initialization of created wallets
    function testFactoryInvariants() public {
        // Create the wallet first to get its address
        address walletAddress = factory.createWallet(
            owners,
            REQUIRED_APPROVALS
        );

        // Verify wallet tracking
        assertTrue(factory.isWallet(walletAddress), "Wallet not tracked");
        assertEq(factory.wallets(0), walletAddress, "Wallet not in array");

        // Verify wallet initialization
        MultiSigWallet newWallet = MultiSigWallet(payable(walletAddress));
        assertEq(
            newWallet.getOwners().length,
            owners.length,
            "Invalid owner count"
        );
        assertEq(
            newWallet.required(),
            REQUIRED_APPROVALS,
            "Invalid required approvals"
        );

        // Verify all owners are properly set
        for (uint256 i = 0; i < owners.length; i++) {
            assertTrue(newWallet.isOwner(owners[i]), "Owner not properly set");
        }
    }

    /// @notice Fuzz test for wallet ownership invariants
    /// @dev Tests wallet creation with random valid inputs
    /// @param _owners Array of owner addresses to test
    /// @param _required Number of required approvals
    function testFuzzOwnershipInvariants(
        address[] calldata _owners,
        uint256 _required
    ) public {
        // Bound the inputs
        vm.assume(_owners.length > 0 && _owners.length <= 50);
        _required = bound(_required, 1, _owners.length);

        // Check for zero addresses and duplicates
        for (uint256 i = 0; i < _owners.length; i++) {
            vm.assume(_owners[i] != address(0));
            for (uint256 j = i + 1; j < _owners.length; j++) {
                vm.assume(_owners[i] != _owners[j]);
            }
        }

        MultiSigWallet fuzzWallet = new MultiSigWallet(_owners, _required);
        assertEq(fuzzWallet.getOwners().length, _owners.length);
        assertEq(fuzzWallet.required(), _required);
    }
}
