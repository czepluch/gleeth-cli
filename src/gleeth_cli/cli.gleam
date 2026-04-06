import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleeth/ethereum/types as eth_types
import gleeth/rpc/types as rpc_types
import gleeth/utils/validation
import gleeth_cli/value

/// CLI command definitions
pub type Command {
  BlockNumber
  Block(block_id: String)
  Balance(addresses: List(eth_types.Address), file: Option(String))
  Call(
    contract: eth_types.Address,
    function: String,
    parameters: List(String),
    abi_file: Option(String),
  )
  Transaction(hash: eth_types.Hash)
  Code(address: eth_types.Address)
  EstimateGas(from: String, to: String, value: String, data: String)
  StorageAt(address: eth_types.Address, slot: String, block: String)
  GetLogs(
    from_block: String,
    to_block: String,
    address: String,
    topics: List(String),
  )
  Send(
    to: String,
    value: String,
    private_key: String,
    gas_limit: String,
    data: String,
    legacy: Bool,
  )
  Wallet(wallet_args: List(String))
  Help
  // RPC commands
  ChainId
  GasPrice
  FeeHistory(block_count: Int, newest_block: String, percentiles: List(Float))
  Nonce(address: eth_types.Address, block: String)
  Receipt(hash: eth_types.Hash)
  Wait(hash: eth_types.Hash, timeout: Int)
  // Offline commands
  Recover(recover_args: List(String))
  Checksum(address: String)
  Convert(value: String, from_unit: String, to_unit: String)
  DecodeTx(raw_hex: String)
  DecodeCalldata(
    calldata: String,
    signature: Option(String),
    abi_file: Option(String),
    function_name: Option(String),
  )
  DecodeRevert(data: String, abi_file: Option(String))
  Selector(signature: String, is_event: Bool)
  Keccak(input: String, is_hex: Bool)
  EncodeCalldata(signature: String, params: List(String))
  FourByte(selector: String)
  AbiLookup(address: String, chain: String, output: Option(String))
  SignTypedData(json_file: String, private_key: String)
  VerifyTypedData(json_file: String, signature: String)
  HashTypedData(json_file: String)
  CommandHelp(text: String)
}

/// CLI arguments structure
pub type Args {
  Args(command: Command, rpc_url: String, json: Bool)
}

/// Parse command line arguments
pub fn parse_args(args: List(String)) -> Result(Args, rpc_types.GleethError) {
  let json = list.contains(args, "--json")
  let args = list.filter(args, fn(a) { a != "--json" })
  use result <- result.try(parse_command(args))
  Ok(Args(..result, json: json))
}

fn parse_command(args: List(String)) -> Result(Args, rpc_types.GleethError) {
  // Check for per-command help: gleeth <command> --help
  case args {
    [command, "--help"] | [command, "-h"] ->
      case command_help(command) {
        Ok(text) -> Ok(Args(CommandHelp(text), "", False))
        Error(_) -> parse_command_inner(args)
      }
    _ -> parse_command_inner(args)
  }
}

