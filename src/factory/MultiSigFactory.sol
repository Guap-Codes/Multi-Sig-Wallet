// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../interfaces/IMultiSigWallet.sol";
import "../core/MultiSigWallet.sol";

/// @title MultiSigFactory
/// @notice Factory contract for deploying new MultiSigWallet instances
/// @dev Creates and keeps track of all deployed MultiSigWallet contracts
contract MultiSigFactory {
    /// @notice Emitted when a new MultiSigWallet is created
    /// @param wallet Address of the newly created wallet
    /// @param owners Array of initial wallet owners
    /// @param required Number of required signatures for wallet operations
    event WalletCreated(address indexed wallet, address[] owners, uint256 required);

    /// @notice Mapping to check if an address is a deployed MultiSigWallet
    /// @dev Used to verify if an address was deployed by this factory
    mapping(address => bool) public isWallet;

    /// @notice Array containing addresses of all deployed wallets
    /// @dev Allows enumeration of all created wallets
    address[] public wallets;

    /// @notice Creates a new MultiSigWallet contract
    /// @param _owners Array of initial wallet owners
    /// @param _required Number of required signatures for wallet operations
    /// @return Address of the newly created MultiSigWallet
    function createWallet(address[] memory _owners, uint256 _required) external returns (address) {
        MultiSigWallet wallet = new MultiSigWallet(_owners, _required);
        isWallet[address(wallet)] = true;
        wallets.push(address(wallet));
        emit WalletCreated(address(wallet), _owners, _required);
        return address(wallet);
    }

    /// @notice Returns an array of all deployed wallet addresses
    /// @return Array containing addresses of all deployed MultiSigWallet contracts
    function getWallets() external view returns (address[] memory) {
        return wallets;
    }
}
