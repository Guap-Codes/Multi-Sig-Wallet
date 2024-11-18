// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../interfaces/IMultiSigWallet.sol";

/// @title Multi-Signature Wallet
/// @author [Your Name]
/// @notice A wallet that requires multiple signatures to execute transactions
/// @dev Implements a multi-signature wallet with owner management capabilities
contract MultiSigWallet is IMultiSigWallet {
    /// @notice Emitted when ETH is deposited into the wallet
    /// @param sender The address that sent the ETH
    /// @param amount The amount of ETH deposited
    event Deposit(address indexed sender, uint256 amount);

    /// @notice Emitted when a new transaction is submitted for approval
    /// @param txId The ID of the submitted transaction
    event Submit(uint256 indexed txId);

    /// @notice Emitted when an owner approves a transaction
    /// @param owner The address of the owner who approved
    /// @param txId The ID of the approved transaction
    event Approve(address indexed owner, uint256 indexed txId);

    /// @notice Emitted when an owner revokes an approval for a transaction
    /// @param owner The address of the owner who revoked approval
    /// @param txId The ID of the transaction
    event Revoke(address indexed owner, uint256 indexed txId);

    /// @notice Emitted when a transaction is executed
    /// @param txId The ID of the executed transaction
    event Execute(uint256 indexed txId);

    /// @notice Emitted when the number of required confirmations changes
    /// @param required The new number of required confirmations
    event RequirementChanged(uint256 required);

    /// @notice Emitted when a new owner is added
    /// @param owner The address of the new owner
    event OwnerAdded(address indexed owner);

    /// @notice Emitted when an owner is removed
    /// @param owner The address of the removed owner
    event OwnerRemoved(address indexed owner);

    /// @notice Emitted when a transaction is cancelled
    /// @param txId The ID of the cancelled transaction
    event TransactionCancelled(uint256 indexed txId);

    /// @notice Emitted when an owner change proposal is submitted
    /// @param changeId The ID of the submitted owner change proposal
    event OwnerChangeSubmitted(uint256 indexed changeId);

    /// @notice Emitted when a transaction fails
    /// @param txId The ID of the failed transaction
    /// @param reason The reason for the failure
    event TransactionFailed(uint256 indexed txId, string reason);

    /// @notice Represents a transaction that can be executed by the wallet
    /// @dev Stores all necessary information for a transaction
    struct Transaction {
        address to;
        /// @param to Destination address for the transaction
        uint256 value;
        /// @param value Amount of ETH to send
        bytes data;
        /// @param data Calldata for the transaction
        bool executed;
    }
    /// @param executed Whether the transaction has been executed

    /// @notice List of wallet owners
    /// @dev The order of owners is maintained from when they were added
    address[] public owners;

    /// @notice Mapping to quickly check if an address is an owner
    /// @dev True if address is an owner, false otherwise
    mapping(address => bool) public isOwner;

    /// @notice Number of required confirmations for a transaction
    /// @dev Must be less than or equal to the number of owners
    uint256 public required;

    /// @notice Array of all transactions submitted to the wallet
    /// @dev Includes both pending and executed transactions
    Transaction[] public transactions;

    /// @notice Tracks transaction approvals by owner
    /// @dev Mapping from transaction ID => owner address => approval status
    mapping(uint256 => mapping(address => bool)) public approved;

    /// @notice Structure for tracking owner addition/removal proposals
    /// @dev Used to manage changes to the owner set
    struct OwnerChange {
        address owner;
        /// @dev Address of the owner to add/remove
        bool isAdd;
        /// @dev True for addition, false for removal
        bool executed;
    }
    /// @dev Whether the change has been executed

    /// @notice Array of all owner change proposals
    /// @dev Includes both pending and executed changes
    OwnerChange[] public ownerChanges;

    /// @notice Tracks owner change approvals
    /// @dev Mapping from change ID => owner address => approval status
    mapping(uint256 => mapping(address => bool)) public ownerChangeApprovals;

    /// @notice Reentrancy guard
    /// @dev Prevents recursive calls to protected functions
    bool private locked;

    /// @notice Maximum number of owners allowed
    /// @dev Prevents gas issues with too many owners
    uint256 public constant MAX_OWNERS = 50;

    /// @notice Restricts function access to wallet owners
    /// @dev Reverts if caller is not in the owners list
    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    /// @notice Ensures a transaction ID is valid
    /// @param _txId The transaction ID to check
    /// @dev Reverts if the transaction ID is out of bounds
    modifier txExists(uint256 _txId) {
        require(_txId < transactions.length, "tx does not exist");
        _;
    }

    /// @notice Ensures transaction hasn't been approved by the caller
    /// @param _txId The transaction ID to check
    /// @dev Prevents double-approval by the same owner
    modifier notApproved(uint256 _txId) {
        require(!approved[_txId][msg.sender], "tx already approved");
        _;
    }

    /// @notice Ensures transaction hasn't been executed
    /// @param _txId The transaction ID to check
    /// @dev Prevents actions on already executed transactions
    modifier notExecuted(uint256 _txId) {
        require(!transactions[_txId].executed, "tx already executed");
        _;
    }

    /// @notice Prevents reentrancy attacks
    /// @dev Uses a boolean lock to prevent recursive calls
    modifier nonReentrant() {
        require(!locked, "reentrant call");
        locked = true;
        _;
        locked = false;
    }

    /// @notice Restricts function access to the wallet contract itself
    /// @dev Used for functions that should only be called internally
    modifier onlyWallet() {
        require(address(this) == msg.sender, "only wallet");
        _;
    }

    /// @notice Creates a new multi-signature wallet
    /// @param _owners Array of initial owner addresses
    /// @param _required Number of required signatures
    /// @dev Initializes the wallet with a set of owners and required confirmations
    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "owners required");
        require(_owners.length <= MAX_OWNERS, "too many owners");
        require(_required > 0 && _required <= _owners.length, "invalid required number of owners");

        for (uint256 i; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner is not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    /// @notice Allows the contract to receive ETH
    /// @dev Emits a Deposit event when ETH is received
    receive() external payable {
        require(msg.value > 0, "zero value not allowed");
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Submits a new transaction for approval
    /// @param _to Destination address
    /// @param _value Amount of ETH to send
    /// @param _data Transaction data payload
    /// @dev Creates a new transaction and emits Submit event
    function submit(address _to, uint256 _value, bytes calldata _data) external onlyOwner {
        require(_to != address(0), "invalid target address");
        require(_value <= address(this).balance, "insufficient balance");

        transactions.push(Transaction({to: _to, value: _value, data: _data, executed: false}));
        emit Submit(transactions.length - 1);
    }

    /// @notice Approves a pending transaction
    /// @param _txId Transaction ID to approve
    /// @dev Marks caller's approval for the transaction
    function approve(uint256 _txId) public virtual onlyOwner txExists(_txId) notApproved(_txId) notExecuted(_txId) {
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    /// @notice Counts the number of approvals for a specific transaction
    /// @param _txId The ID of the transaction to check
    /// @return count The number of owners who have approved the transaction
    /// @dev Iterates through all owners to count valid approvals
    function _getApprovalCount(uint256 _txId) private view returns (uint256 count) {
        for (uint256 i; i < owners.length; i++) {
            if (approved[_txId][owners[i]]) {
                count += 1;
            }
        }
    }

    /// @notice Executes a transaction if it has enough approvals
    /// @param _txId Transaction ID to execute
    /// @dev Requires sufficient approvals and handles execution failure
    function execute(uint256 _txId) public virtual txExists(_txId) notExecuted(_txId) nonReentrant {
        require(_getApprovalCount(_txId) >= required, "approvals < required");
        Transaction storage transaction = transactions[_txId];

        require(transaction.value <= address(this).balance, "insufficient balance");

        transaction.executed = true;

        (bool success, bytes memory result) =
            transaction.to.call{value: transaction.value, gas: gasleft() - 2000}(transaction.data);

        if (!success) {
            string memory reason = result.length > 0 ? _getRevertMsg(result) : "transaction reverted";
            emit TransactionFailed(_txId, reason);
            revert(reason);
        }

        emit Execute(_txId);
    }

    /// @notice Revokes a previously given approval
    /// @param _txId Transaction ID to revoke approval from
    /// @dev Removes caller's approval for the transaction
    function revoke(uint256 _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        require(approved[_txId][msg.sender], "tx not approved");
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }

    /// @notice Returns the total number of transactions ever created
    /// @return The total count of transactions (both pending and executed)
    /// @dev This includes both executed and non-executed transactions
    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    /// @notice Returns the list of current wallet owners
    /// @return Array of owner addresses
    /// @dev The order of owners in the array is maintained from when they were added
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    /// @notice Gets the details of a specific transaction
    /// @param _txId The ID of the transaction to query
    /// @return to The destination address of the transaction
    /// @return value The amount of ETH to be sent in the transaction
    /// @return data The calldata to be executed
    /// @return executed Whether the transaction has been executed
    /// @return approvalCount The current number of approvals for this transaction
    /// @dev Combines transaction details with current approval count
    function getTransaction(uint256 _txId)
        external
        view
        returns (address to, uint256 value, bytes memory data, bool executed, uint256 approvalCount)
    {
        Transaction storage transaction = transactions[_txId];
        return (transaction.to, transaction.value, transaction.data, transaction.executed, _getApprovalCount(_txId));
    }

    /// @notice Changes the number of required approvals
    /// @param _required New number of required approvals
    /// @dev Updates the required number of signatures for transactions
    function changeRequirement(uint256 _required) external onlyOwner {
        require(_required > 0 && _required <= owners.length, "invalid required number");
        required = _required;
        emit RequirementChanged(_required);
    }

    /// @notice Proposes adding a new owner
    /// @param _owner Address of the proposed new owner
    /// @dev Creates an owner change proposal that needs to be approved
    function proposeAddOwner(address _owner) external onlyOwner {
        require(_owner != address(0), "invalid owner");
        require(!isOwner[_owner], "owner exists");
        require(owners.length < MAX_OWNERS, "max owners reached");

        ownerChanges.push(OwnerChange({owner: _owner, isAdd: true, executed: false}));
        emit OwnerChangeSubmitted(ownerChanges.length - 1);
    }

    /// @notice Approves a proposed owner change
    /// @param _changeId The ID of the owner change proposal to approve
    /// @dev Marks the caller's approval for the owner change proposal
    /// @dev Can only be called by existing owners
    /// @dev Emits an Approve event when successful
    function approveOwnerChange(uint256 _changeId) external onlyOwner {
        require(_changeId < ownerChanges.length, "change does not exist");
        require(!ownerChanges[_changeId].executed, "already executed");
        require(!ownerChangeApprovals[_changeId][msg.sender], "already approved");

        ownerChangeApprovals[_changeId][msg.sender] = true;
        emit Approve(msg.sender, _changeId); // Reuse existing event
    }

    /// @notice Executes a proposed owner change after sufficient approvals
    /// @param _changeId The ID of the owner change proposal to execute
    /// @dev Requires the minimum number of approvals before execution
    /// @dev For additions: adds new owner to mapping and array
    /// @dev For removals: removes owner from mapping and array
    /// @dev Emits either OwnerAdded or OwnerRemoved event when successful
    /// @dev Protected against reentrancy attacks
    function executeOwnerChange(uint256 _changeId) external onlyOwner nonReentrant {
        require(_changeId < ownerChanges.length, "change does not exist");
        require(!ownerChanges[_changeId].executed, "already executed");

        uint256 approvalCount;
        for (uint256 i; i < owners.length; i++) {
            if (ownerChangeApprovals[_changeId][owners[i]]) {
                approvalCount++;
            }
        }

        require(approvalCount >= required, "not enough approvals");

        OwnerChange storage change = ownerChanges[_changeId];
        change.executed = true;

        if (change.isAdd) {
            isOwner[change.owner] = true;
            owners.push(change.owner);
            emit OwnerAdded(change.owner);
        } else {
            isOwner[change.owner] = false;
            // Remove owner from array
            for (uint256 i = 0; i < owners.length; i++) {
                if (owners[i] == change.owner) {
                    owners[i] = owners[owners.length - 1];
                    owners.pop();
                    break;
                }
            }
            emit OwnerRemoved(change.owner);
        }
    }

    /// @notice Cancels a pending transaction that has sufficient approvals
    /// @param _txId The ID of the transaction to cancel
    /// @dev Marks the transaction as executed without actually executing it
    /// @dev Requires the caller to be an owner and the transaction to exist and not be executed
    /// @dev Requires the same number of approvals as executing a transaction
    function cancelTransaction(uint256 _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        require(_getApprovalCount(_txId) >= required, "not enough approvals to cancel");
        transactions[_txId].executed = true;
        emit TransactionCancelled(_txId);
    }

    /// @notice Proposes removing an existing owner
    /// @param _owner Address of the owner to remove
    /// @dev Creates an owner removal proposal that needs to be approved
    function proposeRemoveOwner(address _owner) external onlyOwner {
        require(_owner != address(0), "invalid owner");
        require(isOwner[_owner], "not an owner");
        require(owners.length - 1 >= required, "cannot have less owners than required");

        ownerChanges.push(OwnerChange({owner: _owner, isAdd: false, executed: false}));

        emit Submit(ownerChanges.length - 1);
    }

    /// @notice Gets details about a specific owner change proposal
    /// @param _changeId The ID of the owner change proposal to query
    /// @return owner The address of the owner being added or removed
    /// @return isAdd True if the proposal is to add an owner, false if removing
    /// @return executed Whether the owner change has been executed
    /// @return approvalCount The number of current approvals for this change
    /// @dev Returns all relevant information about an owner change proposal including its current approval count
    function getOwnerChange(uint256 _changeId)
        external
        view
        returns (address owner, bool isAdd, bool executed, uint256 approvalCount)
    {
        require(_changeId < ownerChanges.length, "change does not exist");
        OwnerChange storage change = ownerChanges[_changeId];

        uint256 count;
        for (uint256 i; i < owners.length; i++) {
            if (ownerChangeApprovals[_changeId][owners[i]]) {
                count++;
            }
        }

        return (change.owner, change.isAdd, change.executed, count);
    }

    /// @notice Gets all pending owner changes
    /// @return Array of pending owner change IDs
    /// @dev Returns IDs of owner changes that haven't been executed
    function getPendingOwnerChanges() external view returns (uint256[] memory) {
        uint256 count;
        for (uint256 i; i < ownerChanges.length; i++) {
            if (!ownerChanges[i].executed) {
                count++;
            }
        }

        uint256[] memory pending = new uint256[](count);
        uint256 index;
        for (uint256 i; i < ownerChanges.length; i++) {
            if (!ownerChanges[i].executed) {
                pending[index] = i;
                index++;
            }
        }
        return pending;
    }

    /// @notice Internal function to decode revert messages
    /// @param _returnData Raw return data from failed call
    /// @return Decoded revert message string
    /// @dev Handles both silent reverts and revert with message
    function _getRevertMsg(bytes memory _returnData) private pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    /// @notice Gets all pending transactions
    /// @return Array of pending transaction IDs
    /// @dev Returns IDs of transactions that haven't been executed
    function getPendingTransactions() external view returns (uint256[] memory) {
        uint256 count;
        for (uint256 i; i < transactions.length; i++) {
            if (!transactions[i].executed) {
                count++;
            }
        }

        uint256[] memory pending = new uint256[](count);
        uint256 index;
        for (uint256 i; i < transactions.length; i++) {
            if (!transactions[i].executed) {
                pending[index] = i;
                index++;
            }
        }
        return pending;
    }
}
