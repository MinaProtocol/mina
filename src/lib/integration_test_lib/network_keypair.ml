open Signature_lib
open Core_kernel

type t =
  { keypair : Keypair.t
  ; keypair_name : string
  ; privkey_password : string
  ; public_key : string
  ; private_key : string
  }
[@@deriving eq, to_yojson]

let create_network_keypair ~keypair_name ~keypair =
  let open Keypair in
  let privkey_password = "naughty blue worm" in
  let public_key =
    Public_key.Compressed.to_base58_check
      (Public_key.compress keypair.public_key)
  in
  let private_key =
    let plaintext =
      Bigstring.to_bytes (Private_key.to_bigstring keypair.private_key)
    in
    let password = Bytes.of_string privkey_password in
    Secrets.Secret_box.encrypt ~plaintext ~password
    |> Secrets.Secret_box.to_yojson |> Yojson.Safe.to_string
  in
  { keypair; keypair_name; privkey_password; public_key; private_key }
