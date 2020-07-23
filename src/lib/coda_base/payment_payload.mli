open Core
open Import

[%%versioned:
module Stable : sig
  module V1 : sig
    type t =
      { source_pk: Public_key.Compressed.Stable.V1.t
      ; receiver_pk: Public_key.Compressed.Stable.V1.t
      ; token_id: Token_id.Stable.V1.t
      ; amount: Amount.Stable.V1.t
      ; do_not_pay_creation_fee: bool }
    [@@deriving eq, sexp, hash, yojson, compare]
  end
end]

type t = Stable.Latest.t =
  { source_pk: Public_key.Compressed.t
  ; receiver_pk: Public_key.Compressed.t
  ; token_id: Token_id.t
  ; amount: Amount.t
  ; do_not_pay_creation_fee: bool }
[@@deriving eq, sexp, hash, yojson, compare]

val dummy : t

val token : t -> Token_id.t

val gen :
     ?source_pk:Public_key.Compressed.t
  -> max_amount:Currency.Amount.t
  -> t Quickcheck.Generator.t

val gen_default_token :
     ?source_pk:Public_key.Compressed.t
  -> max_amount:Currency.Amount.t
  -> t Quickcheck.Generator.t

val gen_non_default_token :
     ?source_pk:Public_key.Compressed.t
  -> max_amount:Currency.Amount.t
  -> t Quickcheck.Generator.t
