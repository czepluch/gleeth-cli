import gleam/io
import gleam/json
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
  json output_json: Bool,
) -> Result(Nil, rpc_types.GleethError) {
  case output_json {
    False -> io.println("Waiting for transaction " <> hash <> "...")
    True -> Nil
  }
  use r <- result.try(methods.wait_for_receipt_with_timeout(
    provider,
    hash,
    timeout,
  ))
  case output_json {
    True -> io.println(receipt.receipt_to_json(r) |> json.to_string)
    False -> receipt.print_receipt(r)
  }
  Ok(Nil)
}
