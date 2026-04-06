import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleeth_cli/value
import simplifile

/// Look up a verified contract ABI from Sourcify
pub fn execute(
  address: String,
  chain: String,
  output_file: Option(String),
) -> Result(Nil, String) {
  use chain_id <- result.try(value.chain_name_to_id(chain))

  let url =
    "https://sourcify.dev/server/v2/contract/"
    <> int.to_string(chain_id)
    <> "/"
    <> address
    <> "?fields=abi"

  use req <- result.try(
    request.to(url)
    |> result.map_error(fn(_) { "Invalid URL" }),
  )

  use resp <- result.try(
    httpc.send(req)
    |> result.map_error(fn(_) { "HTTP request failed" }),
  )

  case resp.status {
    200 -> {
      // Extract just the ABI array from the response
      // The response wraps it as {"abi": [...]}
      let abi_json = extract_abi(resp.body)
      case output_file {
        Some(file) -> {
          case simplifile.write(file, abi_json) {
            Ok(_) -> {
              io.println("ABI saved to " <> file)
              Ok(Nil)
            }
            Error(_) -> Error("Failed to write to " <> file)
          }
        }
        None -> {
          io.println(abi_json)
          Ok(Nil)
        }
      }
    }
    404 ->
      Error(
        "Contract not verified on Sourcify for chain "
        <> chain
        <> " at "
        <> address,
      )
    status -> Error("Sourcify API returned status " <> int.to_string(status))
  }
}

/// Extract the ABI array from the Sourcify response JSON.
/// Response format: {"abi": [...], ...}
/// We want just the [...] part.
fn extract_abi(body: String) -> String {
  // Simple approach: find the abi field value
  // The response is {"abi":[...],...} - we need the array
  case find_abi_array(body) {
    Ok(abi) -> abi
    Error(_) -> body
  }
}

fn find_abi_array(body: String) -> Result(String, Nil) {
  // Look for "abi": and extract the array that follows
  case
    string.split_once(body, "\"abi\":")
    |> result.map(fn(pair) { pair.1 })
  {
    Ok(rest) -> {
      // rest starts with the array [...], possibly with trailing fields
      // Find matching brackets
      Ok(extract_balanced_array(rest))
    }
    Error(_) -> Error(Nil)
  }
}

fn extract_balanced_array(s: String) -> String {
  // Find the start of the array
  let trimmed = string.trim(s)
  case string.starts_with(trimmed, "[") {
    True -> extract_until_balanced(trimmed, 0, 0)
    False -> s
  }
}

fn extract_until_balanced(s: String, index: Int, depth: Int) -> String {
  case string.pop_grapheme(string.drop_start(s, index)) {
    Ok(#("[", _)) -> extract_until_balanced(s, index + 1, depth + 1)
    Ok(#("]", _)) -> {
      case depth {
        1 -> string.slice(s, 0, index + 1)
        _ -> extract_until_balanced(s, index + 1, depth - 1)
      }
    }
    Ok(#(_, _)) -> extract_until_balanced(s, index + 1, depth)
    Error(_) -> s
  }
}
