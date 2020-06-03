open Core_kernel
open Import

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      { token_owner_pk: Public_key.Compressed.Stable.V1.t
      ; receiver_pk: Public_key.Compressed.Stable.V1.t
      ; token: Token_id.Stable.V1.t
      ; amount: Currency.Amount.Stable.V1.t }
    [@@deriving compare, eq, sexp, hash, yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t =
  { token_owner_pk: Public_key.Compressed.t
  ; receiver_pk: Public_key.Compressed.t
  ; token: Token_id.t
  ; amount: Currency.Amount.t }
[@@deriving compare, eq, sexp, hash, yojson]