fn parse_command_inner(
  args: List(String),
) -> Result(Args, rpc_types.GleethError) {
  case args {
    [] -> Ok(Args(Help, "", False))
    ["help"] -> Ok(Args(Help, "", False))
    ["--help"] -> Ok(Args(Help, "", False))
    ["-h"] -> Ok(Args(Help, "", False))

    ["block-number", ..rest] -> {
      use rpc_url <- result.try(extract_rpc_target(rest))
      Ok(Args(BlockNumber, rpc_url, False))
    }

    ["block", block_id, ..rest] -> {
      use rpc_url <- result.try(extract_rpc_target(rest))
      Ok(Args(Block(block_id), rpc_url, False))
    }

    ["balance", ..args] -> {
      use #(addresses, file, rpc_url) <- result.try(parse_balance_args(args))
      Ok(Args(Balance(addresses, file), rpc_url, False))
    }

    ["call", contract, function, ..rest] -> {
      use validated_contract <- result.try(validation.validate_address(contract))
      let #(parameters, abi_file, rpc_args) = extract_call_args(rest)
      use rpc_url <- result.try(extract_rpc_target(rpc_args))
      Ok(Args(
        Call(validated_contract, function, parameters, abi_file),
        rpc_url,
        False,
      ))
    }

    ["transaction", hash, ..rest] -> {
      use validated_hash <- result.try(validation.validate_hash(hash))
      use rpc_url <- result.try(extract_rpc_target(rest))
      Ok(Args(Transaction(validated_hash), rpc_url, False))
    }

    ["code", address, ..rest] -> {
      use validated_address <- result.try(validation.validate_address(address))
      use rpc_url <- result.try(extract_rpc_target(rest))
      Ok(Args(Code(validated_address), rpc_url, False))
    }

    ["estimate-gas", ..rest] -> {
      use #(from, to, value, data, remaining) <- result.try(
        parse_estimate_gas_args(rest),
      )
      use rpc_url <- result.try(extract_rpc_target(remaining))
      Ok(Args(EstimateGas(from, to, value, data), rpc_url, False))
    }

    ["storage-at", ..rest] -> {
      use #(address, slot, block, remaining) <- result.try(
        parse_storage_at_args(rest),
      )
      use rpc_url <- result.try(extract_rpc_target(remaining))
      Ok(Args(StorageAt(address, slot, block), rpc_url, False))
    }

    ["get-logs", ..rest] -> {
      use #(from_block, to_block, address, topics, remaining) <- result.try(
        parse_get_logs_args(rest),
      )
      use rpc_url <- result.try(extract_rpc_target(remaining))
      Ok(Args(GetLogs(from_block, to_block, address, topics), rpc_url, False))
    }

    ["send", ..rest] -> {
      use #(to, value, private_key, gas_limit, data, legacy, remaining) <- result.try(
        parse_send_args(rest),
      )
      use rpc_url <- result.try(extract_rpc_target(remaining))
      Ok(Args(
        Send(to, value, private_key, gas_limit, data, legacy),
        rpc_url,
        False,
      ))
    }

    ["wallet", ..wallet_args] -> {
      // Wallet commands don't require RPC URL
      Ok(Args(Wallet(wallet_args), "", False))
    }

    // RPC commands
    ["chain-id", ..rest] -> {
      use rpc_url <- result.try(extract_rpc_target(rest))
      Ok(Args(ChainId, rpc_url, False))
    }

    ["gas-price", ..rest] -> {
      use rpc_url <- result.try(extract_rpc_target(rest))
      Ok(Args(GasPrice, rpc_url, False))
    }

    ["fee-history", ..rest] -> {
      use #(block_count, newest_block, percentiles, remaining) <- result.try(
        parse_fee_history_args(rest),
      )
      use rpc_url <- result.try(extract_rpc_target(remaining))
      Ok(Args(
        FeeHistory(block_count, newest_block, percentiles),
        rpc_url,
        False,
      ))
    }

    ["nonce", address, ..rest] -> {
      use validated_address <- result.try(validation.validate_address(address))
      use #(block, remaining) <- result.try(parse_nonce_args(rest))
      use rpc_url <- result.try(extract_rpc_target(remaining))
      Ok(Args(Nonce(validated_address, block), rpc_url, False))
    }

    ["receipt", hash, ..rest] -> {
      use validated_hash <- result.try(validation.validate_hash(hash))
      use rpc_url <- result.try(extract_rpc_target(rest))
      Ok(Args(Receipt(validated_hash), rpc_url, False))
    }

    ["wait", hash, ..rest] -> {
      use validated_hash <- result.try(validation.validate_hash(hash))
      use #(timeout, remaining) <- result.try(parse_wait_args(rest))
      use rpc_url <- result.try(extract_rpc_target(remaining))
      Ok(Args(Wait(validated_hash, timeout), rpc_url, False))
    }

    // Offline commands
    ["recover", ..recover_args] -> {
      Ok(Args(Recover(recover_args), "", False))
    }

    ["checksum", address] -> {
      Ok(Args(Checksum(address), "", False))
    }

    ["convert", value, ..rest] -> {
      use #(from_unit, to_unit) <- result.try(parse_convert_args(rest))
      Ok(Args(Convert(value, from_unit, to_unit), "", False))
    }

    ["decode-tx", raw_hex] -> {
      Ok(Args(DecodeTx(raw_hex), "", False))
    }

    ["decode-calldata", calldata, ..rest] -> {
      let #(signature, abi_file, function_name) =
        parse_decode_calldata_args(rest)
      Ok(Args(
        DecodeCalldata(calldata, signature, abi_file, function_name),
        "",
        False,
      ))
    }

    ["decode-revert", data, ..rest] -> {
      let abi_file = parse_decode_revert_args(rest)
      Ok(Args(DecodeRevert(data, abi_file), "", False))
    }

    ["selector", signature, ..rest] -> {
      let is_event = parse_selector_args(rest)
      Ok(Args(Selector(signature, is_event), "", False))
    }

    ["keccak", "--hex", input] -> Ok(Args(Keccak(input, True), "", False))
    ["keccak", input] -> Ok(Args(Keccak(input, False), "", False))

    ["encode-calldata", signature, ..params] ->
      Ok(Args(EncodeCalldata(signature, params), "", False))

    ["4byte", selector] -> Ok(Args(FourByte(selector), "", False))

    ["abi", address, ..rest] -> {
      let #(chain, output) = parse_abi_lookup_args(rest)
      Ok(Args(AbiLookup(address, chain, output), "", False))
    }

    ["sign-typed-data", file, "--private-key", key] ->
      Ok(Args(SignTypedData(file, key), "", False))
    ["sign-typed-data", file, "-k", key] ->
      Ok(Args(SignTypedData(file, key), "", False))
    ["sign-typed-data", "--verify", file, "--signature", sig] ->
      Ok(Args(VerifyTypedData(file, sig), "", False))
    ["sign-typed-data", "--hash", file] ->
      Ok(Args(HashTypedData(file), "", False))

    _ ->
      Error(rpc_types.ConfigError(
        "Invalid command. Use --help for usage information.",
      ))
  }
}

// Extract RPC URL from remaining arguments.
// --rpc-url takes a URL directly.
// --chain resolves via GLEETH_RPC_<CHAIN> env var, with built-in
// fallbacks for mainnet and sepolia.
fn extract_rpc_target(
  args: List(String),
) -> Result(String, rpc_types.GleethError) {
  case args {
    ["--rpc-url", url, ..] -> Ok(url)
    ["--chain", name, ..] -> resolve_chain_rpc(name)
    [] -> {
      case get_env_rpc_url() {
        Ok(url) -> Ok(url)
        Error(_) ->
          Error(rpc_types.ConfigError(
            "RPC URL required. Use --rpc-url, --chain <name>, or set GLEETH_RPC_URL.",
          ))
      }
    }
    _ ->
      Error(rpc_types.ConfigError(
        "Invalid arguments. Use --rpc-url <url> or --chain <name>.",
      ))
  }
}

// Resolve a chain name to an RPC URL.
// Priority: GLEETH_RPC_<CHAIN> env var > built-in defaults.
fn resolve_chain_rpc(name: String) -> Result(String, rpc_types.GleethError) {
  let env_key = "GLEETH_RPC_" <> string.uppercase(name)
  case get_env(env_key) {
    Ok(url) -> Ok(url)
    Error(_) ->
      case string.lowercase(name) {
        "mainnet" | "ethereum" -> Ok("https://eth.llamarpc.com")
        "sepolia" -> Ok("https://ethereum-sepolia.publicnode.com")
        _ ->
          Error(rpc_types.ConfigError(
            "No RPC URL for chain '"
            <> name
            <> "'. Set "
            <> env_key
            <> " or use --rpc-url.",
          ))
      }
  }
}

