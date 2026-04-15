import gleam/bit_array
import gleam/dict
import gleam/string
import gleeth/crypto/secp256k1
import gleeth/crypto/wallet
import gleeth/eip712
import gleeth_cli/commands/sign_typed_data
import gleeunit/should

pub fn hash_produces_32_bytes_test() {
  let domain =
    eip712.domain()
    |> eip712.domain_name("Ether Mail")
    |> eip712.domain_version("1")
    |> eip712.domain_chain_id(1)
    |> eip712.domain_verifying_contract(
      "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC",
    )

  let types =
    dict.from_list([
      #("Mail", [
        eip712.field("from", "address"),
        eip712.field("to", "address"),
        eip712.field("contents", "string"),
      ]),
    ])

  let message =
    dict.from_list([
      #(
        "from",
        eip712.address_val("0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"),
      ),
      #("to", eip712.address_val("0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB")),
      #("contents", eip712.string_val("Hello, Bob!")),
    ])

  let data = eip712.typed_data(types, "Mail", domain, message)
  let digest = eip712.hash_typed_data(data) |> should.be_ok

  should.equal(bit_array.byte_size(digest), 32)
}

pub fn sign_and_recover_roundtrip_test() {
  let domain =
    eip712.domain()
    |> eip712.domain_name("Ether Mail")
    |> eip712.domain_version("1")
    |> eip712.domain_chain_id(1)

  let types =
    dict.from_list([
      #("Mail", [
        eip712.field("from", "address"),
        eip712.field("contents", "string"),
      ]),
    ])

  let message =
    dict.from_list([
      #(
        "from",
        eip712.address_val("0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"),
      ),
      #("contents", eip712.string_val("Hello")),
    ])

  let data = eip712.typed_data(types, "Mail", domain, message)

  let w =
    wallet.from_private_key_hex(
      "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    )
    |> should.be_ok

  let sig = eip712.sign_typed_data(data, w) |> should.be_ok
  let sig_hex = secp256k1.signature_to_hex(sig)

  let recovered = eip712.recover_typed_data(data, sig_hex) |> should.be_ok

  should.equal(
    string.lowercase(recovered),
    string.lowercase(wallet.get_address(w)),
  )
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
