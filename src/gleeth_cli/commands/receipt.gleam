import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleeth/ethereum/types as eth_types
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth_cli/formatting

/// Execute receipt command
pub fn execute(
  provider: Provider,
  hash: String,
) -> Result(Nil, rpc_types.GleethError) {
  use receipt <- result.try(methods.get_transaction_receipt(provider, hash))
  print_receipt(receipt)
  Ok(Nil)
}

/// Print formatted transaction receipt
pub fn print_receipt(receipt: eth_types.TransactionReceipt) -> Nil {
  io.println("Transaction Receipt:")
  formatting.print_labeled_value("Hash", receipt.transaction_hash)
  formatting.print_labeled_value("Status", case receipt.status {
    eth_types.Success -> "Success"
    eth_types.Failed -> "Failed"
  })
  formatting.print_labeled_value("Block Number", receipt.block_number)
  formatting.print_labeled_value("Block Hash", receipt.block_hash)
  formatting.print_labeled_value("Transaction Index", receipt.transaction_index)
  formatting.print_labeled_value("From", receipt.from)
  formatting.print_labeled_value("To", receipt.to)
  formatting.print_labeled_value("Gas Used", receipt.gas_used)
  formatting.print_labeled_value(
    "Cumulative Gas Used",
    receipt.cumulative_gas_used,
  )
  formatting.print_labeled_value(
    "Effective Gas Price",
    receipt.effective_gas_price,
  )
  case receipt.contract_address {
    "" -> Nil
    addr -> formatting.print_labeled_value("Contract Address", addr)
  }
  case list.is_empty(receipt.logs) {
    True -> Nil
    False -> {
      io.println("")
      io.println("Logs (" <> int.to_string(list.length(receipt.logs)) <> "):")
      list.index_map(receipt.logs, fn(log, i) {
        io.println("  Log #" <> int.to_string(i) <> ":")
        formatting.print_labeled_value("    Address", log.address)
        formatting.print_labeled_value("    Data", log.data)
        list.index_map(log.topics, fn(topic, j) {
          formatting.print_labeled_value(
            "    Topic " <> int.to_string(j),
            topic,
          )
        })
      })
      Nil
    }
  }
}
