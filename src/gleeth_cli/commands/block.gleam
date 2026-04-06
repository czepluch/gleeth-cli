import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex
import gleeth_cli/formatting

/// Get block by number or hash
pub fn execute(
  provider: Provider,
  block_id: String,
  json_output: Bool,
) -> Result(Nil, rpc_types.GleethError) {
  use block <- result.try(case is_block_hash(block_id) {
    True -> methods.get_block_by_hash(provider, block_id)
    False -> methods.get_block_by_number(provider, block_id)
  })

  case json_output {
    True -> {
      let json_str =
        json.object([
          #("number", json.string(block.number)),
          #("hash", json.string(block.hash)),
          #("parent_hash", json.string(block.parent_hash)),
          #("timestamp", json.string(block.timestamp)),
          #("gas_limit", json.string(block.gas_limit)),
          #("gas_used", json.string(block.gas_used)),
          #("transactions", json.array(block.transactions, json.string)),
        ])
        |> json.to_string
      io.println(json_str)
    }
    False -> {
      io.println("Block:")
      formatting.print_labeled_value(
        "Number",
        hex.format_block_number(block.number)
          <> " ("
          <> hex.normalize(block.number)
          <> ")",
      )
      formatting.print_labeled_value("Hash", block.hash)
      formatting.print_labeled_value("Parent Hash", block.parent_hash)
      case hex.to_int(block.timestamp) {
        Ok(ts) -> formatting.print_labeled_value("Timestamp", int.to_string(ts))
        Error(_) -> formatting.print_labeled_value("Timestamp", block.timestamp)
      }
      formatting.print_labeled_value("Gas Limit", block.gas_limit)
      formatting.print_labeled_value("Gas Used", block.gas_used)
      formatting.print_labeled_value(
        "Transactions",
        int.to_string(list.length(block.transactions)),
      )
    }
  }
  Ok(Nil)
}

/// Check if a string looks like a block hash (66 char hex) vs a block number
fn is_block_hash(s: String) -> Bool {
  string.starts_with(s, "0x") && string.length(s) == 66
}
