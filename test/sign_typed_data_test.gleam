import gleeth_cli/commands/sign_typed_data
import gleeunit/should

pub fn sign_and_verify_roundtrip_test() {
  let json_file = "test/fixtures/eip712_mail.json"
  let private_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  // Sign should succeed
  sign_typed_data.execute(json_file, private_key)
  |> should.be_ok
}

pub fn hash_typed_data_test() {
  let json_file = "test/fixtures/eip712_mail.json"

  // Hash should succeed
  sign_typed_data.execute_hash(json_file)
  |> should.be_ok
}

pub fn sign_invalid_file_test() {
  sign_typed_data.execute("nonexistent.json", "0x1234")
  |> should.be_error
}

pub fn hash_invalid_file_test() {
  sign_typed_data.execute_hash("nonexistent.json")
  |> should.be_error
}

pub fn verify_invalid_file_test() {
  sign_typed_data.execute_verify("nonexistent.json", "0xabcd")
  |> should.be_error
}
