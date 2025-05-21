# MultiSig Wallet

A secure, flexible multi-signature wallet implementation built with Solidity and Foundry. Features include timelock functionality, owner management, and factory deployment.

## Features

- **Basic MultiSig Functionality**: Requires multiple approvals for transaction execution
- **Timelock Support**: Optional time delay between approval and execution
- **Owner Management**: Add/remove owners with multi-sig approval
- **Factory Pattern**: Easy deployment of new wallet instances
- **Gas Optimized**: Implements gas-efficient patterns and reentrancy protection
- **Comprehensive Testing**: Includes unit tests and invariant tests

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/downloads)

## Installation

1. Clone the repository:

```bash
git clone https://github.com/Guap-Codes/Multi-Sig-Wallet.git
cd Multi-Sig-Wallet
```


2. Install dependencies:

```
forge install
```


3. Copy the environment file and configure your variables:

```
cp .env.example .env
```


## Usage

### Compilation

```forge build```


### Testing

Run all tests:

```forge test```

Run specific test file:

```forge test --match-path test/MultiSigTest.t.sol```

Run with verbosity:

```forge test -vvv```


### Deployment

1. Configure your `.env` file with appropriate RPC URLs and private key.

2. Deploy to testnet (e.g., Sepolia):

```forge script script/DeployScript.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify```


### Contract Interaction

Use the provided interaction scripts:

Submit a transaction:

```forge script script/InteractionsScript.s.sol:InteractionsScript --sig "submitTransaction(address,address,uint256,bytes)" [WALLET_ADDRESS] [TARGET] [VALUE] [DATA]```

Approve a transaction:

```forge script script/InteractionsScript.s.sol:InteractionsScript --sig "approveTransaction(address,uint256)" [WALLET_ADDRESS] [TX_ID]```

Execute a transaction:

```forge script script/InteractionsScript.s.sol:InteractionsScript --sig "executeTransaction(address,uint256)" [WALLET_ADDRESS] [TX_ID]```


## Contract Architecture

- MultiSigWallet.sol: Base implementation of multi-signature functionality
- MultiSigTimeLock.sol: Extends base wallet with timelock features
- MultiSigFactory.sol: Factory contract for deploying new wallet instances
- MultiSigHelper.sol: Utility library for transaction encoding
- IMultiSigWallet.sol: Interface defining core functionality

## Testing

The project includes:
- Unit tests (MultiSigTest.t.sol)
- Invariant tests (MultiSigInvariantTest.t.sol)
- Helper libraries for testing

## Security Considerations

- Implements reentrancy protection
- Gas-limited external calls
- Owner management restrictions
- Timelock functionality for enhanced security
- Comprehensive testing suite

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE]|(LICENSE) file for details.


