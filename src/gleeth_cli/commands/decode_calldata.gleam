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

/// Decode contract calldata and display arguments
pub fn execute(
  calldata: String,
  signature: Option(String),
  abi_file: Option(String),
  function_name: Option(String),
) -> Result(Nil, String) {
  case signature, abi_file {
    Some(sig), _ -> decode_with_signature(calldata, sig)
    _, Some(file) -> decode_with_abi(calldata, file, function_name)
    None, None -> Error("Either --signature or --abi must be provided")
  }
}

fn decode_with_signature(
  calldata: String,
  signature: String,
) -> Result(Nil, String) {
  case abi_decode.decode_function_input(signature, calldata) {
    Ok(values) -> {
      io.println("Decoded Calldata:")
      io.println("  Function: " <> signature)
      io.println("  Arguments:")
      list.index_map(values, fn(value, i) {
        io.println(
          "    [" <> int.to_string(i) <> "] " <> format_abi_value(value),
        )
      })
      Ok(Nil)
    }
    Error(err) -> Error(abi_error_to_string(err))
  }
}

fn decode_with_abi(
  calldata: String,
  abi_file: String,
  _function_name: Option(String),
) -> Result(Nil, String) {
  use json_str <- result.try(
    simplifile.read(abi_file)
    |> result.map_error(fn(_) { "Cannot read ABI file: " <> abi_file }),
  )
  use entries <- result.try(
    abi_json.parse_abi(json_str)
    |> result.map_error(abi_error_to_string),
  )
  case abi_decode.decode_calldata(calldata, entries) {
    Ok(decoded) -> {
      io.println("Decoded Calldata:")
      io.println("  Function: " <> decoded.function_name)
      io.println("  Arguments:")
      list.index_map(decoded.arguments, fn(value, i) {
        io.println(
          "    [" <> int.to_string(i) <> "] " <> format_abi_value(value),
        )
      })
      Ok(Nil)
    }
    Error(err) -> Error(abi_error_to_string(err))
  }
}

/// Format an ABI value for display
pub fn format_abi_value(value: abi_types.AbiValue) -> String {
  case value {
    abi_types.UintValue(n) -> int.to_string(n)
    abi_types.IntValue(n) -> int.to_string(n)
    abi_types.AddressValue(addr) -> addr
    abi_types.BoolValue(b) ->
      case b {
        True -> "true"
        False -> "false"
      }
    abi_types.FixedBytesValue(data) ->
      "0x" <> string.lowercase(bit_array.base16_encode(data))
    abi_types.BytesValue(data) ->
      "0x" <> string.lowercase(bit_array.base16_encode(data))
    abi_types.StringValue(s) -> "\"" <> s <> "\""
    abi_types.ArrayValue(elements) -> {
      let inner = list.map(elements, format_abi_value)
      "[" <> string.join(inner, ", ") <> "]"
    }
    abi_types.TupleValue(elements) -> {
      let inner = list.map(elements, format_abi_value)
      "(" <> string.join(inner, ", ") <> ")"
    }
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
