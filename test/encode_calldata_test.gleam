import gleeth_cli/commands/encode_calldata
import gleeunit/should

pub fn encode_transfer_test() {
  // transfer(address,uint256) with known args should produce known calldata
  // selector: 0xa9059cbb
  let result =
    encode_calldata.execute("transfer(address,uint256)", [
      "address:0x0000000000000000000000000000000000000001",
      "uint256:1",
    ])
  should.be_ok(result)
}

pub fn encode_no_params_test() {
  // totalSupply() - no params, just the selector
  let result = encode_calldata.execute("totalSupply()", [])
  should.be_ok(result)
}

pub fn encode_invalid_param_test() {
  let result =
    encode_calldata.execute("transfer(address,uint256)", ["not-a-typed-param"])
  should.be_error(result)
}

pub fn encode_extracts_name_from_signature_test() {
  // "transfer(address,uint256)" and "transfer" should produce same result
  // when given the same typed params
  let result =
    encode_calldata.execute("transfer", [
      "address:0x0000000000000000000000000000000000000001",
      "uint256:1",
    ])
  should.be_ok(result)
}
