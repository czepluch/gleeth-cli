import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleeth/ethereum/contract
import gleeth/rpc/types as rpc_types

/// Encode function call into calldata hex.
///
/// Accepts either a full signature like "transfer(address,uint256)" or
/// just the function name like "transfer". The parameter types come from
/// the parsed "type:value" arguments.
pub fn execute(
  function_signature: String,
  param_strings: List(String),
) -> Result(Nil, rpc_types.GleethError) {
  let function_name = extract_function_name(function_signature)
  use parsed_params <- result.try(list.try_map(
    param_strings,
    contract.parse_parameter,
  ))
  use calldata <- result.try(contract.build_call_data(
    function_name,
    parsed_params,
  ))
  io.println(calldata)
  Ok(Nil)
}

/// Extract just the function name from a full signature.
/// "transfer(address,uint256)" -> "transfer"
/// "transfer" -> "transfer"
fn extract_function_name(signature: String) -> String {
  case string.split_once(signature, "(") {
    Ok(#(name, _)) -> name
    Error(_) -> signature
  }
}
