// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/// @title MultiSigHelper
/// @notice Helper library for encoding function calls for multi-signature wallets
/// @dev Provides utility functions to encode transaction submission and approval data
library MultiSigHelper {
    /// @notice Encodes the data needed to submit a transaction to a multi-sig wallet
    /// @param target The address that the multi-sig will call
    /// @param value The amount of ETH (in wei) to send with the call
    /// @param data The calldata to be executed by the target contract
    /// @return bytes The encoded function call data
    function encodeTransactionData(address target, uint256 value, bytes memory data)
        public
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(bytes4(keccak256("submit(address,uint256,bytes)")), target, value, data);
    }

    /// @notice Encodes the data needed to approve a pending transaction
    /// @param txId The ID of the transaction to approve
    /// @return bytes The encoded function call data
    function encodeApproval(uint256 txId) public pure returns (bytes memory) {
        return abi.encodeWithSelector(bytes4(keccak256("approve(uint256)")), txId);
    }
}
