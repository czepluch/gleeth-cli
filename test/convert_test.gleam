import gleeth/wei
import gleeunit/should

pub fn ether_to_wei_test() {
  wei.from_ether("1")
  |> should.be_ok
  |> should.equal("0xde0b6b3a7640000")
}

pub fn gwei_to_wei_test() {
  wei.from_gwei("1")
  |> should.be_ok
  |> should.equal("0x3b9aca00")
}

pub fn wei_to_ether_test() {
  wei.to_ether("0xde0b6b3a7640000")
  |> should.be_ok
  |> should.equal("1.0")
}

pub fn wei_to_gwei_test() {
  wei.to_gwei("0x3b9aca00")
  |> should.be_ok
  |> should.equal("1.0")
}

pub fn fractional_ether_to_wei_test() {
  wei.from_ether("0.5")
  |> should.be_ok
  |> should.equal("0x6f05b59d3b20000")
}

pub fn large_wei_to_ether_test() {
  // 100 ETH
  wei.to_ether("0x56bc75e2d63100000")
  |> should.be_ok
  |> should.equal("100.0")
}

pub fn zero_ether_to_wei_test() {
  wei.from_ether("0")
  |> should.be_ok
  |> should.equal("0x0")
}
