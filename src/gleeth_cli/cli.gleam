import clip
import clip/arg
import clip/flag
import clip/help
import clip/opt
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

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Main entry point: parse a list of CLI arguments into Args using clip.
pub fn run(args: List(String)) -> Result(Args, String) {
  // Handle special cases before clip parsing
  case args {
    [] | ["help"] | ["--help"] | ["-h"] -> Ok(Args(Help, "", False))
    // Per-command help: gleeth <command> --help
    [_, "--help"] | [_, "-h"] -> {
      case clip.run(cli_command(), args) {
        // clip returns help text as Error - return it as CommandHelp
        Error(help_text) ->
          Ok(Args(CommandHelp(clean_help_text(help_text)), "", False))
        Ok(Ok(parsed)) -> Ok(parsed)
        Ok(Error(msg)) -> Error(msg)
      }
    }
    ["wallet", ..wallet_args] -> Ok(Args(Wallet(wallet_args), "", False))
    ["recover", ..recover_args] -> Ok(Args(Recover(recover_args), "", False))
    _ -> {
      case clip.run(cli_command(), args) {
        Ok(Ok(parsed)) -> Ok(parsed)
        Ok(Error(msg)) -> Error(msg)
        Error(msg) -> Error(msg)
      }
    }
  }
}

/// Backward-compatible wrapper that maps String errors to GleethError.
pub fn parse_args(args: List(String)) -> Result(Args, rpc_types.GleethError) {
  run(args)
  |> result.map_error(rpc_types.ConfigError)
}

/// Resolve --rpc-url / --chain to a URL.
/// Both are optional; exactly one should be provided, or GLEETH_RPC_URL is used.
pub fn resolve_rpc(
  rpc_url: Result(String, Nil),
  chain: Result(String, Nil),
) -> Result(String, String) {
  case rpc_url, chain {
    Ok(url), _ -> Ok(url)
    _, Ok(name) -> resolve_chain_rpc(name)
    Error(_), Error(_) ->
      case get_env("GLEETH_RPC_URL") {
        Ok(url) -> Ok(url)
        Error(_) ->
          Error(
            "RPC URL required. Use --rpc-url, --chain <name>, or set GLEETH_RPC_URL.",
          )
      }
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

// ---------------------------------------------------------------------------
// Shared option builders
// ---------------------------------------------------------------------------

/// Optional --rpc-url
fn rpc_url_opt() -> opt.Opt(Result(String, Nil)) {
  opt.new("rpc-url")
  |> opt.help("RPC endpoint URL")
  |> opt.optional
}

/// Optional --chain
fn chain_opt() -> opt.Opt(Result(String, Nil)) {
  opt.new("chain")
  |> opt.help("Chain name (resolves via GLEETH_RPC_<CHAIN> env var)")
  |> opt.optional
}

/// --json flag
fn json_flag() -> flag.Flag {
  flag.new("json")
  |> flag.help("Output as JSON")
}

/// Build Args for an RPC command.
fn make_rpc_args(
  rpc_url: Result(String, Nil),
  chain: Result(String, Nil),
  json: Bool,
  command: Command,
) -> Result(Args, String) {
  use url <- result.try(resolve_rpc(rpc_url, chain))
  Ok(Args(command, url, json))
}

/// Build Args for an offline command (no RPC needed).
fn offline_args(command: Command) -> Result(Args, String) {
  Ok(Args(command, "", False))
}

/// Convert Result(a, Nil) to Option(a).
fn to_option(r: Result(a, Nil)) -> Option(a) {
  option.from_result(r)
}

// ---------------------------------------------------------------------------
// Top-level command
// ---------------------------------------------------------------------------

fn cli_command() -> clip.Command(Result(Args, String)) {
  clip.subcommands_with_default(
    [
      #("block-number", block_number_cmd()),
      #("block", block_cmd()),
      #("balance", balance_cmd()),
      #("call", call_cmd()),
      #("transaction", transaction_cmd()),
      #("code", code_cmd()),
      #("estimate-gas", estimate_gas_cmd()),
      #("storage-at", storage_at_cmd()),
      #("get-logs", get_logs_cmd()),
      #("send", send_cmd()),
      #("chain-id", chain_id_cmd()),
      #("gas-price", gas_price_cmd()),
      #("fee-history", fee_history_cmd()),
      #("nonce", nonce_cmd()),
      #("receipt", receipt_cmd()),
      #("wait", wait_cmd()),
      #("checksum", checksum_cmd()),
      #("convert", convert_cmd()),
      #("decode-tx", decode_tx_cmd()),
      #("decode-calldata", decode_calldata_cmd()),
      #("decode-revert", decode_revert_cmd()),
      #("selector", selector_cmd()),
      #("keccak", keccak_cmd()),
      #("encode-calldata", encode_calldata_cmd()),
      #("4byte", four_byte_cmd()),
      #("abi", abi_cmd()),
      #("sign-typed-data", sign_typed_data_cmd()),
    ],
    clip.fail("Invalid command. Use --help for usage information."),
  )
}

// ---------------------------------------------------------------------------
// RPC subcommands
// ---------------------------------------------------------------------------

fn block_number_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use rpc_url <- clip.parameter
    use chain <- clip.parameter
    use json <- clip.parameter
    make_rpc_args(rpc_url, chain, json, BlockNumber)
  })
  |> clip.opt(rpc_url_opt())
  |> clip.opt(chain_opt())
  |> clip.flag(json_flag())
  |> clip.help(help.simple("block-number", "Get the latest block number"))
}

