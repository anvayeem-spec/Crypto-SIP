.PHONY: help install update build test coverage anvil clean docs lint format

help:
	@echo "Crypto-SIP Development Commands"
	@echo "================================"
	@echo "make install     - Install Foundry dependencies"
	@echo "make update      - Update dependencies"
	@echo "make build       - Build the project"
	@echo "make test        - Run tests"
	@echo "make coverage    - Generate test coverage report"
	@echo "make anvil       - Start Anvil local network"
	@echo "make clean       - Clean build artifacts"
	@echo "make docs        - Generate contract documentation"
	@echo "make lint        - Lint Solidity code"
	@echo "make format      - Format Solidity code"

install:
	@echo "Installing Foundry dependencies..."
	forge install foundry-rs/forge-std
	forge install OpenZeppelin/openzeppelin-contracts

update:
	@echo "Updating dependencies..."
	forge update

build:
	@echo "Building project..."
	forge build

test:
	@echo "Running tests..."
	forge test -vv

coverage:
	@echo "Generating coverage report..."
	forge coverage

anvil:
	@echo "Starting Anvil on localhost:8545..."
	anvil --host 0.0.0.0 --port 8545 --block-time 1

clean:
	@echo "Cleaning build artifacts..."
	rm -rf out cache broadcast

docs:
	@echo "Note: Documentation generation requires external tools"
	@echo "Consider using forge doc or installing SolDoc"

lint:
	@echo "Linting Solidity code..."
	@echo "Note: Install solhint with: npm install -g solhint"

format:
	@echo "Formatting Solidity code..."
	@echo "Note: Use VS Code with Prettier + Solidity extension"
