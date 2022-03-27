val optional : f:(([> `Null ] as 'a) -> 'b) -> 'a -> 'b option

val public_key : Yojson.Basic.t -> Signature_lib.Public_key.Compressed.t

val public_key_array :
     Yojson.Basic.t Core_kernel.Array.t
  -> Signature_lib.Public_key.Compressed.t Core_kernel.Array.t

val optional_public_key :
  Yojson.Basic.t option -> Signature_lib.Public_key.Compressed.t option

val uint64 : Yojson.Basic.t -> Unsigned.UInt64.t

val optional_uint64 : Yojson.Basic.t option -> Unsigned.UInt64.t option

val uint32 : Yojson.Basic.t -> Unsigned.UInt32.t

val balance : Yojson.Basic.t -> Currency.Balance.Stable.Latest.t

val amount : Yojson.Basic.t -> Currency.Amount.Stable.Latest.t

val fee : Yojson.Basic.t -> Currency.Fee.Stable.Latest.t

val nonce : Yojson.Basic.t -> Mina_base.Account.Nonce.t

val token : Yojson.Basic.t -> Mina_base.Token_id.t
