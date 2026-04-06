import gleam/option.{None, Some}
import gleeth_cli/cli
import gleeunit/should

// =============================================================================
// Help / empty args
// =============================================================================

pub fn parse_empty_args_test() {
  cli.parse_args([])
  |> should.be_ok
  |> fn(args: cli.Args) { args.command }
  |> should.equal(cli.Help)
}

pub fn parse_help_test() {
  cli.parse_args(["help"])
  |> should.be_ok
  |> fn(args: cli.Args) { args.command }
  |> should.equal(cli.Help)
}

pub fn parse_dash_help_test() {
  cli.parse_args(["--help"])
  |> should.be_ok
  |> fn(args: cli.Args) { args.command }
  |> should.equal(cli.Help)
}

pub fn parse_h_flag_test() {
  cli.parse_args(["-h"])
  |> should.be_ok
  |> fn(args: cli.Args) { args.command }
  |> should.equal(cli.Help)
}

// =============================================================================
// block-number
// =============================================================================

pub fn parse_block_number_test() {
  let args =
    cli.parse_args(["block-number", "--rpc-url", "http://localhost:8545"])
    |> should.be_ok
  should.equal(args.command, cli.BlockNumber)
  should.equal(args.rpc_url, "http://localhost:8545")
}

pub fn parse_block_number_missing_rpc_test() {
  cli.parse_args(["block-number"])
  |> should.be_error
}

// =============================================================================
// balance
// =============================================================================