fn block_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use rpc_url <- clip.parameter
    use chain <- clip.parameter
    use json <- clip.parameter
    use block_id <- clip.parameter
    make_rpc_args(rpc_url, chain, json, Block(block_id))
  })
  |> clip.opt(rpc_url_opt())
  |> clip.opt(chain_opt())
  |> clip.flag(json_flag())
  |> clip.arg(
    arg.new("block-id")
    |> arg.help("Block number, hash, or 'latest'"),
  )
  |> clip.help(help.simple("block", "Get block details by number, hash, or tag"))
}

fn balance_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use file <- clip.parameter
    use rpc_url <- clip.parameter
    use chain <- clip.parameter
    use json <- clip.parameter
    use addresses <- clip.parameter
    use validated <- result.try(validate_balance_args(addresses, file))
    let #(addrs, f) = validated
    make_rpc_args(rpc_url, chain, json, Balance(addrs, f))
  })
  |> clip.opt(
    opt.new("file")
    |> opt.short("f")
    |> opt.help("File with one address per line")
    |> opt.optional,
  )
  |> clip.opt(rpc_url_opt())
  |> clip.opt(chain_opt())
  |> clip.flag(json_flag())
  |> clip.arg_many(
    arg.new("address")
    |> arg.help("Ethereum address(es)"),
  )
  |> clip.help(help.simple(
    "balance",
    "Get ETH balance for one or more addresses",
  ))
}

fn call_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use abi_file <- clip.parameter
    use rpc_url <- clip.parameter
    use chain <- clip.parameter
    use json <- clip.parameter
    use contract <- clip.parameter
    use function <- clip.parameter
    use parameters <- clip.parameter
    use validated_contract <- result.try(validate_address_str(contract))
    make_rpc_args(
      rpc_url,
      chain,
      json,
      Call(validated_contract, function, parameters, to_option(abi_file)),
    )
  })
  |> clip.opt(
    opt.new("abi")
    |> opt.help("JSON ABI file for typed encoding/decoding")
    |> opt.optional,
  )
  |> clip.opt(rpc_url_opt())
  |> clip.opt(chain_opt())
  |> clip.flag(json_flag())
  |> clip.arg(
    arg.new("contract")
    |> arg.help("Contract address"),
  )
  |> clip.arg(
    arg.new("function")
    |> arg.help("Function name"),
  )
  |> clip.arg_many(
    arg.new("params")
    |> arg.help("Parameters as type:value"),
  )
  |> clip.help(help.simple("call", "Call a contract function (read-only)"))
}