// Parse balance command arguments - supports multiple addresses and --file
fn parse_balance_args(
  args: List(String),
) -> Result(
  #(List(eth_types.Address), Option(String), String),
  rpc_types.GleethError,
) {
  case args {
    ["--file", filename, ..rest] -> {
      use rpc_url <- result.try(extract_rpc_target(rest))
      Ok(#([], Some(filename), rpc_url))
    }
    ["-f", filename, ..rest] -> {
      use rpc_url <- result.try(extract_rpc_target(rest))
      Ok(#([], Some(filename), rpc_url))
    }
    _ -> {
      let #(address_args, remaining) = split_until_flag(args)
      case address_args {
        [] ->
          Error(rpc_types.ConfigError(
            "At least one address or --file must be specified",
          ))
        _ -> {
          use validated_addresses <- result.try(validation.validate_addresses(
            address_args,
          ))
          use rpc_url <- result.try(extract_rpc_target(remaining))
          Ok(#(validated_addresses, None, rpc_url))
        }
      }
    }
  }
}

// Split arguments until we hit a flag (--rpc-url, --file, etc.)
fn split_until_flag(args: List(String)) -> #(List(String), List(String)) {
  case args {
    [] -> #([], [])
    [arg, ..rest] -> {
      case string.starts_with(arg, "--") {
        True -> #([], args)
        False -> {
          let #(addresses, remaining) = split_until_flag(rest)
          #([arg, ..addresses], remaining)
        }
      }
    }
  }
}

// Get RPC URL from the GLEETH_RPC_URL environment variable
fn get_env_rpc_url() -> Result(String, Nil) {
  get_env("GLEETH_RPC_URL")
}

@external(erlang, "gleeth_ffi", "get_env")
fn get_env(name: String) -> Result(String, Nil)

// Extract parameters, --abi flag, and RPC arguments from call command args
fn extract_call_args(
  args: List(String),
) -> #(List(String), Option(String), List(String)) {
  extract_call_args_helper(args, [], None)
}

fn extract_call_args_helper(
  args: List(String),
  parameters: List(String),
  abi_file: Option(String),
) -> #(List(String), Option(String), List(String)) {
  case args {
    ["--abi", file, ..rest] ->
      extract_call_args_helper(rest, parameters, Some(file))
    ["--params", param, ..rest] ->
      extract_call_args_helper(rest, [param, ..parameters], abi_file)
    [arg, ..rest] ->
      case string.starts_with(arg, "--") {
        // Unknown flag - treat as remaining args (for --rpc-url, --chain, etc.)
        True -> #(list.reverse(parameters), abi_file, args)
        // Positional arg - treat as parameter
        False -> extract_call_args_helper(rest, [arg, ..parameters], abi_file)
      }
    [] -> #(list.reverse(parameters), abi_file, [])
  }
}

// Parse estimate-gas command arguments
fn parse_estimate_gas_args(
  args: List(String),
) -> Result(
  #(String, String, String, String, List(String)),
  rpc_types.GleethError,
) {
  parse_estimate_gas_args_helper(args, "", "", "", "", [])
}

