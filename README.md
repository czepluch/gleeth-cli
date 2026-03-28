# gleeth-cli

CLI tool for Ethereum built on [gleeth](https://hex.pm/packages/gleeth).

## Installation

```sh
gleam add gleeth_cli
```

## Usage

Set `GLEETH_RPC_URL` or pass `--rpc-url` with each command.

```sh
# Query block number
gleam run -- block-number --rpc-url http://localhost:8545

# Check balance
gleam run -- balance 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045

# Send ETH
gleam run -- send --to 0x... --value 0xde0b6b3a7640000 --private-key 0x...

# Call a contract
gleam run -- call 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 "balanceOf(address)" --params address:0x...

# Wallet management
gleam run -- wallet create
gleam run -- wallet show --private-key 0x...
gleam run -- wallet sign --private-key 0x... --message "hello"
```

## Commands

- `block-number` - get latest block number
- `balance` - get ETH balance for one or more addresses
- `call` - call a contract function (with optional `--abi` file)
- `tx` - look up transaction details
- `code` - get contract bytecode
- `estimate-gas` - estimate gas for a transaction
- `storage-at` - read contract storage
- `get-logs` - query event logs
- `send` - sign and broadcast a transaction
- `wallet` - create, inspect, and sign with wallets
- `recover` - recover signer from a signature

## Requirements

- Gleam >= 1.14.0
- Erlang/OTP >= 27
- Elixir (for NIF compilation)

## Development

```sh
gleam build
gleam run -- --help
gleam format
```
