# gleeth-cli

Ethereum CLI built on [gleeth](https://hex.pm/packages/gleeth). Query blocks, balances, transactions, gas prices, and logs. Sign and send transactions. Manage wallets. Decode calldata, revert reasons, and raw transactions. All from the command line.

[![Package Version](https://img.shields.io/hexpm/v/gleeth_cli)](https://hex.pm/packages/gleeth_cli)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleeth_cli/)

## Requirements

- Gleam >= 1.14.0
- Erlang/OTP >= 27
- Elixir (for NIF compilation)

## Installation

```sh
gleam add gleeth_cli
```

## Quick Start

Set `GLEETH_RPC_URL` to avoid passing `--rpc-url` with every command:

```sh
export GLEETH_RPC_URL=http://localhost:8545
```

Or pass it explicitly:

```sh
gleam run -- block-number --rpc-url http://localhost:8545
```

## Commands

### Blockchain Queries

```sh
# Get latest block number
gleam run -- block-number

# Get chain ID
gleam run -- chain-id

# Get current gas price and priority fee
gleam run -- gas-price

# Get fee history for the last 10 blocks with reward percentiles
gleam run -- fee-history --block-count 10 --percentiles 25,50,75
```

### Account Queries

```sh
# Check balance of an address
gleam run -- balance 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045

# Check multiple balances at once (queried in parallel)
gleam run -- balance 0xaddr1 0xaddr2 0xaddr3

# Check balances from a file (one address per line)
gleam run -- balance --file addresses.txt

# Get transaction count (nonce)
gleam run -- nonce 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045
```

### Contract Interaction

```sh
# Call a contract function
gleam run -- call 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 totalSupply

# Call with parameters
gleam run -- call 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 balanceOf \
  address:0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045

# Call with ABI file for typed decoding
gleam run -- call 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 balanceOf \
  address:0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045 --abi erc20.json

# Get contract bytecode
gleam run -- code 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48

# Estimate gas
gleam run -- estimate-gas \
  --from 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --to 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
  --value 0xde0b6b3a7640000

# Read contract storage
gleam run -- storage-at --address 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 --slot 0x0

# Query event logs
gleam run -- get-logs --address 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 \
  --from-block 0x1000000 --to-block latest
```

### Transactions

```sh
# Send ETH (EIP-1559)
gleam run -- send \
  --to 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
  --value 0xde0b6b3a7640000 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Send ETH (legacy transaction)
gleam run -- send \
  --to 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
  --value 0xde0b6b3a7640000 \
  --private-key 0x... --legacy

# Look up a transaction
gleam run -- transaction 0xabc123...

# Get a transaction receipt
gleam run -- receipt 0xabc123...

# Wait for a transaction to be mined (polls with exponential backoff)
gleam run -- wait 0xabc123... --timeout 120000
```

### Wallet Management

```sh
# Generate a new wallet
gleam run -- wallet generate

# Show wallet info from private key
gleam run -- wallet info --private-key 0x...

# Sign a message
gleam run -- wallet sign --private-key 0x... --message "hello"

# Verify a signature
gleam run -- wallet verify --public-key 0x04... --message "hello" --signature 0x...
```

### Offline Utilities

These commands run locally without an RPC connection:

```sh
# Compute EIP-55 checksummed address
gleam run -- checksum 0xd8da6bf26964af9d7eed9e03e53415d37aa96045

# Convert between units
gleam run -- convert 1 --from ether --to wei
gleam run -- convert 1000000000 --from gwei --to ether

# Compute function selector
gleam run -- selector "transfer(address,uint256)"

# Compute event topic
gleam run -- selector "Transfer(address,address,uint256)" --event

# Recover signer from signature
gleam run -- recover --mode address "hello" 0x...

# Decode a raw signed transaction
gleam run -- decode-tx 0x02f8...

# Decode contract calldata
gleam run -- decode-calldata 0xa9059cbb... --signature "transfer(address,uint256)"
gleam run -- decode-calldata 0xa9059cbb... --abi erc20.json

# Decode revert reason
gleam run -- decode-revert 0x08c379a0...
```

## Development

```sh
gleam build
gleam test
gleam format
gleam run -- --help
```

## License

MIT
