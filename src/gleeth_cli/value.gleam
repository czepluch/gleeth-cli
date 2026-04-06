import gleam/int
import gleam/result
import gleam/string
import gleeth/utils/hex
import gleeth/wei

/// Parse a value string with optional unit suffix into a hex wei string.
///
/// Supported formats:
/// - `"1ether"` / `"1eth"` - ether amount
/// - `"10gwei"` - gwei amount
/// - `"21000wei"` - wei amount (decimal)
/// - `"21000"` - plain decimal (treated as wei)
/// - `"0xde0b6b3a7640000"` - hex (passed through as-is)
pub fn parse_value(s: String) -> Result(String, String) {
  let lower = string.lowercase(s)
  case string.starts_with(lower, "0x") {
    True -> Ok(s)
    False -> {
      case string.ends_with(lower, "ether") {
        True -> {
          let amount = string.drop_end(s, 5)
          wei.from_ether(amount)
        }
        False ->
          case string.ends_with(lower, "eth") {
            True -> {
              let amount = string.drop_end(s, 3)
              wei.from_ether(amount)
            }
            False ->
              case string.ends_with(lower, "gwei") {
                True -> {
                  let amount = string.drop_end(s, 4)
                  wei.from_gwei(amount)
                }
                False ->
                  case string.ends_with(lower, "wei") {
                    True -> {
                      let amount = string.drop_end(s, 3)
                      parse_decimal_wei(amount)
                    }
                    False -> parse_decimal_wei(s)
                  }
              }
          }
      }
    }
  }
}

/// Parse a decimal string as wei and return hex.
fn parse_decimal_wei(s: String) -> Result(String, String) {
  case int.parse(s) {
    Ok(n) -> Ok(hex.from_int(n))
    Error(_) -> Error("Invalid value: " <> s)
  }
}

/// Resolve a chain name to its chain ID.
pub fn chain_name_to_id(name: String) -> Result(Int, String) {
  case string.lowercase(name) {
    "mainnet" | "ethereum" -> Ok(1)
    "sepolia" -> Ok(11_155_111)
    "goerli" -> Ok(5)
    "holesky" -> Ok(17_000)
    "arbitrum" | "arbitrum-one" -> Ok(42_161)
    "arbitrum-sepolia" -> Ok(421_614)
    "optimism" | "op" -> Ok(10)
    "optimism-sepolia" | "op-sepolia" -> Ok(11_155_420)
    "base" -> Ok(8453)
    "base-sepolia" -> Ok(84_532)
    "polygon" | "matic" -> Ok(137)
    "polygon-amoy" -> Ok(80_002)
    "avalanche" | "avax" -> Ok(43_114)
    "bsc" | "bnb" -> Ok(56)
    "gnosis" -> Ok(100)
    "linea" -> Ok(59_144)
    "zksync" | "zksync-era" -> Ok(324)
    "scroll" -> Ok(534_352)
    _ ->
      Error(
        "Unknown chain: "
        <> name
        <> ". Supported: mainnet, sepolia, holesky, arbitrum, optimism, base, polygon, avalanche, bsc, gnosis, linea, zksync, scroll",
      )
  }
}

/// Resolve a chain name to its chain ID as a string.
pub fn chain_id_string(name: String) -> Result(String, String) {
  use id <- result.try(chain_name_to_id(name))
  Ok(int.to_string(id))
}
