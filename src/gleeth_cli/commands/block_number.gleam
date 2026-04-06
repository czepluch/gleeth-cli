import gleam/io
import gleam/json
import gleam/result
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth_cli/formatting

/// Execute block number command
pub fn execute(
  provider: Provider,
  json json: Bool,
) -> Result(Nil, rpc_types.GleethError) {
  use block_number <- result.try(methods.get_block_number(provider))
  case json {
    True -> {
      json.object([#("block_number", json.string(block_number))])
      |> json.to_string
      |> io.println
    }
    False -> formatting.print_block_number(block_number)
  }
  Ok(Nil)
}
