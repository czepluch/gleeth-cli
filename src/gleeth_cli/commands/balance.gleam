import gleam/io
import gleam/json
import gleam/option.{type Option, None}
import gleam/result
import gleeth/ethereum/types as eth_types
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth_cli/commands/parallel_balance
import gleeth_cli/formatting

/// Execute balance command - handles both single and multiple addresses
pub fn execute(
  provider: Provider,
  addresses: List(eth_types.Address),
  file: Option(String),
  json json_output: Bool,
) -> Result(Nil, rpc_types.GleethError) {
  case addresses, file {
    [single_address], None -> {
      // Single address
      use balance <- result.try(methods.get_balance(provider, single_address))
      case json_output {
        True -> {
          json.object([
            #("address", json.string(single_address)),
            #("balance", json.string(balance)),
          ])
          |> json.to_string
          |> io.println
        }
        False -> formatting.print_balance(single_address, balance)
      }
      Ok(Nil)
    }
    _, _ -> {
      // Multiple addresses or file input - use parallel processing
      parallel_balance.execute_parallel(provider, addresses, file)
    }
  }
}
