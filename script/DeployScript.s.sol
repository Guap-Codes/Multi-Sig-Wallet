// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {Script} from "forge-std/Script.sol";
import {MultiSigFactory} from "../src/factory/MultiSigFactory.sol";
import {MultiSigTimeLock} from "../src/core/MultiSigTimeLock.sol";

/// @title MultiSig Wallet Deployment Script
/// @notice Script to deploy MultiSig wallet factory and create initial wallets
/// @dev Uses Forge scripting system for deployments
contract DeployScript is Script {
    /// @notice Main deployment function
    /// @dev Deploys factory and creates example wallets
    /// @custom:security Make sure to replace placeholder addresses before mainnet deployment
    function run() external {
        // Get deployer's private key from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the MultiSig wallet factory
        // @dev This factory will be used to create new MultiSig wallets
        MultiSigFactory factory = new MultiSigFactory();

        // Set up example wallet configuration
        // @dev Replace these addresses with actual owner addresses before deployment
        address[] memory owners = new address[](3);
        owners[0] = address(0x1); // Owner 1
        owners[1] = address(0x2); // Owner 2
        owners[2] = address(0x3); // Owner 3

        // Create a new wallet through the factory
        // @dev Second parameter (2) is the number of required signatures
        factory.createWallet(owners, 2);

        // Deploy a standalone TimeLog wallet
        // @dev Uses same owners and signature requirement as example
        new MultiSigTimeLock(owners, 2);

        vm.stopBroadcast();
    }
}