fn transaction_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use rpc_url <- clip.parameter
    use chain <- clip.parameter
    use json <- clip.parameter
    use hash <- clip.parameter
    use validated_hash <- result.try(validate_hash_str(hash))
    make_rpc_args(rpc_url, chain, json, Transaction(validated_hash))
  })
  |> clip.opt(rpc_url_opt())
  |> clip.opt(chain_opt())
  |> clip.flag(json_flag())
  |> clip.arg(
    arg.new("hash")
    |> arg.help("Transaction hash"),
  )
  |> clip.help(help.simple("transaction", "Get transaction details by hash"))
}

fn code_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use rpc_url <- clip.parameter
    use chain <- clip.parameter
    use json <- clip.parameter
    use address <- clip.parameter
    use validated_address <- result.try(validate_address_str(address))
    make_rpc_args(rpc_url, chain, json, Code(validated_address))
  })
  |> clip.opt(rpc_url_opt())
  |> clip.opt(chain_opt())
  |> clip.flag(json_flag())
  |> clip.arg(
    arg.new("address")
    |> arg.help("Contract address"),
  )
  |> clip.help(help.simple("code", "Get contract bytecode at an address"))
}

fn estimate_gas_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use from <- clip.parameter
    use to <- clip.parameter
    use value_str <- clip.parameter
    use data <- clip.parameter
    use rpc_url <- clip.parameter
    use chain <- clip.parameter
    use json <- clip.parameter
    let from_addr = case from {
      Ok(a) -> validate_address_str(a)
      Error(Nil) -> Ok("")
    }
    let to_addr = case to {
      Ok(a) -> validate_address_str(a)
      Error(Nil) -> Ok("")
    }
    let parsed_value = case value_str {
      Ok(v) -> value.parse_value(v)
      Error(Nil) -> Ok("")
    }
    use f <- result.try(from_addr)
    use t <- result.try(to_addr)
    use val <- result.try(parsed_value)
    let d = result.unwrap(data, "")
    make_rpc_args(rpc_url, chain, json, EstimateGas(f, t, val, d))
  })
  |> clip.opt(
    opt.new("from")
    |> opt.help("Sender address")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("to")
    |> opt.help("Recipient address")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("value")
    |> opt.help("Value (e.g. 1ether, 10gwei, 0xde0b...)")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("data")
    |> opt.help("Transaction data")
    |> opt.optional,
  )
  |> clip.opt(rpc_url_opt())
  |> clip.opt(chain_opt())
  |> clip.flag(json_flag())
  |> clip.help(help.simple("estimate-gas", "Estimate gas for a transaction"))
}

fn storage_at_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use address <- clip.parameter
    use slot <- clip.parameter
    use block <- clip.parameter
    use rpc_url <- clip.parameter
    use chain <- clip.parameter
    use json <- clip.parameter
    use validated_address <- result.try(validate_address_str(address))
    let block_tag = result.unwrap(block, "")
    make_rpc_args(
      rpc_url,
      chain,
      json,
      StorageAt(validated_address, slot, block_tag),
    )
  })
  |> clip.opt(
    opt.new("address")
    |> opt.help("Contract address (required)"),
  )
  |> clip.opt(
    opt.new("slot")
    |> opt.help("Storage slot position (required)"),
  )
  |> clip.opt(
    opt.new("block")
    |> opt.help("Block number, hash, or 'latest'")
    |> opt.optional,
  )
  |> clip.opt(rpc_url_opt())
  |> clip.opt(chain_opt())
  |> clip.flag(json_flag())
  |> clip.help(help.simple("storage-at", "Read a contract's storage slot"))
}

fn get_logs_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use from_block <- clip.parameter
    use to_block <- clip.parameter
    use address <- clip.parameter
    use topics_str <- clip.parameter
    use rpc_url <- clip.parameter
    use chain <- clip.parameter
    use json <- clip.parameter
    let fb = result.unwrap(from_block, "")
    let tb = result.unwrap(to_block, "")
    let addr = case address {
      Ok(a) -> validate_address_str(a)
      Error(Nil) -> Ok("")
    }
    let topics = case topics_str {
      Ok(s) -> parse_topic_list(s)
      Error(Nil) -> []
    }
    use validated_addr <- result.try(addr)
    make_rpc_args(rpc_url, chain, json, GetLogs(fb, tb, validated_addr, topics))
  })
  |> clip.opt(
    opt.new("from-block")
    |> opt.help("Starting block")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("to-block")
    |> opt.help("Ending block")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("address")
    |> opt.help("Contract address to filter")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("topic")
    |> opt.help("Topic filter (comma-separated for multiple)")
    |> opt.optional,
  )
  |> clip.opt(rpc_url_opt())
  |> clip.opt(chain_opt())
  |> clip.flag(json_flag())
  |> clip.help(help.simple("get-logs", "Query event logs with filtering"))
}

