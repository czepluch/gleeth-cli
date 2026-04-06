import gleam/io
import gleam/json
import gleam/result
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex
import gleeth_cli/formatting

/// Execute gas price command
pub fn execute(
  provider: Provider,
  json json: Bool,
) -> Result(Nil, rpc_types.GleethError) {
  use gas_price <- result.try(methods.get_gas_price(provider))
  use priority_fee <- result.try(methods.get_max_priority_fee(provider))
  case json {
    True -> {
      json.object([
        #("gas_price", json.string(gas_price)),
        #("max_priority_fee", json.string(priority_fee)),
      ])
      |> json.to_string
      |> io.println
    }
    False -> {
      formatting.print_labeled_value(
        "Gas Price",
        hex.format_wei_to_gwei(gas_price)
          <> " ("
          <> hex.normalize(gas_price)
          <> ")",
      )
      formatting.print_labeled_value(
        "Max Priority Fee",
        hex.format_wei_to_gwei(priority_fee)
          <> " ("
          <> hex.normalize(priority_fee)
          <> ")",
      )
    }
  }
  Ok(Nil)
}
