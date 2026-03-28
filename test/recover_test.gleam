import gleeth_cli/commands/recover
import gleeunit/should

pub fn parse_args_basic_test() {
  let options =
    recover.parse_args(["hello", "0xabcdef"])
    |> should.be_ok
  should.equal(options.message, "hello")
  should.equal(options.signature, "0xabcdef")
  should.equal(options.recovery_mode, recover.RecoverAddress)
  should.equal(options.format, recover.Detailed)
}

pub fn parse_args_with_mode_test() {
  let options =
    recover.parse_args(["--mode", "pubkey", "hello", "0xabcdef"])
    |> should.be_ok
  should.equal(options.recovery_mode, recover.RecoverPublicKey)
}

pub fn parse_args_with_format_test() {
  let options =
    recover.parse_args(["--format", "json", "hello", "0xabcdef"])
    |> should.be_ok
  should.equal(options.format, recover.Json)
}

pub fn parse_args_with_mode_and_format_test() {
  let options =
    recover.parse_args([
      "--mode",
      "candidates",
      "--format",
      "compact",
      "message",
      "0xsig",
    ])
    |> should.be_ok
  should.equal(options.recovery_mode, recover.RecoverCandidates)
  should.equal(options.format, recover.Compact)
}

pub fn parse_args_missing_positional_test() {
  recover.parse_args(["--mode", "address"])
  |> should.be_error
}

pub fn parse_args_empty_test() {
  recover.parse_args([])
  |> should.be_error
}

pub fn parse_recovery_mode_address_test() {
  recover.parse_recovery_mode("address")
  |> should.be_ok
  |> should.equal(recover.RecoverAddress)
}

pub fn parse_recovery_mode_pubkey_test() {
  recover.parse_recovery_mode("pubkey")
  |> should.be_ok
  |> should.equal(recover.RecoverPublicKey)
}

pub fn parse_recovery_mode_candidates_test() {
  recover.parse_recovery_mode("candidates")
  |> should.be_ok
  |> should.equal(recover.RecoverCandidates)
}

pub fn parse_recovery_mode_verify_test() {
  let mode =
    recover.parse_recovery_mode(
      "verify:0xd8da6bf26964af9d7eed9e03e53415d37aa96045",
    )
    |> should.be_ok
  case mode {
    recover.VerifyAddress(addr) ->
      should.equal(addr, "0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
    _ -> should.fail()
  }
}

pub fn parse_recovery_mode_invalid_test() {
  recover.parse_recovery_mode("invalid")
  |> should.be_error
}

pub fn parse_output_format_compact_test() {
  recover.parse_output_format("compact")
  |> should.be_ok
  |> should.equal(recover.Compact)
}

pub fn parse_output_format_json_test() {
  recover.parse_output_format("json")
  |> should.be_ok
  |> should.equal(recover.Json)
}

pub fn parse_output_format_detailed_test() {
  recover.parse_output_format("detailed")
  |> should.be_ok
  |> should.equal(recover.Detailed)
}

pub fn parse_output_format_invalid_test() {
  recover.parse_output_format("xml")
  |> should.be_error
}

pub fn validate_options_empty_message_test() {
  let options =
    recover.RecoverOptions(
      message: "",
      signature: "0xabcd",
      recovery_mode: recover.RecoverAddress,
      format: recover.Detailed,
    )
  recover.validate_options(options)
  |> should.be_error
}

pub fn default_options_test() {
  let options = recover.default_options()
  should.equal(options.message, "")
  should.equal(options.signature, "")
  should.equal(options.recovery_mode, recover.RecoverAddress)
  should.equal(options.format, recover.Detailed)
}
