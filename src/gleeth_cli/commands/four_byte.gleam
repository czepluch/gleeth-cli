import gleam/dynamic/decode
import gleam/http/request
import gleam/httpc
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/string

/// Look up function signatures for a 4-byte selector via Sourcify
pub fn execute(selector: String) -> Result(Nil, String) {
  let normalized = case string.starts_with(selector, "0x") {
    True -> selector
    False -> "0x" <> selector
  }

  let url =
    "https://api.4byte.sourcify.dev/signature-database/v1/lookup?function="
    <> normalized

  use req <- result.try(
    request.to(url)
    |> result.map_error(fn(_) { "Invalid URL" }),
  )

  use resp <- result.try(
    httpc.send(req)
    |> result.map_error(fn(_) { "HTTP request failed" }),
  )

  use signatures <- result.try(parse_response(resp.body, normalized))

  case signatures {
    [] -> {
      io.println("No signatures found for " <> normalized)
      Ok(Nil)
    }
    sigs -> {
      io.println("Selector: " <> normalized)
      list.each(sigs, fn(sig) { io.println("  " <> sig) })
      Ok(Nil)
    }
  }
}

/// Parse the Sourcify signature lookup response.
/// Format: {"ok": true, "result": {"function": {"0xa9059cbb": [{"name": "transfer(address,uint256)", ...}]}, "event": {}}}
fn parse_response(
  body: String,
  selector: String,
) -> Result(List(String), String) {
  let names_decoder =
    decode.at(
      ["result", "function", selector],
      decode.list(decode.at(["name"], decode.string)),
    )

  json.parse(body, names_decoder)
  |> result.map_error(fn(_) { "Failed to parse API response" })
}
