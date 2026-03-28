# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

gleeth-cli is an Ethereum CLI tool written in Gleam, built on the [gleeth](https://hex.pm/packages/gleeth) library. It wraps the full gleeth API surface: RPC queries (blocks, balances, transactions, receipts, gas, fees, nonce, logs, storage), transaction signing/sending (legacy + EIP-1559), wallet management, and offline utilities (address checksum, unit conversion, ABI decoding, signature recovery, function selectors).

## Build and Development

```sh
gleam build          # Build the project
gleam run -- --help  # Run with help flag
gleam test           # Run tests (gleeunit)
gleam format         # Format code
```

Run a specific command: `gleam run -- <command> [args]`

## Requirements

- Gleam >= 1.14.0
- Erlang/OTP >= 27
- Elixir (required for NIF compilation of ex_keccak and ex_secp256k1 dependencies)

## Architecture

**Entry point**: `src/gleeth_cli.gleam` - `main()` parses argv, routes to commands. Offline commands (wallet, recover, checksum, convert, decode-tx, decode-calldata, decode-revert, selector) are handled before Provider creation. RPC commands create a `gleeth/provider.Provider` from `--rpc-url` or `GLEETH_RPC_URL` env var.

**CLI parsing**: `src/gleeth_cli/cli.gleam` - Hand-rolled argument parser. The `Command` variant type defines all commands and their arguments. `parse_args` returns `Args(command, rpc_url)`. Each command's flags are parsed by dedicated helper functions in this file.

**Command modules**: `src/gleeth_cli/commands/` - One module per command. Each exposes an `execute` function that takes a `Provider` and command-specific arguments, calls `gleeth` RPC methods, and prints formatted output.

Key patterns:
- All RPC-backed commands use `gleeth/rpc/methods` for Ethereum JSON-RPC calls
- Error handling uses `use <-  result.try(...)` chaining throughout
- Address/hash validation happens via `gleeth/utils/validation` at parse time
- `parallel_balance.gleam` uses OTP processes (`gleam/erlang/process`) to batch-query balances concurrently (batches of 10)
- `call.gleam` supports both ABI-based decoding (from JSON ABI file) and heuristic decoding for common ERC-20 functions
- `send.gleam` supports both legacy (Type 0) and EIP-1559 (Type 2) transactions

**Shared utilities**:
- `formatting.gleam` - Output formatting (Wei-to-Ether conversion, labeled values, table display)
- `file.gleam` - Read address lists from files (one per line, # comments supported)

**FFI**: `cli.gleam` uses `@external(erlang, "gleeth_ffi", "get_env")` for environment variable access.
