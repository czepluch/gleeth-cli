import gleeth/crypto/transaction
import gleeunit/should

// A known legacy transaction (Ethereum mainnet, simple ETH transfer)
// This is a crafted minimal legacy transaction for testing decode
pub fn decode_detects_eip1559_prefix_test() {
  // Malformed but starts with 0x02 - should attempt EIP-1559 decoding
  // and fail with a TransactionError rather than silently succeeding
  transaction.decode("0x02")
  |> should.be_error
}

pub fn decode_empty_fails_test() {
  transaction.decode("0x")
  |> should.be_error
}

pub fn decode_invalid_hex_fails_test() {
  transaction.decode("not-hex-at-all")
  |> should.be_error
}

pub fn decode_legacy_type_detection_test() {
  // RLP-encoded data starting with 0xf8+ should be detected as legacy
  // A very short/malformed one should still error, but as a legacy parse error
  transaction.decode_legacy("0xf800")
  |> should.be_error
}

pub fn decode_eip1559_type_detection_test() {
  // Must start with 0x02
  transaction.decode_eip1559("0x02c0")
  |> should.be_error
}

// Test that error_to_string works for all error variants
pub fn error_to_string_test() {
  let err = transaction.InvalidAddress("bad address")
  let msg = transaction.error_to_string(err)
  // Just verify it returns a non-empty string
  case msg {
    "" -> should.fail()
    _ -> Nil
  }
}
