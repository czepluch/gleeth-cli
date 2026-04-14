# gleeth-cli

Ethereum CLI built on [gleeth](https://hex.pm/packages/gleeth). Query blocks, balances, transactions, gas prices, and logs. Sign and send transactions. Manage wallets. Decode calldata, revert reasons, and raw transactions. Supports ENS names anywhere an address is expected. All from the command line.

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

Or use a chain name (`mainnet` and `sepolia` have built-in public RPCs):

```sh
gleeth balance vitalik.eth --chain mainnet
```

ENS names work anywhere an address is expected.

For other chains, set an env var and use `--chain`:

```sh
export GLEETH_RPC_ARBITRUM=https://arb1.arbitrum.io/rpc
gleeth balance 0x... --chain arbitrum
```

## Tutorial

This walkthrough uses a local [Anvil](https://book.getfoundry.sh/anvil/) node. Start it in a separate terminal:

```sh
anvil
```

Anvil gives you 10 accounts with 10000 ETH each. The first account's private key is `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`.

Set the RPC URL so you don't have to pass it every time:

```sh
export GLEETH_RPC_URL=http://localhost:8545
```

**Check the latest block:**

```
$ gleeth block-number
Latest Block: 0
Raw Hex: 0x0
```

**Check a balance:**

```
$ gleeth balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Balance: 10000.0 ETH
Raw Wei: 0x21e19e0c9bab2400000
```

**ENS names work on mainnet (any command that takes an address):**

```
$ gleeth balance vitalik.eth --chain mainnet
Resolving vitalik.eth...
Address: 0xd8da6bf26964af9d7eed9e03e53415d37aa96045
Balance: 1.328645385561465 ETH
Raw Wei: 0x12704bf04eda60b6
```

**Send 1 ETH to another account:**

```
$ gleeth send \
    --to 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
    --value 1ether \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
Sending transaction...
  From: 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
  To: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
  Value: 0xde0b6b3a7640000
  ...
Transaction sent!
  Hash: 0x...
```

**Look up the transaction receipt:**

```
$ gleeth receipt 0x<hash-from-above>
Transaction Receipt:
  Hash: 0x...
  Status: Success
  Block Number: 0x1
  Gas Used: 0x5208
  ...
```

**Get JSON output for scripting:**

```
$ gleeth balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --json
{"address":"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266","balance":"0x..."}
```

**Offline tools work without a node:**

```
$ gleeth selector "transfer(address,uint256)"
Function: transfer(address,uint256)
Selector: 0xa9059cbb

$ gleeth convert 1 --from ether --to wei
1 ether = 1000000000000000000 wei

$ gleeth 4byte 0xa9059cbb
Selector: 0xa9059cbb
  transfer(address,uint256)

$ gleeth checksum 0xd8da6bf26964af9d7eed9e03e53415d37aa96045
Address:
  Input:      0xd8da6bf26964af9d7eed9e03e53415d37aa96045
  Checksummed: 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045
```

For per-command help, use `--help` on any command:

```
$ gleeth send --help
```

## Global Options

```
--rpc-url <URL>    RPC endpoint URL
--chain <name>     Chain name (resolves via GLEETH_RPC_<CHAIN> env var;
                   mainnet and sepolia have built-in fallbacks)
--json             Output as JSON (all RPC commands)
```

Values like `--value` and `--gas-limit` accept unit suffixes:

```
1ether, 0.5eth, 10gwei, 21000wei, 21000, 0xde0b6b3a7640000
```

## Commands

### Blockchain Queries

```sh
gleeth block-number
gleeth block latest
gleeth block 21000000
gleeth chain-id
gleeth gas-price
gleeth fee-history --block-count 10 --percentiles 25,50,75

# JSON output for scripting
gleeth block latest --chain mainnet --json
gleeth gas-price --chain mainnet --json
```

### Account Queries

```sh
# Check balance (ENS names or hex addresses)
gleeth balance vitalik.eth
gleeth balance 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045

# Multiple balances (queried in parallel)
gleeth balance vitalik.eth 0xaddr1 0xaddr2

# From a file (one address per line)
gleeth balance --file addresses.txt

# Get nonce
gleeth nonce vitalik.eth
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

### EIP-712 Typed Data Signing

```sh
# Sign typed data from a JSON file
gleeth sign-typed-data typed_data.json --private-key 0x...

# Verify a signature against typed data
gleeth sign-typed-data --verify typed_data.json --signature 0x...

# Hash typed data (for debugging)
gleeth sign-typed-data --hash typed_data.json
```

The JSON file follows the standard EIP-712 format (same as MetaMask/ethers):

```json
{
  "types": { "Mail": [{"name": "from", "type": "address"}, ...] },
  "primaryType": "Mail",
  "domain": { "name": "MyDapp", "version": "1", "chainId": 1 },
  "message": { "from": "0x...", "to": "0x...", "contents": "Hello" }
}
```

### ABI and Signature Tools

```sh
# Encode calldata from function signature + parameters
gleeth encode-calldata "transfer(address,uint256)" \
  address:0xd8dA6BF2... uint256:1000000

# Decode calldata
gleeth decode-calldata 0xa9059cbb... --signature "transfer(address,uint256)"
gleeth decode-calldata 0xa9059cbb... --abi erc20.json

# Look up function signatures by 4-byte selector (via Sourcify)
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