fn send_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use to <- clip.parameter
    use value_str <- clip.parameter
    use private_key <- clip.parameter
    use gas_limit_str <- clip.parameter
    use data <- clip.parameter
    use legacy <- clip.parameter
    use rpc_url <- clip.parameter
    use chain <- clip.parameter
    use json <- clip.parameter
    let to_addr = case to {
      Ok(a) -> validate_address_str(a)
      Error(Nil) -> Ok("")
    }
    let parsed_value = case value_str {
      Ok(v) -> value.parse_value(v)
      Error(Nil) -> Ok("")
    }
    let parsed_gas = case gas_limit_str {
      Ok(g) -> value.parse_value(g)
      Error(Nil) -> Ok("")
    }
    use t <- result.try(to_addr)
    use val <- result.try(parsed_value)
    let key = result.unwrap(private_key, "")
    use gl <- result.try(parsed_gas)
    let d = result.unwrap(data, "0x")
    make_rpc_args(rpc_url, chain, json, Send(t, val, key, gl, d, legacy))
  })
  |> clip.opt(
    opt.new("to")
    |> opt.help("Recipient address")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("value")
    |> opt.help("Amount to send (e.g. 1ether, 10gwei)")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("private-key")
    |> opt.help("Sender's private key")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("gas-limit")
    |> opt.help("Gas limit")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("data")
    |> opt.help("Transaction calldata")
    |> opt.optional,
  )
  |> clip.flag(
    flag.new("legacy")
    |> flag.help("Use legacy (Type 0) instead of EIP-1559"),
  )
  |> clip.opt(rpc_url_opt())
  |> clip.opt(chain_opt())
  |> clip.flag(json_flag())
  |> clip.help(help.simple("send", "Sign and broadcast a transaction"))
}

fn chain_id_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use rpc_url <- clip.parameter
    use chain <- clip.parameter
    use json <- clip.parameter
    make_rpc_args(rpc_url, chain, json, ChainId)
  })
  |> clip.opt(rpc_url_opt())
  |> clip.opt(chain_opt())
  |> clip.flag(json_flag())
  |> clip.help(help.simple(
    "chain-id",
    "Get the chain ID of the connected network",
  ))
}

fn gas_price_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use rpc_url <- clip.parameter
    use chain <- clip.parameter
    use json <- clip.parameter
    make_rpc_args(rpc_url, chain, json, GasPrice)
  })
  |> clip.opt(rpc_url_opt())
  |> clip.opt(chain_opt())
  |> clip.flag(json_flag())
  |> clip.help(help.simple(
    "gas-price",
    "Get current gas price and max priority fee",
  ))
}

fn fee_history_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use block_count <- clip.parameter
    use newest_block <- clip.parameter
    use percentiles_str <- clip.parameter
    use rpc_url <- clip.parameter
    use chain <- clip.parameter
    use json <- clip.parameter
    let percentiles = case percentiles_str {
      Ok(s) -> {
        case parse_float_list(s) {
          Ok(pcts) -> Ok(pcts)
          Error(_) ->
            Error(
              "Invalid percentiles: "
              <> s
              <> " (expected comma-separated floats like 25.0,50.0,75.0)",
            )
        }
      }
      Error(Nil) -> Ok([])
    }
    use pcts <- result.try(percentiles)
    let nb = result.unwrap(newest_block, "latest")
    make_rpc_args(rpc_url, chain, json, FeeHistory(block_count, nb, pcts))
  })
  |> clip.opt(
    opt.new("block-count")
    |> opt.help("Number of blocks to query (required)")
    |> opt.int,
  )
  |> clip.opt(
    opt.new("newest-block")
    |> opt.help("Start block (default: latest)")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("percentiles")
    |> opt.help("Reward percentiles, comma-separated (e.g. 25,50,75)")
    |> opt.optional,
  )
  |> clip.opt(rpc_url_opt())
  |> clip.opt(chain_opt())
  |> clip.flag(json_flag())
  |> clip.help(help.simple("fee-history", "Get fee history for recent blocks"))
}

