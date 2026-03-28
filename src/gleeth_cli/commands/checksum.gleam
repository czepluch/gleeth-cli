import gleam/io
import gleeth/ethereum/address

/// Compute and display EIP-55 checksummed address
pub fn execute(addr: String) -> Result(Nil, String) {
  case address.checksum(addr) {
    Ok(checksummed) -> {
      let was_valid = address.is_valid_checksum(addr)
      io.println("Address:")
      io.println("  Input:      " <> addr)
      io.println("  Checksummed: " <> checksummed)
      case was_valid {
        True -> io.println("  Input was already correctly checksummed")
        False -> Nil
      }
      Ok(Nil)
    }
    Error(msg) -> Error(msg)
  }
}
