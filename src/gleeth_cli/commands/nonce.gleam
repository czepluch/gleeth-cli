import gleam/result
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth_cli/formatting

/// Execute nonce command
pub fn execute(
  provider: Provider,
  address: String,
  block: String,
) -> Result(Nil, rpc_types.GleethError) {
  use nonce <- result.try(methods.get_transaction_count(
    provider,
    address,
    block,
  ))
  formatting.print_labeled_value("Address", address)
  formatting.format_hex_with_decimal(nonce, "Nonce")
  Ok(Nil)
}
