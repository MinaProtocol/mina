val optional : 'a option -> f:('a -> ([> `Null ] as 'b)) -> 'b

val uint64 : Unsigned.UInt64.t -> [> `String of string ]

val amount : Currency.Amount.Stable.Latest.t -> [> `String of string ]

val fee : Currency.Fee.Stable.Latest.t -> [> `String of string ]

val nonce : Mina_base.Account.Nonce.t -> [> `String of string ]

val uint32 : Unsigned.UInt32.t -> [> `String of string ]

val public_key : Signature_lib.Public_key.Compressed.t -> [> `String of string ]

val token : Mina_base.Token_id.t -> [> `String of string ]
