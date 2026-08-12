# Foundry Setup Guide for Crypto-SIP

This guide covers the installation and configuration of Foundry for the Crypto-SIP project.

## Prerequisites

- **Rust** (required for Foundry): https://rustup.rs/
- **Git**: For cloning and managing dependencies

## Installation

### 1. Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Verify installation:
```bash
forge --version
anvil --version
cast --version
```

### 2. Install Project Dependencies

Navigate to the project directory and run:

```bash
make install
```

Or manually:
```bash
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts
```

## Project Structure

```
Crypto-SIP/
├── src/                 # Solidity contracts
├── test/                # Test files
├── script/              # Deployment scripts
├── lib/                 # Dependencies (forge-std, OpenZeppelin)
├── foundry.toml         # Foundry configuration
├── Makefile             # Development commands
└── README.md            # Project documentation
```

## Common Commands

### Building

```bash
# Build contracts
forge build

# Build with optimizer
forge build --optimize --optimizer-runs 200
```

### Testing

```bash
# Run all tests
forge test

# Run tests with verbose output
forge test -vv

# Run specific test
forge test --match testIncrement

# Run with gas reporting
forge test --gas-report

# Generate coverage report
forge coverage
```

### Local Network (Anvil)

```bash
# Start local network on localhost:8545
anvil

# Or use make command
make anvil

# Run tests against Anvil
forge test --fork-url http://localhost:8545
```

### Deployment

```bash
# Deploy to local network
forge script script/Counter.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Contract Interaction (Cast)

```bash
# Get account balance
cast balance 0x742d35Cc6634C0532925a3b844Bc0e7595f42b0C

# Call a contract function
cast call 0x... "functionName()" --rpc-url http://localhost:8545

# Send a transaction
cast send 0x... "functionName()" --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY
```

### Utilities

```bash
# Generate documentation
forge doc

# Check code size
forge inspect Contract size

# Clean build artifacts
make clean

# Update all dependencies
make update
```

## Useful Resources

- **Foundry Book**: https://book.getfoundry.sh/
- **Forge Docs**: https://github.com/foundry-rs/foundry/tree/master/crates/forge
- **Anvil Docs**: https://github.com/foundry-rs/foundry/tree/master/crates/anvil
- **OpenZeppelin Contracts**: https://docs.openzeppelin.com/contracts/
- **Solidity Docs**: https://docs.soliditylang.org/

## Troubleshooting

### Issue: `forge: command not found`
**Solution**: Ensure Foundry is installed and in your PATH. Run `foundryup` again.

### Issue: `error: Failed to install lib/forge-std`
**Solution**: Ensure Git is installed and you have internet connectivity. Check SSH keys if using SSH.

### Issue: Tests not finding libraries
**Solution**: Run `forge build` first to ensure all dependencies are compiled.

### Issue: Anvil not connecting
**Solution**: Ensure Anvil is running on the correct port (default 8545) and your RPC URL matches.

## IDE Setup

### VS Code
1. Install extensions:
   - **Solidity** (by Juan Blanco)
   - **Prettier - Code formatter** (by Prettier)
   - **Prettier - Solidity** (by Byron Wasti)

2. Add to `.vscode/settings.json`:
```json
{
  "[solidity]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  }
}
```

## Next Steps

1. Review the [Foundry Book](https://book.getfoundry.sh/) for in-depth documentation
2. Replace `Counter.sol` with your actual Crypto-SIP contract
3. Write comprehensive tests in the `test/` directory
4. Create deployment scripts in the `script/` directory

## Support

For issues or questions:
- Check the [Foundry GitHub Issues](https://github.com/foundry-rs/foundry/issues)
- Visit [Foundry Discord](https://discord.gg/foundry-rs)
