# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

gleeth-cli is an Ethereum CLI tool written in Gleam, built on the [gleeth](https://hex.pm/packages/gleeth) library (v1.4.0+). It wraps the full gleeth API surface: RPC queries (blocks, block details, balances, transactions, receipts, gas, fees, nonce, logs, storage), transaction signing/sending (legacy + EIP-1559), wallet management, and offline utilities (address checksum, unit conversion, ABI encoding/decoding, signature recovery, function selectors, keccak hashing). It also integrates with external services (Sourcify for ABI and signature lookups).

## Build and Development

```sh
gleam build              # Build the project
gleam run -- --help      # Run with help flag
gleam test               # Run tests (gleeunit)
gleam format             # Format code
gleam export erlang-shipment  # Build standalone release (requires elixir)
```

Run a specific command: `gleam run -- <command> [args]`

If using mise, `.mise.toml` provides erlang, gleam, and elixir.

## Requirements

- Gleam >= 1.14.0
- Erlang/OTP >= 27
- Elixir (required for NIF compilation of ex_keccak and ex_secp256k1 dependencies)

## Architecture

**Entry point**: `src/gleeth_cli.gleam` - `main()` parses argv, routes to commands. Offline commands (wallet, recover, checksum, convert, decode-tx, decode-calldata, decode-revert, selector, keccak, encode-calldata, 4byte, abi) are handled before Provider creation. RPC commands use `create_provider(RpcTarget)` which resolves either `--rpc-url`, `--chain` presets, or `GLEETH_RPC_URL` env var.

**CLI parsing**: `src/gleeth_cli/cli.gleam` - Hand-rolled argument parser. The `Command` variant type defines all commands. `RpcTarget` is either `RpcUrl(String)` or `ChainPreset(String)`. `parse_args` strips `--json` globally, then delegates to `parse_command` which returns `Args(command, rpc_target, json)`.

**Command modules**: `src/gleeth_cli/commands/` - One module per command. Each exposes an `execute` function. RPC commands take a `Provider`; offline commands don't. Some commands accept a `json: Bool` parameter for JSON output.

**Shared utilities**:
- `value.gleam` - Human-readable value parsing (`1ether`, `10gwei`) and chain name-to-ID mapping
- `formatting.gleam` - Output formatting (Wei-to-Ether conversion, labeled values, table display)
- `file.gleam` - Read address lists from files (one per line, # comments supported)

Key patterns:
- All RPC-backed commands use `gleeth/rpc/methods` for Ethereum JSON-RPC calls
- Error handling uses `use <- result.try(...)` chaining throughout
- Address/hash validation happens via `gleeth/utils/validation` at parse time
- `parallel_balance.gleam` uses OTP processes (`gleam/erlang/process`) to batch-query balances concurrently (batches of 10)
- `four_byte.gleam` and `abi_lookup.gleam` make HTTP requests to Sourcify APIs using `gleam/httpc`
- `send.gleam` supports both legacy (Type 0) and EIP-1559 (Type 2) transactions

**FFI**: `cli.gleam` uses `@external(erlang, "gleeth_ffi", "get_env")` for environment variable access.

## RPC resolution

`--chain` and `--rpc-url` both resolve to an RPC endpoint. `--chain mainnet` and `--chain sepolia` have built-in public RPC fallbacks. Other chains resolve via `GLEETH_RPC_<CHAIN>` env vars (e.g. `GLEETH_RPC_ARBITRUM`). The chain ID is always fetched from the node via `eth_chainId` - no local mapping needed for RPC commands.

The chain name-to-ID mapping in `value.gleam` is only used by the `abi` command (Sourcify lookups) where you need a chain ID without an RPC connection.

## Future work

- **Config file**: Add `~/.gleeth.toml` or similar for persisting RPC endpoints per chain, default options, and aliases. Currently everything is env vars.
- **ENS resolution**: Needs gleeth library support (namehash, resolver contract calls). Once available, all address arguments should transparently resolve ENS names.
- **EIP-712 signing**: Implemented. `sign-typed-data` command supports sign, verify, and hash modes. Parses standard EIP-712 JSON format.
