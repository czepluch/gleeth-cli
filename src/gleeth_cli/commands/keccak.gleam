import gleam/io
import gleeth/crypto/keccak
import gleeth/utils/hex

/// Compute keccak256 hash of input data
pub fn execute(input: String, is_hex: Bool) -> Result(Nil, String) {
  case is_hex {
    True -> {
      case hex.decode(input) {
        Ok(bytes) -> {
          let hash = keccak.hash_binary_to_hex(keccak.keccak256_binary(bytes))
          io.println(hash)
          Ok(Nil)
        }
        Error(_) -> Error("Invalid hex input: " <> input)
      }
    }
    False -> {
      let hash = keccak.keccak256_hex(input)
      io.println(hash)
      Ok(Nil)
    }
  }
}
