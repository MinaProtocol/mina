(* payment_payload.ml *)

open Core_kernel
open Signature_lib
module Amount = Currency.Amount
module Fee = Currency.Fee

module Poly = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('public_key, 'amount) t =
        { source_pk : 'public_key; receiver_pk : 'public_key; amount : 'amount }
      [@@deriving equal, sexp, hash, yojson, compare, hlist]
    end
  end]
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      (Public_key.Compressed.Stable.V1.t, Amount.Stable.V1.t) Poly.Stable.V2.t
    [@@deriving equal, sexp, hash, compare, yojson]

    let to_latest = Fn.id
  end
end]

let dummy =
  Poly.
    { source_pk = Public_key.Compressed.empty
    ; receiver_pk = Public_key.Compressed.empty
    ; amount = Amount.zero
    }

let token _ = Token_id.default

let source { Poly.source_pk; _ } = Account_id.create source_pk Token_id.default

let receiver { Poly.receiver_pk; _ } =
  Account_id.create receiver_pk Token_id.default

let gen ?source_pk ~max_amount =
  let open Quickcheck.Generator.Let_syntax in
  let%bind source_pk =
    match source_pk with
    | Some source_pk ->
        return source_pk
    | None ->
        Public_key.Compressed.gen
  in
  let%bind receiver_pk = Public_key.Compressed.gen in
  let%map amount = Amount.gen_incl Amount.zero max_amount in
  Poly.{ source_pk; receiver_pk; amount }
