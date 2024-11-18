// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/// @title Multi-Signature Wallet Interface
/// @notice Interface for a wallet that requires multiple signatures to execute transactions
interface IMultiSigWallet {
    /// @notice Submits a new transaction to the wallet for approval
    /// @param _to The destination address of the transaction
    /// @param _value The amount of ether to send
    /// @param _data The calldata to be executed
    function submit(address _to, uint256 _value, bytes calldata _data) external;

    /// @notice Approves a pending transaction
    /// @param _txId The ID of the transaction to approve
    function approve(uint256 _txId) external;

    /// @notice Executes a transaction that has received enough approvals
    /// @param _txId The ID of the transaction to execute
    function execute(uint256 _txId) external;

    /// @notice Revokes a previously given approval
    /// @param _txId The ID of the transaction to revoke approval from
    function revoke(uint256 _txId) external;

    /// @notice Gets the details of a specific transaction
    /// @param _txId The ID of the transaction to query
    /// @return to The destination address of the transaction
    /// @return value The amount of ether sent in the transaction
    /// @return data The transaction calldata
    /// @return executed Whether the transaction has been executed
    /// @return approvalCount The number of approvals received
    function getTransaction(uint256 _txId)
        external
        view
        returns (address to, uint256 value, bytes memory data, bool executed, uint256 approvalCount);

    /// @notice Returns the total number of transactions
    /// @return The count of all transactions
    function getTransactionCount() external view returns (uint256);

    /// @notice Returns the list of wallet owners
    /// @return Array of owner addresses
    function getOwners() external view returns (address[] memory);

    /// @notice Changes the number of required approvals
    /// @param _required The new number of required approvals
    function changeRequirement(uint256 _required) external;

    /// @notice Gets all pending transaction IDs
    /// @return Array of pending transaction IDs
    function getPendingTransactions() external view returns (uint256[] memory);

    /// @notice Gets all pending owner change transaction IDs
    /// @return Array of pending owner change transaction IDs
    function getPendingOwnerChanges() external view returns (uint256[] memory);
    // ... other view functions
}
