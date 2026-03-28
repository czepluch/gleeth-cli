import gleam/bit_array
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleeth/ethereum/abi/decode as abi_decode
import gleeth/ethereum/abi/json as abi_json
import gleeth/ethereum/abi/types as abi_types
import simplifile

/// Decode and display revert reason data
pub fn execute(data: String, abi_file: Option(String)) -> Result(Nil, String) {
  let decode_result = case abi_file {
    Some(file) -> {
      use json_str <- result.try(
        simplifile.read(file)
        |> result.map_error(fn(_) {
          abi_types.InvalidAbiJson("Cannot read ABI file: " <> file)
        }),
      )
      use entries <- result.try(abi_json.parse_abi(json_str))
      abi_decode.decode_revert_with_abi(data, entries)
    }
    None -> abi_decode.decode_revert(data)
  }

  case decode_result {
    Ok(decoded) -> {
      print_decoded_revert(decoded)
      Ok(Nil)
    }
    Error(err) -> Error(abi_error_to_string(err))
  }
}

fn print_decoded_revert(decoded: abi_decode.DecodedRevert) -> Nil {
  io.println("Revert Reason:")
  case decoded {
    abi_decode.RevertString(msg) -> {
      io.println("  Type: Error(string)")
      io.println("  Message: " <> msg)
    }
    abi_decode.RevertPanic(code) -> {
      io.println("  Type: Panic(uint256)")
      io.println("  Code: " <> int.to_string(code))
      io.println("  Meaning: " <> panic_code_meaning(code))
    }
    abi_decode.RevertCustomError(name, arguments) -> {
      io.println("  Type: Custom Error")
      io.println("  Name: " <> name)
      case list.is_empty(arguments) {
        True -> Nil
        False -> {
          io.println("  Arguments:")
          list.each(arguments, fn(arg) {
            io.println("    " <> string.inspect(arg))
          })
        }
      }
    }
    abi_decode.RevertUnknown(raw) -> {
      io.println("  Type: Unknown")
      io.println("  Raw: 0x" <> string.lowercase(bit_array.base16_encode(raw)))
    }
  }
}

fn panic_code_meaning(code: Int) -> String {
  case code {
    0x00 -> "Generic compiler panic"
    0x01 -> "Assert failed"
    0x11 -> "Arithmetic overflow/underflow"
    0x12 -> "Division or modulo by zero"
    0x21 -> "Conversion to invalid enum value"
    0x22 -> "Incorrectly encoded storage byte array"
    0x31 -> "pop() on empty array"
    0x32 -> "Array index out of bounds"
    0x41 -> "Too much memory allocated"
    0x51 -> "Called zero-initialized function pointer"
    _ -> "Unknown panic code"
  }
}

fn abi_error_to_string(err: abi_types.AbiError) -> String {
  case err {
    abi_types.TypeParseError(msg) -> msg
    abi_types.EncodeError(msg) -> msg
    abi_types.DecodeError(msg) -> msg
    abi_types.InvalidAbiJson(msg) -> msg
  }
}