fn nonce_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use block <- clip.parameter
    use rpc_url <- clip.parameter
    use chain <- clip.parameter
    use json <- clip.parameter
    use address <- clip.parameter
    use validated_address <- result.try(validate_address_str(address))
    let block_tag = result.unwrap(block, "pending")
    make_rpc_args(rpc_url, chain, json, Nonce(validated_address, block_tag))
  })
  |> clip.opt(
    opt.new("block")
    |> opt.help("pending or latest (default: pending)")
    |> opt.optional,
  )
  |> clip.opt(rpc_url_opt())
  |> clip.opt(chain_opt())
  |> clip.flag(json_flag())
  |> clip.arg(
    arg.new("address")
    |> arg.help("Ethereum address"),
  )
  |> clip.help(help.simple(
    "nonce",
    "Get transaction count (nonce) for an address",
  ))
}

fn receipt_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use rpc_url <- clip.parameter
    use chain <- clip.parameter
    use json <- clip.parameter
    use hash <- clip.parameter
    use validated_hash <- result.try(validate_hash_str(hash))
    make_rpc_args(rpc_url, chain, json, Receipt(validated_hash))
  })
  |> clip.opt(rpc_url_opt())
  |> clip.opt(chain_opt())
  |> clip.flag(json_flag())
  |> clip.arg(
    arg.new("hash")
    |> arg.help("Transaction hash"),
  )
  |> clip.help(help.simple("receipt", "Get a transaction receipt"))
}

fn wait_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use timeout <- clip.parameter
    use rpc_url <- clip.parameter
    use chain <- clip.parameter
    use json <- clip.parameter
    use hash <- clip.parameter
    use validated_hash <- result.try(validate_hash_str(hash))
    make_rpc_args(rpc_url, chain, json, Wait(validated_hash, timeout))
  })
  |> clip.opt(
    opt.new("timeout")
    |> opt.help("Timeout in milliseconds (default: 60000)")
    |> opt.int
    |> opt.default(60_000),
  )
  |> clip.opt(rpc_url_opt())
  |> clip.opt(chain_opt())
  |> clip.flag(json_flag())
  |> clip.arg(
    arg.new("hash")
    |> arg.help("Transaction hash"),
  )
  |> clip.help(help.simple("wait", "Wait for a transaction to be mined"))
}

// ---------------------------------------------------------------------------
// Offline subcommands
// ---------------------------------------------------------------------------

fn checksum_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use address <- clip.parameter
    offline_args(Checksum(address))
  })
  |> clip.arg(
    arg.new("address")
    |> arg.help("Ethereum address (any case)"),
  )
  |> clip.help(help.simple("checksum", "Compute EIP-55 checksummed address"))
}

fn convert_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use from_unit <- clip.parameter
    use to_unit <- clip.parameter
    use val <- clip.parameter
    offline_args(Convert(val, from_unit, to_unit))
  })
  |> clip.opt(
    opt.new("from")
    |> opt.help("Source unit: wei, gwei, ether"),
  )
  |> clip.opt(
    opt.new("to")
    |> opt.help("Target unit: wei, gwei, ether"),
  )
  |> clip.arg(
    arg.new("value")
    |> arg.help("Numeric value to convert"),
  )
  |> clip.help(help.simple("convert", "Convert between Ethereum units"))
}

fn decode_tx_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use raw_hex <- clip.parameter
    offline_args(DecodeTx(raw_hex))
  })
  |> clip.arg(
    arg.new("raw-hex")
    |> arg.help("RLP-encoded signed transaction (0x-prefixed)"),
  )
  |> clip.help(help.simple("decode-tx", "Decode a signed raw transaction"))
}

