(* encoders.ml -- encode internal values to Yojson.Basic.t *)

let optional = Core_kernel.Option.value_map ~default:`Null

let uint64 value = `String (Unsigned.UInt64.to_string value)

let amount value = `String (Currency.Amount.to_string value)

let fee value = `String (Currency.Fee.to_string value)

let nonce value = `String (Coda_base.Account.Nonce.to_string value)

let uint32 value = `String (Unsigned.UInt32.to_string value)

let public_key value =
  `String (Signature_lib.Public_key.Compressed.to_base58_check value)

let token value = `String (Coda_base.Token_id.to_string value)
