import gleam/int
import gleam/io
import gleam/list
import gleeth/crypto/transaction
import gleeth_cli/formatting

/// Decode and display a raw signed transaction
pub fn execute(raw_hex: String) -> Result(Nil, String) {
  case transaction.decode(raw_hex) {
    Ok(decoded) -> {
      print_decoded(decoded)
      Ok(Nil)
    }
    Error(err) -> Error(transaction.error_to_string(err))
  }
}

fn print_decoded(decoded: transaction.DecodedTransaction) -> Nil {
  case decoded {
    transaction.DecodedLegacy(tx) -> {
      io.println("Decoded Legacy Transaction (Type 0):")
      formatting.print_labeled_value("To", tx.to)
      formatting.print_labeled_value("Value", tx.value)
      formatting.print_labeled_value("Gas Limit", tx.gas_limit)
      formatting.print_labeled_value("Gas Price", tx.gas_price)
      formatting.print_labeled_value("Nonce", tx.nonce)
      formatting.print_labeled_value("Chain ID", int.to_string(tx.chain_id))
      case tx.data {
        "" | "0x" -> Nil
        d -> formatting.print_labeled_value("Data", d)
      }
      io.println("")
      io.println("Signature:")
      formatting.print_labeled_value("v", tx.v)
      formatting.print_labeled_value("r", tx.r)
      formatting.print_labeled_value("s", tx.s)
    }
    transaction.DecodedEip1559(tx) -> {
      io.println("Decoded EIP-1559 Transaction (Type 2):")
      formatting.print_labeled_value("To", tx.to)
      formatting.print_labeled_value("Value", tx.value)
      formatting.print_labeled_value("Gas Limit", tx.gas_limit)
      formatting.print_labeled_value("Max Fee Per Gas", tx.max_fee_per_gas)
      formatting.print_labeled_value(
        "Max Priority Fee",
        tx.max_priority_fee_per_gas,
      )
      formatting.print_labeled_value("Nonce", tx.nonce)
      formatting.print_labeled_value("Chain ID", int.to_string(tx.chain_id))
      case tx.data {
        "" | "0x" -> Nil
        d -> formatting.print_labeled_value("Data", d)
      }
      case list.is_empty(tx.access_list) {
        True -> Nil
        False -> {
          io.println("")
          io.println("Access List:")
          list.each(tx.access_list, fn(entry) {
            formatting.print_labeled_value("  Address", entry.address)
            list.each(entry.storage_keys, fn(key) {
              formatting.print_labeled_value("    Key", key)
            })
          })
        }
      }
      io.println("")
      io.println("Signature:")
      formatting.print_labeled_value("v", tx.v)
      formatting.print_labeled_value("r", tx.r)
      formatting.print_labeled_value("s", tx.s)
    }
  }
}
