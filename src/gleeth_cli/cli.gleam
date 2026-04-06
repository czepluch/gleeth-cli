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
}

/// How to connect to an Ethereum node
pub type RpcTarget {
  RpcUrl(url: String)
  ChainPreset(name: String)
}

/// CLI arguments structure
pub type Args {
  Args(command: Command, rpc_target: RpcTarget, json: Bool)
}

/// Parse command line arguments
pub fn parse_args(args: List(String)) -> Result(Args, rpc_types.GleethError) {
  let json = list.contains(args, "--json")
  let args = list.filter(args, fn(a) { a != "--json" })
  use result <- result.try(parse_command(args))
  Ok(Args(..result, json: json))
}

fn parse_command(args: List(String)) -> Result(Args, rpc_types.GleethError) {
  case args {
    [] -> Ok(Args(Help, RpcUrl(""), False))
    ["help"] -> Ok(Args(Help, RpcUrl(""), False))
    ["--help"] -> Ok(Args(Help, RpcUrl(""), False))
    ["-h"] -> Ok(Args(Help, RpcUrl(""), False))

    ["block-number", ..rest] -> {
      use rpc_target <- result.try(extract_rpc_target(rest))
      Ok(Args(BlockNumber, rpc_target, False))
    }

    ["block", block_id, ..rest] -> {
      use rpc_target <- result.try(extract_rpc_target(rest))
      Ok(Args(Block(block_id), rpc_target, False))
    }

    ["balance", ..args] -> {
      use #(addresses, file, rpc_target) <- result.try(parse_balance_args(args))
      Ok(Args(Balance(addresses, file), rpc_target, False))
    }

    ["call", contract, function, ..rest] -> {
      use validated_contract <- result.try(validation.validate_address(contract))
      let #(parameters, abi_file, rpc_args) = extract_call_args(rest)
      use rpc_target <- result.try(extract_rpc_target(rpc_args))
      Ok(Args(
        Call(validated_contract, function, parameters, abi_file),
        rpc_target,
        False,
      ))
    }

    ["transaction", hash, ..rest] -> {
      use validated_hash <- result.try(validation.validate_hash(hash))
      use rpc_target <- result.try(extract_rpc_target(rest))
      Ok(Args(Transaction(validated_hash), rpc_target, False))
    }

    ["code", address, ..rest] -> {
      use validated_address <- result.try(validation.validate_address(address))
      use rpc_target <- result.try(extract_rpc_target(rest))
      Ok(Args(Code(validated_address), rpc_target, False))
    }

    ["estimate-gas", ..rest] -> {
      use #(from, to, value, data, remaining) <- result.try(
        parse_estimate_gas_args(rest),
      )
      use rpc_target <- result.try(extract_rpc_target(remaining))
      Ok(Args(EstimateGas(from, to, value, data), rpc_target, False))
    }

    ["storage-at", ..rest] -> {
      use #(address, slot, block, remaining) <- result.try(
        parse_storage_at_args(rest),
      )
      use rpc_target <- result.try(extract_rpc_target(remaining))
      Ok(Args(StorageAt(address, slot, block), rpc_target, False))
    }

    ["get-logs", ..rest] -> {
      use #(from_block, to_block, address, topics, remaining) <- result.try(
        parse_get_logs_args(rest),
      )
      use rpc_target <- result.try(extract_rpc_target(remaining))
      Ok(Args(GetLogs(from_block, to_block, address, topics), rpc_target, False))
    }

    ["send", ..rest] -> {
      use #(to, value, private_key, gas_limit, data, legacy, remaining) <- result.try(
        parse_send_args(rest),
      )
      use rpc_target <- result.try(extract_rpc_target(remaining))
      Ok(Args(
        Send(to, value, private_key, gas_limit, data, legacy),
        rpc_target,
        False,
      ))
    }

    ["wallet", ..wallet_args] -> {
      // Wallet commands don't require RPC URL
      Ok(Args(Wallet(wallet_args), RpcUrl(""), False))
    }

    // RPC commands
    ["chain-id", ..rest] -> {
      use rpc_target <- result.try(extract_rpc_target(rest))
      Ok(Args(ChainId, rpc_target, False))
    }

    ["gas-price", ..rest] -> {
      use rpc_target <- result.try(extract_rpc_target(rest))
      Ok(Args(GasPrice, rpc_target, False))
    }

    ["fee-history", ..rest] -> {
      use #(block_count, newest_block, percentiles, remaining) <- result.try(
        parse_fee_history_args(rest),
      )
      use rpc_target <- result.try(extract_rpc_target(remaining))
      Ok(Args(
        FeeHistory(block_count, newest_block, percentiles),
        rpc_target,
        False,
      ))
    }

    ["nonce", address, ..rest] -> {
      use validated_address <- result.try(validation.validate_address(address))
      use #(block, remaining) <- result.try(parse_nonce_args(rest))
      use rpc_target <- result.try(extract_rpc_target(remaining))
      Ok(Args(Nonce(validated_address, block), rpc_target, False))
    }

    ["receipt", hash, ..rest] -> {
      use validated_hash <- result.try(validation.validate_hash(hash))
      use rpc_target <- result.try(extract_rpc_target(rest))
      Ok(Args(Receipt(validated_hash), rpc_target, False))
    }

    ["wait", hash, ..rest] -> {
      use validated_hash <- result.try(validation.validate_hash(hash))
      use #(timeout, remaining) <- result.try(parse_wait_args(rest))
      use rpc_target <- result.try(extract_rpc_target(remaining))
      Ok(Args(Wait(validated_hash, timeout), rpc_target, False))
    }

    // Offline commands
    ["recover", ..recover_args] -> {
      Ok(Args(Recover(recover_args), RpcUrl(""), False))
    }

    ["checksum", address] -> {
      Ok(Args(Checksum(address), RpcUrl(""), False))
    }

    ["convert", value, ..rest] -> {
      use #(from_unit, to_unit) <- result.try(parse_convert_args(rest))
      Ok(Args(Convert(value, from_unit, to_unit), RpcUrl(""), False))
    }

    ["decode-tx", raw_hex] -> {
      Ok(Args(DecodeTx(raw_hex), RpcUrl(""), False))
    }

    ["decode-calldata", calldata, ..rest] -> {
      let #(signature, abi_file, function_name) =
        parse_decode_calldata_args(rest)
      Ok(Args(
        DecodeCalldata(calldata, signature, abi_file, function_name),
        RpcUrl(""),
        False,
      ))
    }

    ["decode-revert", data, ..rest] -> {
      let abi_file = parse_decode_revert_args(rest)
      Ok(Args(DecodeRevert(data, abi_file), RpcUrl(""), False))
    }

    ["selector", signature, ..rest] -> {
      let is_event = parse_selector_args(rest)
      Ok(Args(Selector(signature, is_event), RpcUrl(""), False))
    }

    ["keccak", "--hex", input] ->
      Ok(Args(Keccak(input, True), RpcUrl(""), False))
    ["keccak", input] -> Ok(Args(Keccak(input, False), RpcUrl(""), False))

    ["encode-calldata", signature, ..params] ->
      Ok(Args(EncodeCalldata(signature, params), RpcUrl(""), False))

    ["4byte", selector] -> Ok(Args(FourByte(selector), RpcUrl(""), False))

    ["abi", address, ..rest] -> {
      let #(chain, output) = parse_abi_lookup_args(rest)
      Ok(Args(AbiLookup(address, chain, output), RpcUrl(""), False))
    }

    _ ->
      Error(rpc_types.ConfigError(
        "Invalid command. Use --help for usage information.",
      ))
  }
}