// Helper function to parse estimate-gas arguments recursively
fn parse_estimate_gas_args_helper(
  args: List(String),
  from: String,
  to: String,
  value: String,
  data: String,
  remaining: List(String),
) -> Result(
  #(String, String, String, String, List(String)),
  rpc_types.GleethError,
) {
  case args {
    [] -> Ok(#(from, to, value, data, remaining))

    ["--from", addr, ..rest] -> {
      use validated_addr <- result.try(validation.validate_address(addr))
      parse_estimate_gas_args_helper(
        rest,
        validated_addr,
        to,
        value,
        data,
        remaining,
      )
    }

    ["--to", addr, ..rest] -> {
      use validated_addr <- result.try(validation.validate_address(addr))
      parse_estimate_gas_args_helper(
        rest,
        from,
        validated_addr,
        value,
        data,
        remaining,
      )
    }

    ["--value", val, ..rest] -> {
      use parsed_val <- result.try(
        value.parse_value(val)
        |> result.map_error(rpc_types.ConfigError),
      )
      parse_estimate_gas_args_helper(
        rest,
        from,
        to,
        parsed_val,
        data,
        remaining,
      )
    }

    ["--data", hex_data, ..rest] -> {
      parse_estimate_gas_args_helper(rest, from, to, value, hex_data, remaining)
    }

    // Any other arguments (like --rpc-url) go to remaining
    _ -> Ok(#(from, to, value, data, args))
  }
}

// Parse storage-at command arguments
fn parse_storage_at_args(
  args: List(String),
) -> Result(#(String, String, String, List(String)), rpc_types.GleethError) {
  parse_storage_at_args_helper(args, "", "", "", [])
}

// Helper function to parse storage-at arguments recursively
fn parse_storage_at_args_helper(
  args: List(String),
  address: String,
  slot: String,
  block: String,
  remaining: List(String),
) -> Result(#(String, String, String, List(String)), rpc_types.GleethError) {
  case args {
    [] -> {
      // Validate required fields
      case address == "" || slot == "" {
        True ->
          Error(rpc_types.ConfigError(
            "storage-at requires --address and --slot flags",
          ))
        False -> Ok(#(address, slot, block, remaining))
      }
    }

    ["--address", addr, ..rest] -> {
      use validated_addr <- result.try(validation.validate_address(addr))
      parse_storage_at_args_helper(rest, validated_addr, slot, block, remaining)
    }

    ["--slot", slot_val, ..rest] -> {
      parse_storage_at_args_helper(rest, address, slot_val, block, remaining)
    }

    ["--block", block_val, ..rest] -> {
      parse_storage_at_args_helper(rest, address, slot, block_val, remaining)
    }

    // Any other arguments (like --rpc-url) go to remaining
    _ -> Ok(#(address, slot, block, args))
  }
}

// Parse get-logs command arguments
fn parse_get_logs_args(
  args: List(String),
) -> Result(
  #(String, String, String, List(String), List(String)),
  rpc_types.GleethError,
) {
  parse_get_logs_args_helper(args, "", "", "", [], [])
}

// Helper function to parse get-logs arguments recursively
fn parse_get_logs_args_helper(
  args: List(String),
  from_block: String,
  to_block: String,
  address: String,
  topics: List(String),
  remaining: List(String),
) -> Result(
  #(String, String, String, List(String), List(String)),
  rpc_types.GleethError,
) {
  case args {
    [] -> Ok(#(from_block, to_block, address, topics, remaining))

    ["--from-block", block, ..rest] -> {
      parse_get_logs_args_helper(
        rest,
        block,
        to_block,
        address,
        topics,
        remaining,
      )
    }

    ["--to-block", block, ..rest] -> {
      parse_get_logs_args_helper(
        rest,
        from_block,
        block,
        address,
        topics,
        remaining,
      )
    }

    ["--address", addr, ..rest] -> {
      use validated_addr <- result.try(validation.validate_address(addr))
      parse_get_logs_args_helper(
        rest,
        from_block,
        to_block,
        validated_addr,
        topics,
        remaining,
      )
    }

    ["--topic", topic, ..rest] -> {
      // Add topic to the list
      let new_topics = [topic, ..topics]
      parse_get_logs_args_helper(
        rest,
        from_block,
        to_block,
        address,
        new_topics,
        remaining,
      )
    }

    // Any other arguments (like --rpc-url) go to remaining
    _ -> Ok(#(from_block, to_block, address, topics, args))
  }
}

// Parse send command arguments
fn parse_send_args(
  args: List(String),
) -> Result(
  #(String, String, String, String, String, Bool, List(String)),
  rpc_types.GleethError,
) {
  parse_send_args_helper(args, "", "", "", "", "0x", False, [])
}

fn parse_send_args_helper(
  args: List(String),
  to: String,
  value: String,
  private_key: String,
  gas_limit: String,
  data: String,
  legacy: Bool,
  remaining: List(String),
) -> Result(
  #(String, String, String, String, String, Bool, List(String)),
  rpc_types.GleethError,
) {
  case args {
    [] -> {
      case to == "" || private_key == "" {
        True ->
          Error(rpc_types.ConfigError(
            "send requires --to and --private-key flags",
          ))
        False ->
          Ok(#(to, value, private_key, gas_limit, data, legacy, remaining))
      }
    }
    ["--to", addr, ..rest] -> {
      use validated_addr <- result.try(validation.validate_address(addr))
      parse_send_args_helper(
        rest,
        validated_addr,
        value,
        private_key,
        gas_limit,
        data,
        legacy,
        remaining,
      )
    }
    ["--value", val, ..rest] -> {
      use parsed_val <- result.try(
        value.parse_value(val)
        |> result.map_error(rpc_types.ConfigError),
      )
      parse_send_args_helper(
        rest,
        to,
        parsed_val,
        private_key,
        gas_limit,
        data,
        legacy,
        remaining,
      )
    }
    ["--private-key", key, ..rest] ->
      parse_send_args_helper(
        rest,
        to,
        value,
        key,
        gas_limit,
        data,
        legacy,
        remaining,
      )
    ["--gas-limit", gl, ..rest] -> {
      use parsed_gl <- result.try(
        value.parse_value(gl)
        |> result.map_error(rpc_types.ConfigError),
      )
      parse_send_args_helper(
        rest,
        to,
        value,
        private_key,
        parsed_gl,
        data,
        legacy,
        remaining,
      )
    }
    ["--data", d, ..rest] ->
      parse_send_args_helper(
        rest,
        to,
        value,
        private_key,
        gas_limit,
        d,
        legacy,
        remaining,
      )
    ["--legacy", ..rest] ->
      parse_send_args_helper(
        rest,
        to,
        value,
        private_key,
        gas_limit,
        data,
        True,
        remaining,
      )
    _ -> Ok(#(to, value, private_key, gas_limit, data, legacy, args))
  }
}

// Parse fee-history command arguments
fn parse_fee_history_args(
  args: List(String),
) -> Result(#(Int, String, List(Float), List(String)), rpc_types.GleethError) {
  parse_fee_history_helper(args, 0, "latest", [])
}

fn parse_fee_history_helper(
  args: List(String),
  block_count: Int,
  newest_block: String,
  percentiles: List(Float),
) -> Result(#(Int, String, List(Float), List(String)), rpc_types.GleethError) {
  case args {
    [] -> {
      case block_count {
        0 ->
          Error(rpc_types.ConfigError("fee-history requires --block-count flag"))
        _ -> Ok(#(block_count, newest_block, percentiles, []))
      }
    }
    ["--block-count", count_str, ..rest] -> {
      case int.parse(count_str) {
        Ok(count) ->
          parse_fee_history_helper(rest, count, newest_block, percentiles)
        Error(_) ->
          Error(rpc_types.ConfigError("Invalid block count: " <> count_str))
      }
    }
    ["--newest-block", block, ..rest] ->
      parse_fee_history_helper(rest, block_count, block, percentiles)
    ["--percentiles", pct_str, ..rest] -> {
      case parse_float_list(pct_str) {
        Ok(pcts) ->
          parse_fee_history_helper(rest, block_count, newest_block, pcts)
        Error(_) ->
          Error(rpc_types.ConfigError(
            "Invalid percentiles: "
            <> pct_str
            <> " (expected comma-separated floats like 25.0,50.0,75.0)",
          ))
      }
    }
    _ -> {
      case block_count {
        0 ->
          Error(rpc_types.ConfigError("fee-history requires --block-count flag"))
        _ -> Ok(#(block_count, newest_block, percentiles, args))
      }
    }
  }
}

fn parse_float_list(s: String) -> Result(List(Float), Nil) {
  s
  |> string.split(",")
  |> list.try_map(fn(part) {
    let trimmed = string.trim(part)
    case float.parse(trimmed) {
      Ok(f) -> Ok(f)
      Error(_) -> {
        // Try parsing as int and converting
        case int.parse(trimmed) {
          Ok(i) -> Ok(int.to_float(i))
          Error(_) -> Error(Nil)
        }
      }
    }
  })
}

// Parse nonce command arguments
fn parse_nonce_args(
  args: List(String),
) -> Result(#(String, List(String)), rpc_types.GleethError) {
  case args {
    ["--block", block, ..rest] -> Ok(#(block, rest))
    _ -> Ok(#("pending", args))
  }
}

// Parse wait command arguments
fn parse_wait_args(
  args: List(String),
) -> Result(#(Int, List(String)), rpc_types.GleethError) {
  case args {
    ["--timeout", timeout_str, ..rest] -> {
      case int.parse(timeout_str) {
        Ok(timeout) -> Ok(#(timeout, rest))
        Error(_) ->
          Error(rpc_types.ConfigError("Invalid timeout: " <> timeout_str))
      }
    }
    _ -> Ok(#(60_000, args))
  }
}

// Parse convert command arguments
fn parse_convert_args(
  args: List(String),
) -> Result(#(String, String), rpc_types.GleethError) {
  case args {
    ["--from", from_unit, "--to", to_unit] -> Ok(#(from_unit, to_unit))
    ["--to", to_unit, "--from", from_unit] -> Ok(#(from_unit, to_unit))
    _ ->
      Error(rpc_types.ConfigError(
        "convert requires --from <unit> --to <unit> (units: wei, gwei, ether)",
      ))
  }
}

// Parse decode-calldata arguments
fn parse_decode_calldata_args(
  args: List(String),
) -> #(Option(String), Option(String), Option(String)) {
  parse_decode_calldata_helper(args, None, None, None)
}

fn parse_decode_calldata_helper(
  args: List(String),
  signature: Option(String),
  abi_file: Option(String),
  function_name: Option(String),
) -> #(Option(String), Option(String), Option(String)) {
  case args {
    ["--signature", sig, ..rest] ->
      parse_decode_calldata_helper(rest, Some(sig), abi_file, function_name)
    ["--abi", file, ..rest] ->
      parse_decode_calldata_helper(rest, signature, Some(file), function_name)
    ["--function", name, ..rest] ->
      parse_decode_calldata_helper(rest, signature, abi_file, Some(name))
    _ -> #(signature, abi_file, function_name)
  }
}

// Parse decode-revert arguments
fn parse_decode_revert_args(args: List(String)) -> Option(String) {
  case args {
    ["--abi", file, ..] -> Some(file)
    _ -> None
  }
}

// Parse selector arguments
fn parse_selector_args(args: List(String)) -> Bool {
  case args {
    ["--event", ..] -> True
    _ -> False
  }
}

fn parse_abi_lookup_args(args: List(String)) -> #(String, Option(String)) {
  parse_abi_lookup_helper(args, "mainnet", None)
}

fn parse_abi_lookup_helper(
  args: List(String),
  chain: String,
  output: Option(String),
) -> #(String, Option(String)) {
  case args {
    ["--chain", name, ..rest] -> parse_abi_lookup_helper(rest, name, output)
    ["--output", file, ..rest] ->
      parse_abi_lookup_helper(rest, chain, Some(file))
    ["-o", file, ..rest] -> parse_abi_lookup_helper(rest, chain, Some(file))
    _ -> #(chain, output)
  }
}

/// Per-command help text
fn command_help(command: String) -> Result(String, Nil) {
  case command {
    "block-number" ->
      Ok(
        "Get the latest block number

Usage: gleeth block-number [options]

Options:
  --rpc-url <url>       RPC endpoint
  --chain <name>        Chain name
  --json                Output as JSON",
      )
    "block" ->
      Ok(
        "Get block details by number, hash, or tag

Usage: gleeth block <number|hash|latest> [options]

Arguments:
  <number|hash|latest>  Block number (decimal or hex), block hash, or 'latest'

Options:
  --rpc-url <url>       RPC endpoint
  --chain <name>        Chain name
  --json                Output as JSON

Examples:
  gleeth block latest --chain mainnet
  gleeth block 21000000 --chain mainnet
  gleeth block 0x75da96... --chain mainnet --json",
      )
    "balance" ->
      Ok(
        "Get ETH balance for one or more addresses

Usage: gleeth balance <address> [address2 ...] [options]
       gleeth balance --file <file> [options]

Arguments:
  <address>             Ethereum address (one or more, queried in parallel)
  --file, -f <file>     File with one address per line (# comments supported)

Options:
  --rpc-url <url>       RPC endpoint
  --chain <name>        Chain name
  --json                Output as JSON (single address only)

Examples:
  gleeth balance 0xd8dA6BF2... --chain mainnet
  gleeth balance 0xaddr1 0xaddr2 0xaddr3 --chain mainnet
  gleeth balance --file addresses.txt --chain mainnet",
      )
    "call" ->
      Ok(
        "Call a contract function (read-only)

Usage: gleeth call <contract> <function> [params...] [options]

Arguments:
  <contract>            Contract address
  <function>            Function name (e.g. balanceOf, totalSupply)
  [params...]           Parameters as type:value (e.g. address:0x...)

Options:
  --abi <file>          JSON ABI file for typed encoding/decoding
  --rpc-url <url>       RPC endpoint
  --chain <name>        Chain name

Examples:
  gleeth call 0xA0b8... totalSupply --chain mainnet
  gleeth call 0xA0b8... balanceOf address:0xd8dA... --chain mainnet
  gleeth call 0xA0b8... name --abi erc20.json --chain mainnet",
      )
    "transaction" ->
      Ok(
        "Get transaction details by hash

Usage: gleeth transaction <hash> [options]

Arguments:
  <hash>                Transaction hash (0x-prefixed, 66 chars)

Options:
  --rpc-url <url>       RPC endpoint
  --chain <name>        Chain name",
      )
    "code" ->
      Ok(
        "Get contract bytecode at an address

Usage: gleeth code <address> [options]

Arguments:
  <address>             Contract address

Options:
  --rpc-url <url>       RPC endpoint
  --chain <name>        Chain name",
      )
    "estimate-gas" ->
      Ok(
        "Estimate gas for a transaction

Usage: gleeth estimate-gas [options]

Options:
  --from <address>      Sender address
  --to <address>        Recipient address
  --value <amount>      Value (e.g. 1ether, 10gwei, 0xde0b...)
  --data <hex>          Transaction data
  --rpc-url <url>       RPC endpoint
  --chain <name>        Chain name",
      )
    "storage-at" ->
      Ok(
        "Read a contract's storage slot

Usage: gleeth storage-at --address <addr> --slot <hex> [options]

Options:
  --address <address>   Contract address (required)
  --slot <hex>          Storage slot position (required)
  --block <tag>         Block number, hash, or 'latest' (default: latest)
  --rpc-url <url>       RPC endpoint
  --chain <name>        Chain name",
      )
    "get-logs" ->
      Ok(
        "Query event logs with filtering

Usage: gleeth get-logs [options]

Options:
  --from-block <b>      Starting block (default: latest)
  --to-block <b>        Ending block (default: latest)
  --address <addr>      Contract address to filter
  --topic <hex>         Topic filter (repeatable for multiple topics)
  --rpc-url <url>       RPC endpoint
  --chain <name>        Chain name",
      )
    "send" ->
      Ok(
        "Sign and broadcast a transaction

Usage: gleeth send [options]

Options:
  --to <address>        Recipient address (required)
  --value <amount>      Amount to send (e.g. 1ether, 10gwei, 0xde0b...)
  --private-key <hex>   Sender's private key (required)
  --gas-limit <amount>  Gas limit (default: 21000)
  --data <hex>          Transaction calldata
  --legacy              Use legacy (Type 0) instead of EIP-1559
  --rpc-url <url>       RPC endpoint
  --chain <name>        Chain name

Examples:
  gleeth send --to 0x7099... --value 1ether --private-key 0xac09... --chain mainnet
  gleeth send --to 0x7099... --value 10gwei --private-key 0x... --legacy",
      )
    "chain-id" ->
      Ok(
        "Get the chain ID of the connected network

Usage: gleeth chain-id [options]

Options:
  --rpc-url <url>       RPC endpoint
  --chain <name>        Chain name
  --json                Output as JSON",
      )
    "gas-price" ->
      Ok(
        "Get current gas price and max priority fee

Usage: gleeth gas-price [options]

Options:
  --rpc-url <url>       RPC endpoint
  --chain <name>        Chain name
  --json                Output as JSON",
      )
    "fee-history" ->
      Ok(
        "Get fee history for recent blocks

Usage: gleeth fee-history --block-count <n> [options]

Options:
  --block-count <n>     Number of blocks to query (required)
  --newest-block <b>    Start block (default: latest)
  --percentiles <list>  Reward percentiles, comma-separated (e.g. 25,50,75)
  --rpc-url <url>       RPC endpoint
  --chain <name>        Chain name

Examples:
  gleeth fee-history --block-count 10 --percentiles 25,50,75 --chain mainnet",
      )
    "nonce" ->
      Ok(
        "Get transaction count (nonce) for an address

Usage: gleeth nonce <address> [options]

Arguments:
  <address>             Ethereum address

Options:
  --block <tag>         pending or latest (default: pending)
  --rpc-url <url>       RPC endpoint
  --chain <name>        Chain name
  --json                Output as JSON",
      )
    "receipt" ->
      Ok(
        "Get a transaction receipt

Usage: gleeth receipt <hash> [options]

Arguments:
  <hash>                Transaction hash

Options:
  --rpc-url <url>       RPC endpoint
  --chain <name>        Chain name",
      )
    "wait" ->
      Ok(
        "Wait for a transaction to be mined (polls with exponential backoff)

Usage: gleeth wait <hash> [options]

Arguments:
  <hash>                Transaction hash

Options:
  --timeout <ms>        Timeout in milliseconds (default: 60000)
  --rpc-url <url>       RPC endpoint
  --chain <name>        Chain name",
      )
    "wallet" ->
      Ok(
        "Manage Ethereum wallets

Usage: gleeth wallet <command> [options]

Commands:
  generate                              Generate new random wallet
  create --private-key <key>            Create wallet from private key
  info --private-key <key>              Show wallet information
  sign --private-key <key> --message <msg>     Sign a personal message
  verify --public-key <key> --message <msg> --signature <sig>  Verify

Short flags: -k (private-key), -p (public-key), -m (message), -s (signature)

Examples:
  gleeth wallet generate
  gleeth wallet sign -k 0x... -m 'Hello World'",
      )
    "recover" ->
      Ok(
        "Recover signer from an Ethereum signature

Usage: gleeth recover [options] <message> <signature>

Arguments:
  <message>             Message that was signed (or 0x-prefixed hash)
  <signature>           Signature in hex (65 bytes, r+s+v format)

Options:
  --mode <mode>         pubkey, address, candidates, or verify:<addr>
  --format <fmt>        compact, detailed, or json

Examples:
  gleeth recover --mode address 'Hello' 0x...
  gleeth recover --mode verify:0xf39fd... 'Hello' 0x...
  gleeth recover --mode pubkey --format json 'Hello' 0x...",
      )
    "checksum" ->
      Ok(
        "Compute EIP-55 checksummed address

Usage: gleeth checksum <address>

Arguments:
  <address>             Ethereum address (any case)",
      )
    "convert" ->
      Ok(
        "Convert between Ethereum units (wei, gwei, ether)

Usage: gleeth convert <value> --from <unit> --to <unit>

Arguments:
  <value>               Numeric value to convert

Options:
  --from <unit>         Source unit: wei, gwei, ether
  --to <unit>           Target unit: wei, gwei, ether

Examples:
  gleeth convert 1 --from ether --to wei
  gleeth convert 1000000000 --from gwei --to ether
  gleeth convert 0.5 --from ether --to gwei",
      )
    "decode-tx" ->
      Ok(
        "Decode a signed raw transaction

Usage: gleeth decode-tx <raw-hex>

Arguments:
  <raw-hex>             RLP-encoded signed transaction (0x-prefixed)
                        Auto-detects legacy (Type 0) and EIP-1559 (Type 2)",
      )
    "decode-calldata" ->
      Ok(
        "Decode contract calldata into function name and arguments

Usage: gleeth decode-calldata <hex> [options]

Arguments:
  <hex>                 Calldata hex string (0x-prefixed)

Options (one required):
  --signature <sig>     Function signature (e.g. transfer(address,uint256))
  --abi <file>          JSON ABI file
  --function <name>     Function name (used with --abi)

Examples:
  gleeth decode-calldata 0xa9059cbb... --signature 'transfer(address,uint256)'
  gleeth decode-calldata 0xa9059cbb... --abi erc20.json",
      )
    "decode-revert" ->
      Ok(
        "Decode revert reason from failed transaction data

Usage: gleeth decode-revert <hex> [options]

Arguments:
  <hex>                 Revert data hex string (0x-prefixed)

Options:
  --abi <file>          JSON ABI file (for custom error types)

Handles Error(string), Panic(uint256), and custom errors.",
      )
    "selector" ->
      Ok(
        "Compute function selector or event topic from a signature

Usage: gleeth selector <signature> [options]

Arguments:
  <signature>           Function or event signature (e.g. transfer(address,uint256))

Options:
  --event               Compute full 32-byte event topic instead of 4-byte selector

Examples:
  gleeth selector 'transfer(address,uint256)'
  gleeth selector 'Transfer(address,address,uint256)' --event",
      )
    "keccak" ->
      Ok(
        "Compute keccak256 hash

Usage: gleeth keccak <input>
       gleeth keccak --hex <hex-data>

Arguments:
  <input>               String to hash
  --hex <hex-data>      Hex-encoded bytes to hash

Examples:
  gleeth keccak 'transfer(address,uint256)'
  gleeth keccak --hex 0xdeadbeef",
      )
    "encode-calldata" ->
      Ok(
        "Encode function calldata from signature and parameters

Usage: gleeth encode-calldata <signature> [type:value ...]

Arguments:
  <signature>           Function signature (e.g. transfer(address,uint256))
  [type:value ...]      Parameters as type:value pairs

Examples:
  gleeth encode-calldata 'transfer(address,uint256)' address:0xd8dA... uint256:1000000
  gleeth encode-calldata 'approve(address,uint256)' address:0x... uint256:0xffffffff",
      )
    "4byte" ->
      Ok(
        "Look up function signatures by 4-byte selector (via Sourcify)

Usage: gleeth 4byte <selector>

Arguments:
  <selector>            4-byte function selector (0x-prefixed)

Examples:
  gleeth 4byte 0xa9059cbb",
      )
    "abi" ->
      Ok(
        "Look up a verified contract's ABI from Sourcify

Usage: gleeth abi <address> [options]

Arguments:
  <address>             Contract address

Options:
  --chain <name>        Chain name (default: mainnet)
  --output, -o <file>   Save ABI to file instead of printing

Examples:
  gleeth abi 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 --chain mainnet
  gleeth abi 0xA0b8... --chain mainnet --output usdc.json",
      )
    "sign-typed-data" ->
      Ok(
        "Sign, verify, or hash EIP-712 typed structured data

Usage: gleeth sign-typed-data <file> --private-key <key>   Sign
       gleeth sign-typed-data --verify <file> --signature <sig>  Verify
       gleeth sign-typed-data --hash <file>                Hash

Arguments:
  <file>                JSON file with EIP-712 typed data

Options:
  --private-key, -k     Private key for signing
  --verify              Verify mode: recover signer from signature
  --signature           Signature to verify (hex)
  --hash                Hash mode: output the EIP-712 digest

The JSON file follows the standard EIP-712 format:
  {\"types\": {...}, \"primaryType\": \"...\", \"domain\": {...}, \"message\": {...}}

Examples:
  gleeth sign-typed-data permit.json -k 0xac09...
  gleeth sign-typed-data --verify permit.json --signature 0x4a0f...
  gleeth sign-typed-data --hash permit.json",
      )
    _ -> Error(Nil)
  }
}

/// Display help message
pub fn show_help() -> Nil {
  io.println("gleeth - Ethereum CLI built on gleeth")
  io.println("")
  io.println("USAGE: gleeth <command> [options]")
  io.println("")
  io.println("GLOBAL OPTIONS:")
  io.println("  --rpc-url <url>       RPC endpoint URL")
  io.println(
    "  --chain <name>        Chain name (resolves via GLEETH_RPC_<CHAIN> env var)",
  )
  io.println("  --json                Output as JSON")
  io.println("")
  io.println("  Values accept unit suffixes: 1ether, 0.5eth, 10gwei, 21000")
  io.println("")
  io.println("BLOCKCHAIN:")
  io.println("  block-number                          Latest block number")
  io.println("  block <number|hash|latest>            Block details")
  io.println("  chain-id                              Chain ID")
  io.println(
    "  gas-price                             Gas price and priority fee",
  )
  io.println(
    "  fee-history [options]                 Fee history for recent blocks",
  )
  io.println(
    "    --block-count <n>                     Blocks to query (required)",
  )
  io.println(
    "    --newest-block <block>                Start block (default: latest)",
  )
  io.println("    --percentiles <25,50,75>              Reward percentiles")
  io.println("")
  io.println("ACCOUNTS:")
  io.println(
    "  balance <addr> [addr2 ...]            ETH balance (parallel for multiple)",
  )
  io.println(
    "  balance --file <file>                 Balances from address file",
  )
  io.println("  nonce <addr> [--block pending|latest] Transaction count")
  io.println("")
  io.println("CONTRACTS:")
  io.println("  call <contract> <func> [params]       Call a contract function")
  io.println(
    "    --abi <file>                          ABI file for typed decoding",
  )
  io.println("  code <addr>                           Contract bytecode")
  io.println(
    "  estimate-gas [options]                Estimate gas for a transaction",
  )
  io.println("    --from <addr>  --to <addr>  --value <amount>  --data <hex>")
  io.println("  storage-at --address <addr> --slot <hex>  Read storage slot")
  io.println("    --block <number|hash|latest>          Block to query")
  io.println("  get-logs [options]                    Query event logs")
  io.println(
    "    --from-block <b>  --to-block <b>  --address <addr>  --topic <hex>",
  )
  io.println("")
  io.println("TRANSACTIONS:")
  io.println(
    "  send [options]                        Sign and broadcast a transaction",
  )
  io.println("    --to <addr>                           Recipient (required)")
  io.println(
    "    --value <amount>                      Amount (e.g. 1ether, 10gwei, 0xde0...)",
  )
  io.println("    --private-key <hex>                   Sender key (required)")
  io.println(
    "    --gas-limit <amount>                  Gas limit (default: 21000)",
  )
  io.println("    --data <hex>                          Calldata")
  io.println(
    "    --legacy                              Use Type 0 instead of EIP-1559",
  )
  io.println("  transaction <hash>                    Transaction details")
  io.println("  receipt <hash>                        Transaction receipt")
  io.println(
    "  wait <hash> [--timeout <ms>]          Wait for tx to be mined (default: 60s)",
  )
  io.println("")
  io.println("WALLET:")
  io.println(
    "  wallet generate                       Generate new random wallet",
  )
  io.println(
    "  wallet info -k <key>                  Show wallet info from private key",
  )
  io.println("  wallet sign -k <key> -m <msg>         Sign a personal message")
  io.println(
    "  wallet verify -p <pubkey> -m <msg> -s <sig>  Verify a signature",
  )
  io.println("")
  io.println("EIP-712:")
  io.println(
    "  sign-typed-data <file> -k <key>       Sign typed data from JSON",
  )
  io.println(
    "  sign-typed-data --verify <file> --signature <sig>  Recover signer",
  )
  io.println("  sign-typed-data --hash <file>         Compute EIP-712 digest")
  io.println("")
  io.println("ABI & SIGNATURES:")
  io.println(
    "  selector <sig> [--event]              Function selector or event topic",
  )
  io.println("  encode-calldata <sig> [type:val ...]  Encode function calldata")
  io.println("  decode-calldata <hex> [options]       Decode calldata")
  io.println("    --signature <sig>                     Function signature")
  io.println("    --abi <file> [--function <name>]      Or use ABI file")
  io.println("  decode-revert <hex> [--abi <file>]    Decode revert reason")
  io.println(
    "  decode-tx <raw-hex>                   Decode signed raw transaction",
  )
  io.println(
    "  4byte <selector>                      Look up selector (Sourcify)",
  )
  io.println(
    "  abi <addr> [--chain <name>]           Look up verified ABI (Sourcify)",
  )
  io.println("    --output <file>                       Save ABI to file")
  io.println("")
  io.println("UTILITIES:")
  io.println("  keccak <input>                        Keccak256 hash of string")
  io.println(
    "  keccak --hex <data>                   Keccak256 hash of hex data",
  )
  io.println("  checksum <addr>                       EIP-55 checksum address")
  io.println(
    "  convert <val> --from <unit> --to <unit>  Convert wei/gwei/ether",
  )
  io.println(
    "  recover [options] <msg> <sig>         Recover signer from signature",
  )
  io.println("    --mode pubkey|address|candidates|verify:<addr>")
  io.println("    --format compact|detailed|json")
  io.println("")
  io.println("ENVIRONMENT:")
  io.println("  GLEETH_RPC_URL          Default RPC endpoint")
  io.println(
    "  GLEETH_RPC_<CHAIN>      Per-chain RPC (e.g. GLEETH_RPC_ARBITRUM)",
  )
  io.println("")
  io.println("EXAMPLES:")
  io.println("  gleeth block-number --chain mainnet")
  io.println("  gleeth block latest --chain mainnet --json")
  io.println("  gleeth balance 0xd8dA6BF2... --chain mainnet")
  io.println(
    "  gleeth send --to 0x7099... --value 1ether --private-key 0xac09... --chain mainnet",
  )
  io.println(
    "  gleeth call 0xA0b8... balanceOf address:0xd8dA... --chain mainnet",
  )
  io.println("  gleeth selector \"transfer(address,uint256)\"")
  io.println("  gleeth 4byte 0xa9059cbb")
  io.println("  gleeth convert 1 --from ether --to wei")
  io.println("  gleeth sign-typed-data data.json -k 0xac09...")
}