pub fn parse_balance_single_address_test() {
  let args =
    cli.parse_args([
      "balance",
      "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.Balance(addresses, file) -> {
      // validation preserves original case
      should.equal(addresses, [
        "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      ])
      should.equal(file, None)
    }
    _ -> should.fail()
  }
}

pub fn parse_balance_with_file_test() {
  let args =
    cli.parse_args([
      "balance",
      "--file",
      "addresses.txt",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.Balance(addresses, file) -> {
      should.equal(addresses, [])
      should.equal(file, Some("addresses.txt"))
    }
    _ -> should.fail()
  }
}

pub fn parse_balance_no_address_test() {
  cli.parse_args(["balance", "--rpc-url", "http://localhost:8545"])
  |> should.be_error
}

// =============================================================================
// transaction
// =============================================================================

pub fn parse_transaction_test() {
  let hash =
    "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
  let args =
    cli.parse_args(["transaction", hash, "--rpc-url", "http://localhost:8545"])
    |> should.be_ok
  case args.command {
    cli.Transaction(h) -> should.equal(h, hash)
    _ -> should.fail()
  }
}

pub fn parse_transaction_invalid_hash_test() {
  cli.parse_args([
    "transaction",
    "0xinvalid",
    "--rpc-url",
    "http://localhost:8545",
  ])
  |> should.be_error
}

// =============================================================================
// code
// =============================================================================

pub fn parse_code_test() {
  let args =
    cli.parse_args([
      "code",
      "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.Code(_) -> Nil
    _ -> should.fail()
  }
}

// =============================================================================
// call
// =============================================================================

pub fn parse_call_test() {
  let args =
    cli.parse_args([
      "call",
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "totalSupply",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.Call(_, function, params, abi_file) -> {
      should.equal(function, "totalSupply")
      should.equal(params, [])
      should.equal(abi_file, None)
    }
    _ -> should.fail()
  }
}

pub fn parse_call_with_abi_test() {
  let args =
    cli.parse_args([
      "call",
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "balanceOf",
      "address:0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      "--abi",
      "erc20.json",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.Call(_, _, params, abi_file) -> {
      should.equal(params, [
        "address:0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      ])
      should.equal(abi_file, Some("erc20.json"))
    }
    _ -> should.fail()
  }
}

// =============================================================================
// estimate-gas
// =============================================================================

pub fn parse_estimate_gas_test() {
  let args =
    cli.parse_args([
      "estimate-gas",
      "--from",
      "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      "--to",
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "--value",
      "0x1000",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.EstimateGas(from, to, value, data) -> {
      // validation preserves original case
      should.equal(from, "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
      should.equal(to, "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")
      should.equal(value, "0x1000")
      should.equal(data, "")
    }
    _ -> should.fail()
  }
}

// =============================================================================
// storage-at
// =============================================================================

pub fn parse_storage_at_test() {
  let args =
    cli.parse_args([
      "storage-at",
      "--address",
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "--slot",
      "0x0",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.StorageAt(_, slot, block) -> {
      should.equal(slot, "0x0")
      should.equal(block, "")
    }
    _ -> should.fail()
  }
}

pub fn parse_storage_at_missing_slot_test() {
  // storage-at without --slot still parses (validation happens at RPC call time)
  // but the parser requires both --address and --slot
  cli.parse_args([
    "storage-at",
    "--address",
    "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  ])
  |> should.be_error
}

// =============================================================================
// send
// =============================================================================

pub fn parse_send_test() {
  let args =
    cli.parse_args([
      "send",
      "--to",
      "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      "--value",
      "0xde0b6b3a7640000",
      "--private-key",
      "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.Send(to, value, _, _, _, legacy) -> {
      should.equal(to, "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
      should.equal(value, "0xde0b6b3a7640000")
      should.be_false(legacy)
    }
    _ -> should.fail()
  }
}

pub fn parse_send_legacy_test() {
  let args =
    cli.parse_args([
      "send",
      "--to",
      "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      "--private-key",
      "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      "--legacy",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.Send(_, _, _, _, _, legacy) -> should.be_true(legacy)
    _ -> should.fail()
  }
}

pub fn parse_send_missing_to_test() {
  // send with --private-key but no --to: parser defers validation,
  // so it succeeds at parse time but to="" which fails at execute time
  let args =
    cli.parse_args([
      "send",
      "--private-key",
      "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.Send(to, _, _, _, _, _) -> should.equal(to, "")
    _ -> should.fail()
  }
}

// =============================================================================
// chain-id
// =============================================================================

pub fn parse_chain_id_test() {
  let args =
    cli.parse_args(["chain-id", "--rpc-url", "http://localhost:8545"])
    |> should.be_ok
  should.equal(args.command, cli.ChainId)
  should.equal(args.rpc_url, "http://localhost:8545")
}

// =============================================================================
// gas-price
// =============================================================================

pub fn parse_gas_price_test() {
  let args =
    cli.parse_args(["gas-price", "--rpc-url", "http://localhost:8545"])
    |> should.be_ok
  should.equal(args.command, cli.GasPrice)
}

// =============================================================================
// fee-history
// =============================================================================

pub fn parse_fee_history_test() {
  let args =
    cli.parse_args([
      "fee-history",
      "--block-count",
      "10",
      "--percentiles",
      "25,50,75",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.FeeHistory(block_count, newest_block, percentiles) -> {
      should.equal(block_count, 10)
      should.equal(newest_block, "latest")
      should.equal(percentiles, [25.0, 50.0, 75.0])
    }
    _ -> should.fail()
  }
}

pub fn parse_fee_history_with_newest_block_test() {
  let args =
    cli.parse_args([
      "fee-history",
      "--block-count",
      "5",
      "--newest-block",
      "0x100",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.FeeHistory(block_count, newest_block, percentiles) -> {
      should.equal(block_count, 5)
      should.equal(newest_block, "0x100")
      should.equal(percentiles, [])
    }
    _ -> should.fail()
  }
}

pub fn parse_fee_history_missing_block_count_test() {
  cli.parse_args([
    "fee-history",
    "--rpc-url",
    "http://localhost:8545",
  ])
  |> should.be_error
}

// =============================================================================
// nonce
// =============================================================================

pub fn parse_nonce_test() {
  let args =
    cli.parse_args([
      "nonce",
      "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.Nonce(_, block) -> should.equal(block, "pending")
    _ -> should.fail()
  }
}

pub fn parse_nonce_with_block_test() {
  let args =
    cli.parse_args([
      "nonce",
      "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      "--block",
      "latest",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.Nonce(_, block) -> should.equal(block, "latest")
    _ -> should.fail()
  }
}

// =============================================================================
// receipt
// =============================================================================

pub fn parse_receipt_test() {
  let hash =
    "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
  let args =
    cli.parse_args(["receipt", hash, "--rpc-url", "http://localhost:8545"])
    |> should.be_ok
  case args.command {
    cli.Receipt(h) -> should.equal(h, hash)
    _ -> should.fail()
  }
}

// =============================================================================
// wait
// =============================================================================

pub fn parse_wait_test() {
  let hash =
    "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
  let args =
    cli.parse_args(["wait", hash, "--rpc-url", "http://localhost:8545"])
    |> should.be_ok
  case args.command {
    cli.Wait(_, timeout) -> should.equal(timeout, 60_000)
    _ -> should.fail()
  }
}

pub fn parse_wait_with_timeout_test() {
  let hash =
    "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
  let args =
    cli.parse_args([
      "wait",
      hash,
      "--timeout",
      "120000",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.Wait(_, timeout) -> should.equal(timeout, 120_000)
    _ -> should.fail()
  }
}

// =============================================================================
// Offline commands
// =============================================================================

pub fn parse_recover_test() {
  let args =
    cli.parse_args(["recover", "--mode", "address", "hello", "0xabcd"])
    |> should.be_ok
  case args.command {
    cli.Recover(recover_args) ->
      should.equal(recover_args, ["--mode", "address", "hello", "0xabcd"])
    _ -> should.fail()
  }
  should.equal(args.rpc_url, "")
}

pub fn parse_checksum_test() {
  let args =
    cli.parse_args([
      "checksum",
      "0xd8da6bf26964af9d7eed9e03e53415d37aa96045",
    ])
    |> should.be_ok
  case args.command {
    cli.Checksum(addr) ->
      should.equal(addr, "0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
    _ -> should.fail()
  }
  should.equal(args.rpc_url, "")
}

pub fn parse_convert_test() {
  let args =
    cli.parse_args(["convert", "1", "--from", "ether", "--to", "wei"])
    |> should.be_ok
  case args.command {
    cli.Convert(value, from_unit, to_unit) -> {
      should.equal(value, "1")
      should.equal(from_unit, "ether")
      should.equal(to_unit, "wei")
    }
    _ -> should.fail()
  }
}

pub fn parse_convert_reversed_flags_test() {
  let args =
    cli.parse_args(["convert", "1000000000", "--to", "ether", "--from", "gwei"])
    |> should.be_ok
  case args.command {
    cli.Convert(_, from_unit, to_unit) -> {
      should.equal(from_unit, "gwei")
      should.equal(to_unit, "ether")
    }
    _ -> should.fail()
  }
}

pub fn parse_convert_missing_flags_test() {
  cli.parse_args(["convert", "1"])
  |> should.be_error
}

pub fn parse_decode_tx_test() {
  let args =
    cli.parse_args(["decode-tx", "0x02f8abc0"])
    |> should.be_ok
  case args.command {
    cli.DecodeTx(raw_hex) -> should.equal(raw_hex, "0x02f8abc0")
    _ -> should.fail()
  }
}

pub fn parse_decode_calldata_with_signature_test() {
  let args =
    cli.parse_args([
      "decode-calldata",
      "0xa9059cbb0000",
      "--signature",
      "transfer(address,uint256)",
    ])
    |> should.be_ok
  case args.command {
    cli.DecodeCalldata(calldata, signature, abi_file, _) -> {
      should.equal(calldata, "0xa9059cbb0000")
      should.equal(signature, Some("transfer(address,uint256)"))
      should.equal(abi_file, None)
    }
    _ -> should.fail()
  }
}

pub fn parse_decode_calldata_with_abi_test() {
  let args =
    cli.parse_args([
      "decode-calldata",
      "0xa9059cbb0000",
      "--abi",
      "erc20.json",
      "--function",
      "transfer",
    ])
    |> should.be_ok
  case args.command {
    cli.DecodeCalldata(_, signature, abi_file, function_name) -> {
      should.equal(signature, None)
      should.equal(abi_file, Some("erc20.json"))
      should.equal(function_name, Some("transfer"))
    }
    _ -> should.fail()
  }
}

pub fn parse_decode_revert_test() {
  let args =
    cli.parse_args(["decode-revert", "0x08c379a0"])
    |> should.be_ok
  case args.command {
    cli.DecodeRevert(data, abi_file) -> {
      should.equal(data, "0x08c379a0")
      should.equal(abi_file, None)
    }
    _ -> should.fail()
  }
}

pub fn parse_decode_revert_with_abi_test() {
  let args =
    cli.parse_args(["decode-revert", "0x08c379a0", "--abi", "errors.json"])
    |> should.be_ok
  case args.command {
    cli.DecodeRevert(_, abi_file) -> should.equal(abi_file, Some("errors.json"))
    _ -> should.fail()
  }
}

pub fn parse_selector_test() {
  let args =
    cli.parse_args(["selector", "transfer(address,uint256)"])
    |> should.be_ok
  case args.command {
    cli.Selector(sig, is_event) -> {
      should.equal(sig, "transfer(address,uint256)")
      should.be_false(is_event)
    }
    _ -> should.fail()
  }
}

pub fn parse_selector_event_test() {
  let args =
    cli.parse_args([
      "selector",
      "Transfer(address,address,uint256)",
      "--event",
    ])
    |> should.be_ok
  case args.command {
    cli.Selector(_, is_event) -> should.be_true(is_event)
    _ -> should.fail()
  }
}

// =============================================================================
// Invalid commands
// =============================================================================

pub fn parse_invalid_command_test() {
  cli.parse_args(["nonexistent-command"])
  |> should.be_error
}

pub fn parse_invalid_address_test() {
  cli.parse_args([
    "balance",
    "not-an-address",
    "--rpc-url",
    "http://localhost:8545",
  ])
  |> should.be_error
}
