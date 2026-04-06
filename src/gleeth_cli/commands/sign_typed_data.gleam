import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import gleeth/crypto/secp256k1
import gleeth/crypto/wallet
import gleeth/eip712
import gleeth/utils/hex
import simplifile

/// Sign EIP-712 typed data from a JSON file
pub fn execute(json_file: String, private_key: String) -> Result(Nil, String) {
  use json_str <- result.try(
    simplifile.read(json_file)
    |> result.map_error(fn(_) { "Cannot read file: " <> json_file }),
  )
  use typed_data <- result.try(parse_typed_data_json(json_str))
  use w <- result.try(
    wallet.from_private_key_hex(private_key)
    |> result.map_error(wallet.error_to_string),
  )

  use signature <- result.try(eip712.sign_typed_data(typed_data, w))

  let sig_hex = secp256k1.signature_to_hex(signature)
  let #(v, r, s) = secp256k1.signature_to_vrs(signature)

  io.println("EIP-712 Signature:")
  io.println("  Signature: " <> sig_hex)
  io.println("  v: " <> int.to_string(v))
  io.println("  r: " <> r)
  io.println("  s: " <> s)
  io.println("  Signer: " <> wallet.get_address(w))
  Ok(Nil)
}

/// Verify an EIP-712 signature against typed data
pub fn execute_verify(
  json_file: String,
  signature_hex: String,
) -> Result(Nil, String) {
  use json_str <- result.try(
    simplifile.read(json_file)
    |> result.map_error(fn(_) { "Cannot read file: " <> json_file }),
  )
  use typed_data <- result.try(parse_typed_data_json(json_str))
  use recovered <- result.try(eip712.recover_typed_data(
    typed_data,
    signature_hex,
  ))

  io.println("EIP-712 Verification:")
  io.println("  Recovered signer: " <> recovered)
  Ok(Nil)
}

/// Hash EIP-712 typed data (useful for debugging)
pub fn execute_hash(json_file: String) -> Result(Nil, String) {
  use json_str <- result.try(
    simplifile.read(json_file)
    |> result.map_error(fn(_) { "Cannot read file: " <> json_file }),
  )
  use typed_data <- result.try(parse_typed_data_json(json_str))
  use digest <- result.try(eip712.hash_typed_data(typed_data))

  io.println("0x" <> string.lowercase(bit_array.base16_encode(digest)))
  Ok(Nil)
}

// =============================================================================
// JSON Parsing
// =============================================================================

/// Intermediate type for JSON parsing before typed conversion
type RawTypedData {
  RawTypedData(
    types: Dict(String, List(eip712.TypedField)),
    primary_type: String,
    domain: eip712.Domain,
    message: Dict(String, String),
  )
}

fn parse_typed_data_json(json_str: String) -> Result(eip712.TypedData, String) {
  let decoder = {
    use types <- decode.field("types", decode_types())
    use primary_type <- decode.field("primaryType", decode.string)
    use domain <- decode.field("domain", decode_domain())
    use message <- decode.field(
      "message",
      decode.dict(decode.string, decode_raw_value()),
    )
    decode.success(RawTypedData(types, primary_type, domain, message))
  }

  use raw <- result.try(
    json.parse(json_str, decoder)
    |> result.map_error(fn(_) { "Failed to parse EIP-712 JSON" }),
  )

  use message <- result.try(convert_message(
    dict.to_list(raw.message),
    raw.primary_type,
    raw.types,
  ))

  Ok(eip712.typed_data(raw.types, raw.primary_type, raw.domain, message))
}

fn decode_types() -> decode.Decoder(Dict(String, List(eip712.TypedField))) {
  decode.dict(decode.string, decode.list(decode_typed_field()))
}

fn decode_typed_field() -> decode.Decoder(eip712.TypedField) {
  use name <- decode.field("name", decode.string)
  use type_name <- decode.field("type", decode.string)
  decode.success(eip712.field(name, type_name))
}

fn decode_domain() -> decode.Decoder(eip712.Domain) {
  use name <- decode.optional_field(
    "name",
    None,
    decode.optional(decode.string),
  )
  use version <- decode.optional_field(
    "version",
    None,
    decode.optional(decode.string),
  )
  use chain_id <- decode.optional_field(
    "chainId",
    None,
    decode.optional(decode.int),
  )
  use verifying_contract <- decode.optional_field(
    "verifyingContract",
    None,
    decode.optional(decode.string),
  )
  use salt <- decode.optional_field(
    "salt",
    None,
    decode.optional(decode.string),
  )
  decode.success(eip712.Domain(
    name: name,
    version: version,
    chain_id: chain_id,
    verifying_contract: verifying_contract,
    salt: salt,
  ))
}

/// Decode any JSON value to a string for later typed conversion
fn decode_raw_value() -> decode.Decoder(String) {
  decode.one_of(decode.string, [
    decode.int |> decode.map(int.to_string),
    decode.bool
      |> decode.map(fn(b) {
        case b {
          True -> "true"
          False -> "false"
        }
      }),
  ])
}

// =============================================================================
// Message value conversion
// =============================================================================

fn convert_message(
  raw_pairs: List(#(String, String)),
  type_name: String,
  types: Dict(String, List(eip712.TypedField)),
) -> Result(Dict(String, eip712.TypedValue), String) {
  case dict.get(types, type_name) {
    Ok(fields) -> {
      use pairs <- result.try(
        list.try_map(raw_pairs, fn(pair) {
          let #(key, raw_val) = pair
          use field_type <- result.try(find_field_type(key, fields))
          use typed_val <- result.try(convert_value(raw_val, field_type))
          Ok(#(key, typed_val))
        }),
      )
      Ok(dict.from_list(pairs))
    }
    Error(_) -> Error("Unknown type in message: " <> type_name)
  }
}

fn find_field_type(
  name: String,
  fields: List(eip712.TypedField),
) -> Result(String, String) {
  case list.find(fields, fn(f) { f.name == name }) {
    Ok(f) -> Ok(f.type_name)
    Error(_) -> Error("Unknown field: " <> name)
  }
}

fn convert_value(
  raw: String,
  type_name: String,
) -> Result(eip712.TypedValue, String) {
  case type_name {
    "string" -> Ok(eip712.StringVal(raw))
    "address" -> Ok(eip712.AddressVal(raw))
    "bool" ->
      case raw {
        "true" -> Ok(eip712.BoolVal(True))
        "false" -> Ok(eip712.BoolVal(False))
        _ -> Error("Invalid bool value: " <> raw)
      }
    "bytes32" -> {
      use bytes <- result.try(
        hex.decode(raw)
        |> result.map_error(fn(_) { "Invalid bytes32: " <> raw }),
      )
      Ok(eip712.Bytes32Val(bytes))
    }
    "bytes" -> {
      use bytes <- result.try(
        hex.decode(raw) |> result.map_error(fn(_) { "Invalid bytes: " <> raw }),
      )
      Ok(eip712.BytesVal(bytes))
    }
    _ ->
      case
        string.starts_with(type_name, "uint")
        || string.starts_with(type_name, "int")
      {
        True ->
          case int.parse(raw) {
            Ok(n) -> Ok(eip712.IntVal(n))
            Error(_) -> Error("Invalid integer value: " <> raw)
          }
        False ->
          case string.starts_with(type_name, "bytes") {
            True -> {
              use bytes <- result.try(
                hex.decode(raw)
                |> result.map_error(fn(_) {
                  "Invalid " <> type_name <> ": " <> raw
                }),
              )
              Ok(eip712.Bytes32Val(bytes))
            }
            False -> Ok(eip712.StringVal(raw))
          }
      }
  }
}
