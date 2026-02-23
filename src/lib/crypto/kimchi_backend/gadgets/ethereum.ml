module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint

let pubkey_hex_to_point (hex : string) : Bignum_bigint.t * Bignum_bigint.t =
  assert (132 = String.length hex) ;
  let x_hex = "0x" ^ String.sub hex 4 64 in
  let y_hex = "0x" ^ String.sub hex 68 64 in
  (Bignum_bigint.of_string x_hex, Bignum_bigint.of_string y_hex)
