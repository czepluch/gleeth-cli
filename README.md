# gleeth-cli

Ethereum CLI built on [gleeth](https://hex.pm/packages/gleeth). Query blocks, balances, transactions, gas prices, and logs. Sign and send transactions. Manage wallets. Decode calldata, revert reasons, and raw transactions. All from the command line.

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

Or use a chain preset:

```sh
gleeth balance 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045 --chain mainnet
```

## Global Options

```
--rpc-url <URL>    RPC endpoint URL
--chain <name>     Chain preset (mainnet, sepolia)
--json             Output as JSON (supported by query commands)
```

Values like `--value` and `--gas-limit` accept unit suffixes:

```
1ether, 0.5eth, 10gwei, 21000wei, 21000, 0xde0b6b3a7640000
```

## Commands

### Blockchain Queries

```sh
gleeth block-number
gleeth chain-id
gleeth gas-price
gleeth fee-history --block-count 10 --percentiles 25,50,75

# JSON output for scripting
gleeth gas-price --chain mainnet --json
```

### Account Queries

```sh
# Check balance
gleeth balance 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045

# Multiple balances (queried in parallel)
gleeth balance 0xaddr1 0xaddr2 0xaddr3

# From a file (one address per line)
gleeth balance --file addresses.txt

# Get nonce
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
gleeth estimate-gas --from 0xf39Fd6... --to 0x709979... --value 1ether

# Read contract storage
gleeth storage-at --address 0xA0b869... --slot 0x0

# Query event logs
gleeth get-logs --address 0xA0b869... --from-block 0x1000000 --to-block latest
```

### Transactions

```sh
# Send ETH (EIP-1559, human-readable value)
gleeth send \
  --to 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
  --value 1ether \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Send with legacy transaction type
gleeth send --to 0x... --value 0.5eth --private-key 0x... --legacy

# Look up a transaction
gleeth transaction 0xabc123...

# Get a transaction receipt
gleeth receipt 0xabc123...

# Wait for a transaction to be mined
gleeth wait 0xabc123... --timeout 120000
```

### Wallet Management

```sh
gleeth wallet generate
gleeth wallet info --private-key 0x...
gleeth wallet sign --private-key 0x... --message "hello"
gleeth wallet verify --public-key 0x04... --message "hello" --signature 0x...
```

### ABI and Signature Tools

```sh
# Encode calldata from function signature + parameters
gleeth encode-calldata "transfer(address,uint256)" \
  address:0xd8dA6BF2... uint256:1000000

# Decode calldata
gleeth decode-calldata 0xa9059cbb... --signature "transfer(address,uint256)"
gleeth decode-calldata 0xa9059cbb... --abi erc20.json

# Look up function signatures by 4-byte selector (via 4byte.directory)
gleeth 4byte 0xa9059cbb

# Look up verified contract ABI (via Sourcify)
gleeth abi 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 --chain mainnet
gleeth abi 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 --chain mainnet --output erc20.json

# Decode revert reason
gleeth decode-revert 0x08c379a0...
```

### Hashing and Conversion

```sh
# Compute keccak256 hash
gleeth keccak "transfer(address,uint256)"
gleeth keccak --hex 0xdeadbeef

# Compute function selector or event topic
gleeth selector "transfer(address,uint256)"
gleeth selector "Transfer(address,address,uint256)" --event

# EIP-55 address checksum
gleeth checksum 0xd8da6bf26964af9d7eed9e03e53415d37aa96045

# Unit conversion
gleeth convert 1 --from ether --to wei
gleeth convert 1000000000 --from gwei --to ether

# Recover signer from signature
gleeth recover --mode address "hello" 0x...
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
