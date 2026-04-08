import gleam/option.{None, Some}
import gleeth_cli/cli
import gleeunit/should

// =============================================================================
// block
// =============================================================================

pub fn parse_block_latest_test() {
  let args =
    cli.parse_args(["block", "latest", "--rpc-url", "http://localhost:8545"])
    |> should.be_ok
  case args.command {
    cli.Block(block_id) -> should.equal(block_id, "latest")
    _ -> should.fail()
  }
}

pub fn parse_block_number_arg_test() {
  let args =
    cli.parse_args(["block", "21000000", "--rpc-url", "http://localhost:8545"])
    |> should.be_ok
  case args.command {
    cli.Block(block_id) -> should.equal(block_id, "21000000")
    _ -> should.fail()
  }
}

pub fn parse_block_hash_test() {
  let hash =
    "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
  let args =
    cli.parse_args(["block", hash, "--rpc-url", "http://localhost:8545"])
    |> should.be_ok
  case args.command {
    cli.Block(block_id) -> should.equal(block_id, hash)
    _ -> should.fail()
  }
}

// =============================================================================
// --chain flag
// =============================================================================

pub fn parse_chain_mainnet_test() {
  let args =
    cli.parse_args(["block-number", "--chain", "mainnet"])
    |> should.be_ok
  should.equal(args.command, cli.BlockNumber)
  // resolve_rpc is called later, rpc_url should contain resolved URL
  should.not_equal(args.rpc_url, "")
}

pub fn parse_chain_sepolia_test() {
  let args =
    cli.parse_args(["chain-id", "--chain", "sepolia"])
    |> should.be_ok
  should.equal(args.command, cli.ChainId)
  should.not_equal(args.rpc_url, "")
}

// =============================================================================
// --json flag
// =============================================================================

pub fn parse_json_flag_test() {
  let args =
    cli.parse_args([
      "block-number",
      "--rpc-url",
      "http://localhost:8545",
      "--json",
    ])
    |> should.be_ok
  should.be_true(args.json)
}

pub fn parse_no_json_flag_test() {
  let args =
    cli.parse_args(["block-number", "--rpc-url", "http://localhost:8545"])
    |> should.be_ok
  should.be_false(args.json)
}

pub fn parse_json_with_chain_test() {
  let args =
    cli.parse_args(["gas-price", "--chain", "mainnet", "--json"])
    |> should.be_ok
  should.equal(args.command, cli.GasPrice)
  should.be_true(args.json)
}

// =============================================================================
// keccak
// =============================================================================

pub fn parse_keccak_string_test() {
  let args =
    cli.parse_args(["keccak", "hello"])
    |> should.be_ok
  case args.command {
    cli.Keccak(input, is_hex) -> {
      should.equal(input, "hello")
      should.be_false(is_hex)
    }
    _ -> should.fail()
  }
}

pub fn parse_keccak_hex_test() {
  let args =
    cli.parse_args(["keccak", "--hex", "0xdeadbeef"])
    |> should.be_ok
  case args.command {
    cli.Keccak(input, is_hex) -> {
      should.equal(input, "0xdeadbeef")
      should.be_true(is_hex)
    }
    _ -> should.fail()
  }
}

// =============================================================================
// encode-calldata
// =============================================================================

pub fn parse_encode_calldata_test() {
  let args =
    cli.parse_args([
      "encode-calldata",
      "transfer(address,uint256)",
      "address:0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      "uint256:1000000",
    ])
    |> should.be_ok
  case args.command {
    cli.EncodeCalldata(sig, params) -> {
      should.equal(sig, "transfer(address,uint256)")
      should.equal(params, [
        "address:0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
        "uint256:1000000",
      ])
    }
    _ -> should.fail()
  }
}

pub fn parse_encode_calldata_no_params_test() {
  let args =
    cli.parse_args(["encode-calldata", "totalSupply()"])
    |> should.be_ok
  case args.command {
    cli.EncodeCalldata(sig, params) -> {
      should.equal(sig, "totalSupply()")
      should.equal(params, [])
    }
    _ -> should.fail()
  }
}

// =============================================================================
// 4byte
// =============================================================================

pub fn parse_4byte_test() {
  let args =
    cli.parse_args(["4byte", "0xa9059cbb"])
    |> should.be_ok
  case args.command {
    cli.FourByte(selector) -> should.equal(selector, "0xa9059cbb")
    _ -> should.fail()
  }
}

// =============================================================================
// abi
// =============================================================================

pub fn parse_abi_test() {
  let args =
    cli.parse_args([
      "abi",
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "--chain",
      "mainnet",
    ])
    |> should.be_ok
  case args.command {
    cli.AbiLookup(address, chain, output) -> {
      should.equal(address, "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")
      should.equal(chain, "mainnet")
      should.equal(output, None)
    }
    _ -> should.fail()
  }
}

