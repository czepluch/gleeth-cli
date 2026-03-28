import gleam/int
import gleam/io
import gleam/result
import gleam/string
import gleeth/utils/hex
import gleeth/wei

/// Convert between Ethereum units (wei, gwei, ether)
pub fn execute(
  value: String,
  from_unit: String,
  to_unit: String,
) -> Result(Nil, String) {
  use result <- result.try(convert(value, from_unit, to_unit))
  io.println(value <> " " <> from_unit <> " = " <> result <> " " <> to_unit)
  Ok(Nil)
}

fn convert(
  value: String,
  from_unit: String,
  to_unit: String,
) -> Result(String, String) {
  // First convert to wei hex as intermediate
  use wei_hex <- result.try(to_wei(value, from_unit))
  // Then convert from wei to target unit
  from_wei(wei_hex, to_unit)
}

fn to_wei(value: String, unit: String) -> Result(String, String) {
  case string.lowercase(unit) {
    "wei" -> {
      // Accept decimal or hex
      case string.starts_with(value, "0x") {
        True -> Ok(value)
        False -> {
          case int.parse(value) {
            Ok(n) -> Ok(hex.from_int(n))
            Error(_) -> Error("Invalid wei value: " <> value)
          }
        }
      }
    }
    "gwei" -> wei.from_gwei(value)
    "ether" | "eth" -> wei.from_ether(value)
    _ -> Error("Unknown unit: " <> unit <> ". Valid units: wei, gwei, ether")
  }
}

fn from_wei(wei_hex: String, unit: String) -> Result(String, String) {
  case string.lowercase(unit) {
    "wei" -> {
      case hex.to_int(wei_hex) {
        Ok(n) -> Ok(int.to_string(n))
        Error(_) -> Ok(wei_hex)
      }
    }
    "gwei" -> wei.to_gwei(wei_hex)
    "ether" | "eth" -> wei.to_ether(wei_hex)
    _ -> Error("Unknown unit: " <> unit <> ". Valid units: wei, gwei, ether")
  }
}
