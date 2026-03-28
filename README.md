# gleeth-cli

Ethereum CLI built on [gleeth](https://hex.pm/packages/gleeth). Query blocks, balances, transactions, gas prices, and logs. Sign and send transactions. Manage wallets. Decode calldata, revert reasons, and raw transactions. All from the command line.

[![Package Version](https://img.shields.io/hexpm/v/gleeth_cli)](https://hex.pm/packages/gleeth_cli)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleeth_cli/)

## Installation

### Requirements

- Erlang/OTP >= 27
- Gleam >= 1.14.0
- Elixir (for NIF compilation)

If you use [mise](https://mise.jdx.dev), the included `.mise.toml` handles all three.

### Build from source

```sh
git clone https://github.com/czepluch/gleeth-cli.git
cd gleeth-cli
gleam export erlang-shipment
```

This produces `build/erlang-shipment/` with a self-contained BEAM release. Create an alias to use it as `gleeth`:

```sh
alias gleeth='/<path-to>/gleeth-cli/build/erlang-shipment/entrypoint.sh run'
```

Or during development, run directly with:

```sh
gleam run -- <command> [args]
```

## Quick Start

Set `GLEETH_RPC_URL` to avoid passing `--rpc-url` with every command:

```sh
export GLEETH_RPC_URL=http://localhost:8545
```

Or pass it explicitly:

```sh
gleeth block-number --rpc-url http://localhost:8545
```

## Commands

### Blockchain Queries

```sh
# Get latest block number
gleeth block-number

# Get chain ID
gleeth chain-id

# Get current gas price and priority fee
gleeth gas-price

# Get fee history for the last 10 blocks with reward percentiles
gleeth fee-history --block-count 10 --percentiles 25,50,75
```

### Account Queries

```sh
# Check balance of an address
gleeth balance 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045

# Check multiple balances at once (queried in parallel)
gleeth balance 0xaddr1 0xaddr2 0xaddr3

# Check balances from a file (one address per line)
gleeth balance --file addresses.txt

# Get transaction count (nonce)
gleeth nonce 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045
```

### Contract Interaction

```sh
# Call a contract function
gleeth call 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 totalSupply

# Call with parameters
gleeth call 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 balanceOf \
  address:0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045

# Call with ABI file for typed decoding
gleeth call 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 balanceOf \
  address:0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045 --abi erc20.json

# Get contract bytecode
gleeth code 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48

# Estimate gas
gleeth estimate-gas \
  --from 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --to 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
  --value 0xde0b6b3a7640000

# Read contract storage
gleeth storage-at --address 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 --slot 0x0

# Query event logs
gleeth get-logs --address 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 \
  --from-block 0x1000000 --to-block latest
```

### Transactions

```sh
# Send ETH (EIP-1559)
gleeth send \
  --to 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
  --value 0xde0b6b3a7640000 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Send ETH (legacy transaction)
gleeth send \
  --to 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
  --value 0xde0b6b3a7640000 \
  --private-key 0x... --legacy

# Look up a transaction
gleeth transaction 0xabc123...

# Get a transaction receipt
gleeth receipt 0xabc123...

# Wait for a transaction to be mined (polls with exponential backoff)
gleeth wait 0xabc123... --timeout 120000
```

### Wallet Management

```sh
# Generate a new wallet
gleeth wallet generate

# Show wallet info from private key
gleeth wallet info --private-key 0x...

# Sign a message
gleeth wallet sign --private-key 0x... --message "hello"

# Verify a signature
gleeth wallet verify --public-key 0x04... --message "hello" --signature 0x...
```

### Offline Utilities

These commands run locally without an RPC connection:

```sh
# Compute EIP-55 checksummed address
gleeth checksum 0xd8da6bf26964af9d7eed9e03e53415d37aa96045

# Convert between units
gleeth convert 1 --from ether --to wei
gleeth convert 1000000000 --from gwei --to ether

# Compute function selector
gleeth selector "transfer(address,uint256)"

# Compute event topic
gleeth selector "Transfer(address,address,uint256)" --event

# Recover signer from signature
gleeth recover --mode address "hello" 0x...

# Decode a raw signed transaction
gleeth decode-tx 0x02f8...

# Decode contract calldata
gleeth decode-calldata 0xa9059cbb... --signature "transfer(address,uint256)"
gleeth decode-calldata 0xa9059cbb... --abi erc20.json

# Decode revert reason
gleeth decode-revert 0x08c379a0...
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
