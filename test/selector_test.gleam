import gleeth/crypto/keccak
import gleeunit/should

pub fn transfer_selector_test() {
  keccak.function_selector("transfer(address,uint256)")
  |> should.be_ok
  |> should.equal("0xa9059cbb")
}

pub fn approve_selector_test() {
  keccak.function_selector("approve(address,uint256)")
  |> should.be_ok
  |> should.equal("0x095ea7b3")
}

pub fn balance_of_selector_test() {
  keccak.function_selector("balanceOf(address)")
  |> should.be_ok
  |> should.equal("0x70a08231")
}

pub fn total_supply_selector_test() {
  keccak.function_selector("totalSupply()")
  |> should.be_ok
  |> should.equal("0x18160ddd")
}

pub fn transfer_event_topic_test() {
  let topic = keccak.event_topic("Transfer(address,address,uint256)")
  should.equal(
    topic,
    "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
  )
}

pub fn approval_event_topic_test() {
  let topic = keccak.event_topic("Approval(address,address,uint256)")
  should.equal(
    topic,
    "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925",
  )
}
