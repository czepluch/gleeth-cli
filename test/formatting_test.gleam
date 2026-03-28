import gleeth_cli/formatting
import gleeunit/should

pub fn format_address_with_prefix_test() {
  formatting.format_address("0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
  |> should.equal("0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
}

pub fn format_address_without_prefix_test() {
  formatting.format_address("d8da6bf26964af9d7eed9e03e53415d37aa96045")
  |> should.equal("0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
}

pub fn format_hash_with_prefix_test() {
  formatting.format_hash(
    "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
  )
  |> should.equal(
    "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
  )
}

pub fn format_hash_without_prefix_test() {
  formatting.format_hash(
    "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
  )
  |> should.equal(
    "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
  )
}

pub fn display_address_test() {
  formatting.display_address("0xD8DA6BF26964AF9D7EED9E03E53415D37AA96045")
  |> should.equal("0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
}

pub fn display_hash_test() {
  formatting.display_hash(
    "0xABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890",
  )
  |> should.equal(
    "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
  )
}