fn decode_calldata_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use signature <- clip.parameter
    use abi_file <- clip.parameter
    use function_name <- clip.parameter
    use calldata <- clip.parameter
    offline_args(DecodeCalldata(
      calldata,
      to_option(signature),
      to_option(abi_file),
      to_option(function_name),
    ))
  })
  |> clip.opt(
    opt.new("signature")
    |> opt.help("Function signature (e.g. transfer(address,uint256))")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("abi")
    |> opt.help("JSON ABI file")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("function")
    |> opt.help("Function name (used with --abi)")
    |> opt.optional,
  )
  |> clip.arg(
    arg.new("calldata")
    |> arg.help("Calldata hex string (0x-prefixed)"),
  )
  |> clip.help(help.simple(
    "decode-calldata",
    "Decode contract calldata into function name and arguments",
  ))
}

fn decode_revert_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use abi_file <- clip.parameter
    use data <- clip.parameter
    offline_args(DecodeRevert(data, to_option(abi_file)))
  })
  |> clip.opt(
    opt.new("abi")
    |> opt.help("JSON ABI file (for custom error types)")
    |> opt.optional,
  )
  |> clip.arg(
    arg.new("data")
    |> arg.help("Revert data hex string (0x-prefixed)"),
  )
  |> clip.help(help.simple(
    "decode-revert",
    "Decode revert reason from failed transaction",
  ))
}

fn selector_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use is_event <- clip.parameter
    use signature <- clip.parameter
    offline_args(Selector(signature, is_event))
  })
  |> clip.flag(
    flag.new("event")
    |> flag.help("Compute full 32-byte event topic"),
  )
  |> clip.arg(
    arg.new("signature")
    |> arg.help("Function or event signature"),
  )
  |> clip.help(help.simple(
    "selector",
    "Compute function selector or event topic",
  ))
}

fn keccak_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use is_hex <- clip.parameter
    use input <- clip.parameter
    offline_args(Keccak(input, is_hex))
  })
  |> clip.flag(
    flag.new("hex")
    |> flag.help("Treat input as hex-encoded bytes"),
  )
  |> clip.arg(
    arg.new("input")
    |> arg.help("String or hex data to hash"),
  )
  |> clip.help(help.simple("keccak", "Compute keccak256 hash"))
}

fn encode_calldata_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use signature <- clip.parameter
    use params <- clip.parameter
    offline_args(EncodeCalldata(signature, params))
  })
  |> clip.arg(
    arg.new("signature")
    |> arg.help("Function signature"),
  )
  |> clip.arg_many(
    arg.new("params")
    |> arg.help("Parameters as type:value pairs"),
  )
  |> clip.help(help.simple("encode-calldata", "Encode function calldata"))
}

fn four_byte_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use selector <- clip.parameter
    offline_args(FourByte(selector))
  })
  |> clip.arg(
    arg.new("selector")
    |> arg.help("4-byte function selector (0x-prefixed)"),
  )
  |> clip.help(help.simple(
    "4byte",
    "Look up function signatures by 4-byte selector",
  ))
}

fn abi_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use chain <- clip.parameter
    use output <- clip.parameter
    use address <- clip.parameter
    let chain_name = result.unwrap(chain, "mainnet")
    offline_args(AbiLookup(address, chain_name, to_option(output)))
  })
  |> clip.opt(
    opt.new("chain")
    |> opt.help("Chain name (default: mainnet)")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("output")
    |> opt.short("o")
    |> opt.help("Save ABI to file instead of printing")
    |> opt.optional,
  )
  |> clip.arg(
    arg.new("address")
    |> arg.help("Contract address"),
  )
  |> clip.help(help.simple(
    "abi",
    "Look up a verified contract's ABI from Sourcify",
  ))
}

