import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex
import gleeth_cli/formatting

/// Execute fee history command
pub fn execute(
  provider: Provider,
  block_count: Int,
  newest_block: String,
  percentiles: List(Float),
) -> Result(Nil, rpc_types.GleethError) {
  use history <- result.try(methods.get_fee_history(
    provider,
    block_count,
    newest_block,
    percentiles,
  ))
  io.println("Fee History:")
  formatting.print_labeled_value(
    "Oldest Block",
    hex.format_block_number(history.oldest_block),
  )
  io.println("")

  // Print base fees and gas used ratios
  list.index_map(history.base_fee_per_gas, fn(fee, i) {
    let block_label = "Block +" <> int.to_string(i)
    formatting.print_labeled_value(
      block_label <> " Base Fee",
      hex.format_wei_to_gwei(fee),
    )
  })

  case list.is_empty(history.gas_used_ratio) {
    True -> Nil
    False -> {
      io.println("")
      io.println("Gas Used Ratios:")
      list.index_map(history.gas_used_ratio, fn(ratio, i) {
        formatting.print_labeled_value(
          "Block +" <> int.to_string(i),
          float.to_string(ratio *. 100.0) <> "%",
        )
      })
      Nil
    }
  }

  case list.is_empty(history.reward) {
    True -> Nil
    False -> {
      io.println("")
      io.println("Reward Percentiles:")
      list.index_map(history.reward, fn(rewards, i) {
        let formatted = list.map(rewards, hex.format_wei_to_gwei)
        formatting.print_labeled_value(
          "Block +" <> int.to_string(i),
          string.join(formatted, ", "),
        )
      })
      Nil
    }
  }
  Ok(Nil)
}