// Extract RPC target from remaining arguments
fn extract_rpc_target(
  args: List(String),
) -> Result(RpcTarget, rpc_types.GleethError) {
  case args {
    ["--rpc-url", url, ..] -> Ok(RpcUrl(url))
    ["--chain", name, ..] -> {
      use _ <- result.try(
        value.chain_name_to_id(name)
        |> result.map_error(rpc_types.ConfigError),
      )
      Ok(ChainPreset(name))
    }
    [] -> {
      case get_env_rpc_url() {
        Ok(url) -> Ok(RpcUrl(url))
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

// Parse balance command arguments - supports multiple addresses and --file
fn parse_balance_args(
  args: List(String),
) -> Result(
  #(List(eth_types.Address), Option(String), RpcTarget),
  rpc_types.GleethError,
) {
  case args {
    ["--file", filename, ..rest] -> {
      use rpc_target <- result.try(extract_rpc_target(rest))
      Ok(#([], Some(filename), rpc_target))
    }
    ["-f", filename, ..rest] -> {
      use rpc_target <- result.try(extract_rpc_target(rest))
      Ok(#([], Some(filename), rpc_target))
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
          use rpc_target <- result.try(extract_rpc_target(remaining))
          Ok(#(validated_addresses, None, rpc_target))
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
        False ->
          extract_call_args_helper(rest, [arg, ..parameters], abi_file)
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

/// Display help message
pub fn show_help() -> Nil {
  io.println("gleeth-cli - Ethereum CLI built on gleeth")
  io.println("")
  io.println("USAGE:")
  io.println("  gleeth <COMMAND> [OPTIONS]")
  io.println("")
  io.println("COMMANDS:")
  io.println("  block-number                    Get latest block number")
  io.println("  block <number|hash|latest>      Get block details")
  io.println(
    "  balance <address> [address2...]  Get balance of one or more addresses",
  )
  io.println(
    "  balance --file <filename>        Get balances from file (one address per line)",
  )
  io.println(
    "  call <contract> <function> [params...]  Call a contract function",
  )
  io.println("  transaction <hash>              Get transaction details")
  io.println(
    "  code <address>                  Get contract bytecode at address",
  )
  io.println("  estimate-gas [OPTIONS]          Estimate gas for a transaction")
  io.println(
    "  storage-at --address <addr> --slot <slot> [OPTIONS]  Get storage value at slot",
  )
  io.println("  get-logs [OPTIONS]              Get event logs with filtering")
  io.println(
    "  send [OPTIONS]                  Sign and broadcast a transaction",
  )
  io.println("  help                           Show this help message")
  io.println("")
  io.println("OPTIONS:")
  io.println("  --rpc-url <URL>                RPC endpoint URL")
  io.println("  --chain <name>                 Chain preset (mainnet, sepolia)")
  io.println(
    "  --json                         Output as JSON (supported by most query commands)",
  )
  io.println("")
  io.println("VALUES:")
  io.println("  Flags like --value and --gas-limit accept unit suffixes:")
  io.println("  1ether, 0.5eth, 10gwei, 21000wei, 21000, 0xde0b6b3a7640000")
  io.println("")
  io.println("CALL OPTIONS:")
  io.println(
    "  --abi <file>                   JSON ABI file for typed encoding/decoding",
  )
  io.println("")
  io.println("ESTIMATE-GAS OPTIONS:")
  io.println("  --from <address>               Sender address (optional)")
  io.println("  --to <address>                 Recipient address (optional)")
  io.println("  --value <wei>                  Wei amount to send (optional)")
  io.println("  --data <hex>                   Transaction data (optional)")
  io.println("")
  io.println("STORAGE-AT OPTIONS:")
  io.println("  --address <address>            Contract address (required)")
  io.println(
    "  --slot <hex>                   Storage slot position (required)",
  )
  io.println(
    "  --block <number|hash|latest>   Block to query (optional, defaults to 'latest')",
  )
  io.println("")
  io.println("GET-LOGS OPTIONS:")
  io.println(
    "  --from-block <number|hash>     Starting block (optional, defaults to 'latest')",
  )
  io.println(
    "  --to-block <number|hash>       Ending block (optional, defaults to 'latest')",
  )
  io.println(
    "  --address <address>            Contract address to filter (optional)",
  )
  io.println(
    "  --topic <hex>                  Topic filter (repeatable for multiple topics)",
  )
  io.println("")
  io.println("ENVIRONMENT VARIABLES:")
  io.println("  GLEETH_RPC_URL                 Default RPC endpoint URL")
  io.println("")
  io.println("EXAMPLES:")
  io.println("  gleeth block-number --rpc-url https://eth.llamarpc.com")
  io.println(
    "  gleeth balance 0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000 --rpc-url https://eth.llamarpc.com",
  )
  io.println(
    "  gleeth balance addr1 addr2 addr3 --rpc-url https://eth.llamarpc.com",
  )
  io.println(
    "  gleeth balance --file addresses.txt --rpc-url https://eth.llamarpc.com",
  )
  io.println(
    "  gleeth call 0xA0b86a33E6Fb7e4f67c5776f8fcB44F56c71d8b8 totalSupply --rpc-url https://eth.llamarpc.com",
  )
  io.println(
    "  gleeth call 0xA0b86a33E6Fb7e4f67c5776f8fcB44F56c71d8b8 balanceOf address:0x742d... --rpc-url https://eth.llamarpc.com",
  )
  io.println(
    "  gleeth send --to 0x7099... --value 0xde0b6b3a7640000 --private-key 0xac09... --rpc-url http://localhost:8545",
  )
  io.println(
    "  gleeth estimate-gas --from 0x742d... --to 0x7a25... --value 0x1000... --rpc-url https://eth.llamarpc.com",
  )
  io.println(
    "  gleeth storage-at --address 0xA0b86a... --slot 0x0 --rpc-url https://eth.llamarpc.com",
  )
  io.println(
    "  gleeth get-logs --address 0xA0b86a... --from-block 0x1000000 --rpc-url https://eth.llamarpc.com",
  )
  io.println("")
  io.println("SEND OPTIONS:")
  io.println("  --to <address>                 Recipient address (required)")
  io.println(
    "  --value <hex>                  Wei amount to send (hex, e.g. 0xde0b6b3a7640000 for 1 ETH)",
  )
  io.println("  --private-key <hex>            Sender's private key (required)")
  io.println(
    "  --gas-limit <hex>              Gas limit (optional, defaults to 21000)",
  )
  io.println("  --data <hex>                   Transaction data (optional)")
  io.println(
    "  --legacy                       Use legacy (Type 0) instead of EIP-1559",
  )
  io.println("")
  io.println("WALLET COMMANDS:")
  io.println("  gleeth wallet create --private-key 0x1234...")
  io.println("  gleeth wallet generate")
  io.println("  gleeth wallet info --private-key 0x1234...")
  io.println(
    "  gleeth wallet sign --private-key 0x1234... --message 'Hello World'",
  )
  io.println("")
  io.println("ADDITIONAL QUERY COMMANDS:")
  io.println(
    "  chain-id                        Get chain ID of connected network",
  )
  io.println(
    "  gas-price                       Get current gas price and priority fee",
  )
  io.println(
    "  fee-history --block-count <n>   Get fee history for recent blocks",
  )
  io.println(
    "  nonce <address>                 Get transaction count (nonce) for address",
  )
  io.println("  receipt <hash>                  Get transaction receipt")
  io.println(
    "  wait <hash>                     Wait for transaction to be mined",
  )
  io.println("")
  io.println("FEE-HISTORY OPTIONS:")
  io.println(
    "  --block-count <n>              Number of blocks to query (required)",
  )
  io.println(
    "  --newest-block <block>         Newest block (optional, defaults to 'latest')",
  )
  io.println(
    "  --percentiles <p1,p2,...>       Reward percentiles (optional, e.g. 25,50,75)",
  )
  io.println("")
  io.println("NONCE OPTIONS:")
  io.println(
    "  --block <pending|latest>       Block tag (optional, defaults to 'pending')",
  )
  io.println("")
  io.println("WAIT OPTIONS:")
  io.println(
    "  --timeout <ms>                 Timeout in milliseconds (optional, defaults to 60000)",
  )
  io.println("")
  io.println("OFFLINE COMMANDS (no RPC needed):")
  io.println("  recover [OPTIONS] <msg> <sig>   Recover signer from signature")
  io.println("  checksum <address>              Get EIP-55 checksummed address")
  io.println(
    "  convert <value> --from <unit> --to <unit>  Convert between wei/gwei/ether",
  )
  io.println(
    "  decode-tx <raw-hex>             Decode a signed raw transaction",
  )
  io.println("  decode-calldata <hex> [OPTIONS]  Decode contract calldata")
  io.println("  decode-revert <hex> [--abi <f>]  Decode revert reason")
  io.println(
    "  selector <signature> [--event]  Compute function selector or event topic",
  )
  io.println("  keccak <input> [--hex]          Compute keccak256 hash")
  io.println("  encode-calldata <sig> [params]  Encode function calldata")
  io.println(
    "  4byte <selector>                Look up function signatures (4byte.directory)",
  )
  io.println(
    "  abi <address> [--chain <name>]  Look up verified ABI (Sourcify)",
  )
  io.println("")
  io.println("RECOVER OPTIONS:")
  io.println(
    "  --mode <MODE>                  pubkey|address|candidates|verify:<addr>",
  )
  io.println("  --format <FORMAT>              compact|detailed|json")
  io.println("")
  io.println("DECODE-CALLDATA OPTIONS:")
  io.println(
    "  --signature <sig>              Function signature (e.g. transfer(address,uint256))",
  )
  io.println(
    "  --abi <file>                   JSON ABI file (alternative to --signature)",
  )
  io.println("  --function <name>              Function name (used with --abi)")
}
