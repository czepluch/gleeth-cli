import gleam/list
import gleam/string
import gleeth/ethereum/contract
import gleeunit/should

pub fn encode_transfer_test() {
  let params =
    list.try_map(
      [
        "address:0x0000000000000000000000000000000000000001",
        "uint256:1",
      ],
      contract.parse_parameter,
    )
    |> should.be_ok

  let calldata =
    contract.build_call_data("transfer", params)
    |> should.be_ok

  // Should start with transfer selector 0xa9059cbb
  should.be_true(string.starts_with(calldata, "0xa9059cbb"))
}

pub fn encode_no_params_test() {
  let calldata =
    contract.build_call_data("totalSupply", [])
    |> should.be_ok

  // Should be just the selector 0x18160ddd
  should.be_true(string.starts_with(calldata, "0x18160ddd"))
}

pub fn encode_invalid_param_test() {
  contract.parse_parameter("not-a-typed-param")
  |> should.be_error
}

pub fn encode_balanceof_test() {
  let params =
    list.try_map(
      ["address:0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"],
      contract.parse_parameter,
    )
    |> should.be_ok

  let calldata =
    contract.build_call_data("balanceOf", params)
    |> should.be_ok

  // Should start with balanceOf selector 0x70a08231
  should.be_true(string.starts_with(calldata, "0x70a08231"))
}
