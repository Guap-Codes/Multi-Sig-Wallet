// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {Script} from "forge-std/Script.sol";
import {MultiSigWallet} from "../src/core/MultiSigWallet.sol";
import {MultiSigHelper} from "../src/lib/MultiSigHelper.sol";

/// @title MultiSig Wallet Interaction Script
/// @notice Provides functions to interact with a deployed MultiSigWallet contract
/// @dev Uses Forge scripting to execute transactions on-chain
contract InteractionsScript is Script {
    /// @notice Submits a new transaction to the MultiSig wallet
    /// @param wallet Address of the deployed MultiSig wallet
    /// @param target Address that the MultiSig wallet will interact with
    /// @param value Amount of ETH to send with the transaction
    /// @param data Calldata to be executed by the target contract
    function submitTransaction(address wallet, address target, uint256 value, bytes memory data) public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        MultiSigWallet(payable(wallet)).submit(target, value, data);

        vm.stopBroadcast();
    }

    /// @notice Approves a pending transaction in the MultiSig wallet
    /// @param wallet Address of the deployed MultiSig wallet
    /// @param txId ID of the transaction to approve
    function approveTransaction(address wallet, uint256 txId) public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        MultiSigWallet(payable(wallet)).approve(txId);

        vm.stopBroadcast();
    }

    /// @notice Executes an approved transaction from the MultiSig wallet
    /// @param wallet Address of the deployed MultiSig wallet
    /// @param txId ID of the transaction to execute
    /// @dev Transaction must have required number of approvals before execution
    function executeTransaction(address wallet, uint256 txId) public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        MultiSigWallet(payable(wallet)).execute(txId);

        vm.stopBroadcast();
    }
}
