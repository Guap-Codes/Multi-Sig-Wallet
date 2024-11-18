// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./MultiSigWallet.sol";

/// @title MultiSigTimeLock
/// @notice Extension of MultiSigWallet that adds a timelock period before execution
/// @dev Inherits from MultiSigWallet and adds a mandatory waiting period after approval
contract MultiSigTimeLock is MultiSigWallet {
    /// @notice Duration that must pass after approval before a transaction can be executed
    /// @dev Set to 24 hours
    uint256 public constant TIMELOCK_DURATION = 24 hours;

    /// @notice Mapping from transaction ID to timestamp when it can be executed
    /// @dev A value of 0 means the transaction hasn't been approved yet
    mapping(uint256 => uint256) public transactionTimeLocks;

    /// @notice Creates a new MultiSigTimeLock wallet
    /// @param _owners Array of owner addresses
    /// @param _required Number of required confirmations for a transaction
    constructor(address[] memory _owners, uint256 _required) MultiSigWallet(_owners, _required) {}

    /// @notice Executes a transaction if the timelock period has passed
    /// @dev Overrides the execute function from MultiSigWallet
    /// @param _txId Transaction ID to execute
    function execute(uint256 _txId) public override {
        require(
            transactionTimeLocks[_txId] != 0 && block.timestamp >= transactionTimeLocks[_txId], "timelock not expired"
        );
        super.execute(_txId);
    }

    /// @notice Approves a transaction and starts the timelock period if not already started
    /// @dev Overrides the approve function from MultiSigWallet
    /// @param _txId Transaction ID to approve
    function approve(uint256 _txId) public override {
        super.approve(_txId);
        if (transactionTimeLocks[_txId] == 0) {
            transactionTimeLocks[_txId] = block.timestamp + TIMELOCK_DURATION;
        }
    }
}
