import gleam/result
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth_cli/formatting

/// Execute chain ID command
pub fn execute(provider: Provider) -> Result(Nil, rpc_types.GleethError) {
  use chain_id_hex <- result.try(methods.get_chain_id(provider))
  formatting.format_hex_with_decimal(chain_id_hex, "Chain ID")
  Ok(Nil)
}