fn sign_typed_data_cmd() -> clip.Command(Result(Args, String)) {
  clip.command({
    use verify_file <- clip.parameter
    use hash_file <- clip.parameter
    use signature <- clip.parameter
    use private_key <- clip.parameter
    use file <- clip.parameter
    case verify_file, hash_file {
      Ok(vf), _ -> {
        case signature {
          Ok(sig) -> offline_args(VerifyTypedData(vf, sig))
          Error(Nil) ->
            Error("sign-typed-data --verify requires --signature <sig>")
        }
      }
      _, Ok(hf) -> offline_args(HashTypedData(hf))
      _, _ -> {
        case file, private_key {
          Ok(f), Ok(key) -> offline_args(SignTypedData(f, key))
          Ok(_), Error(Nil) ->
            Error("sign-typed-data requires --private-key <key>")
          Error(Nil), _ ->
            Error(
              "sign-typed-data requires a JSON file argument, or --verify/--hash",
            )
        }
      }
    }
  })
  |> clip.opt(
    opt.new("verify")
    |> opt.help("Verify mode: JSON file to verify")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("hash")
    |> opt.help("Hash mode: JSON file to hash")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("signature")
    |> opt.help("Signature to verify (hex)")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("private-key")
    |> opt.short("k")
    |> opt.help("Private key for signing")
    |> opt.optional,
  )
  |> clip.arg(
    arg.new("file")
    |> arg.help("JSON file with EIP-712 typed data")
    |> arg.optional,
  )
  |> clip.help(help.simple(
    "sign-typed-data",
    "Sign, verify, or hash EIP-712 typed structured data",
  ))
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Validate an address string, returning a String error.
fn validate_address_str(address: String) -> Result(String, String) {
  // Allow ENS names through without validation - they'll be resolved later
  case string.contains(address, ".") && !string.starts_with(address, "0x") {
    True -> Ok(address)
    False ->
      validation.validate_address(address)
      |> result.map_error(rpc_types.error_to_string)
  }
}

/// Validate a hash string, returning a String error.
fn validate_hash_str(hash: String) -> Result(String, String) {
  validation.validate_hash(hash)
  |> result.map_error(rpc_types.error_to_string)
}

/// Validate balance args: must have addresses or a file.
fn validate_balance_args(
  addresses: List(String),
  file: Result(String, Nil),
) -> Result(#(List(String), Option(String)), String) {
  case file {
    Ok(f) -> Ok(#([], Some(f)))
    Error(Nil) -> {
      case addresses {
        [] -> Error("At least one address or --file must be specified")
        _ -> {
          // Validate each address, allowing ENS names through
          list.try_map(addresses, validate_address_str)
          |> result.map(fn(addrs) { #(addrs, None) })
        }
      }
    }
  }
}

/// Parse comma-separated topic list.
fn parse_topic_list(s: String) -> List(String) {
  s
  |> string.split(",")
  |> list.map(string.trim)
  |> list.filter(fn(t) { t != "" })
}

/// Parse comma-separated float list.
fn parse_float_list(s: String) -> Result(List(Float), Nil) {
  s
  |> string.split(",")
  |> list.try_map(fn(part) {
    let trimmed = string.trim(part)
    case float.parse(trimmed) {
      Ok(f) -> Ok(f)
      Error(_) -> {
        case int.parse(trimmed) {
          Ok(i) -> Ok(int.to_float(i))
          Error(_) -> Error(Nil)
        }
      }
    }
  })
}

/// Resolve a chain name to an RPC URL.
fn resolve_chain_rpc(name: String) -> Result(String, String) {
  let env_key = "GLEETH_RPC_" <> string.uppercase(name)
  case get_env(env_key) {
    Ok(url) -> Ok(url)
    Error(_) ->
      case string.lowercase(name) {
        "mainnet" | "ethereum" -> Ok("https://eth.llamarpc.com")
        "sepolia" -> Ok("https://ethereum-sepolia.publicnode.com")
        _ ->
          Error(
            "No RPC URL for chain '"
            <> name
            <> "'. Set "
            <> env_key
            <> " or use --rpc-url.",
          )
      }
  }
}

/// Clean up clip's auto-generated help text for display.
/// Removes ugly default representations like "(default: Error(Nil))".
fn clean_help_text(text: String) -> String {
  text
  |> string.replace(" (default: Error(Nil))", "")
  |> string.replace(" (default: \"\")", "")
  |> string.replace(" (default: )", "")
}

@external(erlang, "gleeth_ffi", "get_env")
fn get_env(name: String) -> Result(String, Nil)
