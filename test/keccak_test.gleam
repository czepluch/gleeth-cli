import gleam/string
import gleeth/crypto/keccak
import gleeunit/should

pub fn keccak256_empty_string_test() {
  keccak.keccak256_hex("")
  |> should.equal(
    "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
  )
}

pub fn keccak256_hello_test() {
  keccak.keccak256_hex("hello")
  |> should.equal(
    "0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8",
  )
}

pub fn keccak256_transfer_selector_test() {
  let hash = keccak.keccak256_hex("transfer(address,uint256)")
  let selector = "0x" <> string.slice(string.drop_start(hash, 2), 0, 8)
  should.equal(selector, "0xa9059cbb")
}

pub fn event_topic_matches_full_hash_test() {
  let topic = keccak.event_topic("Transfer(address,address,uint256)")
  let hash = keccak.keccak256_hex("Transfer(address,address,uint256)")
  should.equal(topic, hash)
}