pub fn parse_abi_with_output_test() {
  let args =
    cli.parse_args([
      "abi",
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "--output",
      "usdc.json",
    ])
    |> should.be_ok
  case args.command {
    cli.AbiLookup(_, _, output) -> should.equal(output, Some("usdc.json"))
    _ -> should.fail()
  }
}

// =============================================================================
// sign-typed-data
// =============================================================================

pub fn parse_sign_typed_data_test() {
  let args =
    cli.parse_args([
      "sign-typed-data",
      "data.json",
      "--private-key",
      "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    ])
    |> should.be_ok
  case args.command {
    cli.SignTypedData(file, key) -> {
      should.equal(file, "data.json")
      should.equal(
        key,
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      )
    }
    _ -> should.fail()
  }
}

pub fn parse_sign_typed_data_verify_test() {
  let args =
    cli.parse_args([
      "sign-typed-data",
      "--verify",
      "data.json",
      "--signature",
      "0xabcd",
    ])
    |> should.be_ok
  case args.command {
    cli.VerifyTypedData(file, sig) -> {
      should.equal(file, "data.json")
      should.equal(sig, "0xabcd")
    }
    _ -> should.fail()
  }
}

pub fn parse_sign_typed_data_hash_test() {
  let args =
    cli.parse_args(["sign-typed-data", "--hash", "data.json"])
    |> should.be_ok
  case args.command {
    cli.HashTypedData(file) -> should.equal(file, "data.json")
    _ -> should.fail()
  }
}

// =============================================================================
// Human-readable values
// =============================================================================

pub fn parse_send_ether_value_test() {
  let args =
    cli.parse_args([
      "send",
      "--to",
      "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      "--value",
      "1ether",
      "--private-key",
      "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.Send(_, value, _, _, _, _) -> should.equal(value, "0xde0b6b3a7640000")
    _ -> should.fail()
  }
}

pub fn parse_send_gwei_value_test() {
  let args =
    cli.parse_args([
      "send",
      "--to",
      "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      "--value",
      "10gwei",
      "--private-key",
      "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.Send(_, value, _, _, _, _) -> should.equal(value, "0x2540be400")
    _ -> should.fail()
  }
}

// =============================================================================
// resolve_rpc
// =============================================================================

pub fn resolve_rpc_url_test() {
  cli.resolve_rpc(Ok("http://localhost:8545"), Error(Nil))
  |> should.be_ok
  |> should.equal("http://localhost:8545")
}

pub fn resolve_rpc_chain_mainnet_test() {
  cli.resolve_rpc(Error(Nil), Ok("mainnet"))
  |> should.be_ok
  |> should.equal("https://eth.llamarpc.com")
}

pub fn resolve_rpc_chain_sepolia_test() {
  cli.resolve_rpc(Error(Nil), Ok("sepolia"))
  |> should.be_ok
  |> should.equal("https://ethereum-sepolia.publicnode.com")
}

pub fn resolve_rpc_url_takes_precedence_test() {
  cli.resolve_rpc(Ok("http://custom:8545"), Ok("mainnet"))
  |> should.be_ok
  |> should.equal("http://custom:8545")
}

pub fn resolve_rpc_unknown_chain_no_env_test() {
  cli.resolve_rpc(Error(Nil), Ok("unknown-chain-xyz"))
  |> should.be_error
}

// =============================================================================
// wallet passthrough
// =============================================================================

pub fn parse_wallet_passthrough_test() {
  let args =
    cli.parse_args(["wallet", "generate"])
    |> should.be_ok
  case args.command {
    cli.Wallet(wallet_args) -> should.equal(wallet_args, ["generate"])
    _ -> should.fail()
  }
}

pub fn parse_wallet_sign_passthrough_test() {
  let args =
    cli.parse_args(["wallet", "sign", "-k", "0x123", "-m", "hello"])
    |> should.be_ok
  case args.command {
    cli.Wallet(wallet_args) ->
      should.equal(wallet_args, ["sign", "-k", "0x123", "-m", "hello"])
    _ -> should.fail()
  }
}

// =============================================================================
// get-logs
// =============================================================================

pub fn parse_get_logs_test() {
  let args =
    cli.parse_args([
      "get-logs",
      "--address",
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "--from-block",
      "0x1000000",
      "--rpc-url",
      "http://localhost:8545",
    ])
    |> should.be_ok
  case args.command {
    cli.GetLogs(from_block, _, address, _) -> {
      should.equal(from_block, "0x1000000")
      should.equal(address, "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")
    }
    _ -> should.fail()
  }
}
