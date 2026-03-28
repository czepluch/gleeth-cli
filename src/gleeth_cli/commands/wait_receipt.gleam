import gleam/io
import gleam/result
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth_cli/commands/receipt

/// Execute wait for receipt command
pub fn execute(
  provider: Provider,
  hash: String,
  timeout: Int,
) -> Result(Nil, rpc_types.GleethError) {
  io.println("Waiting for transaction " <> hash <> "...")
  use r <- result.try(methods.wait_for_receipt_with_timeout(
    provider,
    hash,
    timeout,
  ))
  receipt.print_receipt(r)
  Ok(Nil)
}
