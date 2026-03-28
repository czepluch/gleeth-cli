import gleeth/ethereum/address
import gleeunit/should

pub fn checksum_vitalik_test() {
  address.checksum("0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
  |> should.be_ok
  |> should.equal("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
}

pub fn checksum_usdc_test() {
  address.checksum("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
  |> should.be_ok
  |> should.equal("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")
}

pub fn checksum_already_checksummed_test() {
  address.checksum("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
  |> should.be_ok
  |> should.equal("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
}

pub fn valid_checksum_test() {
  address.is_valid_checksum("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
  |> should.be_true
}

pub fn invalid_checksum_test() {
  // Wrong case on some chars
  address.is_valid_checksum("0xd8DA6BF26964aF9D7eEd9e03E53415D37aA96045")
  |> should.be_false
}

pub fn all_lowercase_valid_checksum_test() {
  // All-lowercase is considered valid (no checksum applied)
  address.is_valid_checksum("0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
  |> should.be_true
}

pub fn to_lowercase_test() {
  address.to_lowercase("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
  |> should.be_ok
  |> should.equal("0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
}
