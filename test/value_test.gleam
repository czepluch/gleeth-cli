import gleeth_cli/value
import gleeunit/should

pub fn parse_value_hex_passthrough_test() {
  value.parse_value("0xde0b6b3a7640000")
  |> should.be_ok
  |> should.equal("0xde0b6b3a7640000")
}

pub fn parse_value_ether_test() {
  value.parse_value("1ether")
  |> should.be_ok
  |> should.equal("0xde0b6b3a7640000")
}

pub fn parse_value_eth_test() {
  value.parse_value("1eth")
  |> should.be_ok
  |> should.equal("0xde0b6b3a7640000")
}

pub fn parse_value_gwei_test() {
  value.parse_value("1gwei")
  |> should.be_ok
  |> should.equal("0x3b9aca00")
}

pub fn parse_value_wei_suffix_test() {
  value.parse_value("1000wei")
  |> should.be_ok
  |> should.equal("0x3e8")
}

pub fn parse_value_plain_decimal_test() {
  value.parse_value("21000")
  |> should.be_ok
  |> should.equal("0x5208")
}

pub fn parse_value_fractional_ether_test() {
  value.parse_value("0.5ether")
  |> should.be_ok
  |> should.equal("0x6f05b59d3b20000")
}

pub fn parse_value_invalid_test() {
  value.parse_value("notanumber")
  |> should.be_error
}

pub fn chain_name_mainnet_test() {
  value.chain_name_to_id("mainnet")
  |> should.be_ok
  |> should.equal(1)
}

pub fn chain_name_sepolia_test() {
  value.chain_name_to_id("sepolia")
  |> should.be_ok
  |> should.equal(11_155_111)
}

pub fn chain_name_arbitrum_test() {
  value.chain_name_to_id("arbitrum")
  |> should.be_ok
  |> should.equal(42_161)
}

pub fn chain_name_base_test() {
  value.chain_name_to_id("base")
  |> should.be_ok
  |> should.equal(8453)
}

pub fn chain_name_case_insensitive_test() {
  value.chain_name_to_id("Mainnet")
  |> should.be_ok
  |> should.equal(1)
}

pub fn chain_name_unknown_test() {
  value.chain_name_to_id("nonexistent")
  |> should.be_error
}
