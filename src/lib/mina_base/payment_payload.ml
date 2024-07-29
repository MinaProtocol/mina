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
            ( 'public_key
            , 'amount )
            Mina_wire_types.Mina_base.Payment_payload.Poly.V2.t =
        { receiver_pk : 'public_key; amount : 'amount }
      [@@deriving equal, sexp, hash, yojson, compare, hlist]
    end

    module V1 = struct
      [@@@with_all_version_tags]

      type ('public_key, 'token_id, 'amount) t =
        { source_pk : 'public_key
        ; receiver_pk : 'public_key
        ; token_id : 'token_id
        ; amount : 'amount
        }
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

  module V1 = struct
    [@@@with_all_version_tags]

    type t =
      ( Public_key.Compressed.Stable.V1.t
      , Token_id.Stable.V1.t
      , Amount.Stable.V1.t )
      Poly.Stable.V1.t
    [@@deriving equal, sexp, hash, compare, yojson]

    (* don't need to coerce old payments to new ones *)
    let to_latest _ = failwith "Not implemented"
  end
end]

let dummy =
  Poly.{ receiver_pk = Public_key.Compressed.empty; amount = Amount.zero }

type var = (Public_key.Compressed.var, Amount.var) Poly.t

let var_of_t ({ receiver_pk; amount } : t) : var =
  { receiver_pk = Public_key.Compressed.var_of_t receiver_pk
  ; amount = Amount.var_of_t amount
  }

let gen_aux max_amount =
  let open Quickcheck.Generator.Let_syntax in
  let%bind receiver_pk = Public_key.Compressed.gen in
  let%map amount = Amount.gen_incl Amount.zero max_amount in
  Poly.{ receiver_pk; amount }

let gen max_amount = gen_aux max_amount

let gen_default_token max_amount = gen_aux max_amount
