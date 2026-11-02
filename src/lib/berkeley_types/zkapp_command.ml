(* The zkApp command of the Berkeley era. *)

open Core_kernel
module Call_forest = Mina_base.Zkapp_command.Call_forest

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      (Account_update.Stable.V1.t, unit, unit) Call_forest.Stable.V1.t
      Mina_base.Zkapp_command.Poly.Stable.V2.t
    [@@deriving equal, sexp, yojson]

    let to_latest = Fn.id
  end
end]

(** The transaction hash of [t], by the Berkeley rules: Blake2 over its
    serialisation, with signatures and proofs replaced by dummies. *)
let hash ({ fee_payer; account_updates; memo } : Stable.V1.t) :
    Mina_transaction.Transaction_hash.t =
  let with_dummy_authorizations : Stable.V1.t =
    { fee_payer = { fee_payer with authorization = Mina_base.Signature.dummy }
    ; account_updates =
        Call_forest.map account_updates
          ~f:(fun (account_update : Account_update.Stable.V1.t) ->
            let authorization : Mina_base.Control.Stable.V2.t =
              match account_update.authorization with
              | Proof _ ->
                  Proof (Lazy.force Mina_base.Proof.transaction_dummy)
              | Signature _ ->
                  Signature Mina_base.Signature.dummy
              | None_given ->
                  None_given
            in
            { account_update with authorization } )
    ; memo
    }
  in
  Binable.to_string (module Stable.Latest) with_dummy_authorizations
  |> Mina_transaction.Transaction_hash.digest_string

let to_mesa ({ fee_payer; account_updates; memo } : Stable.V1.t) :
    Mina_base.Zkapp_command.Stable.Latest.t =
  { fee_payer
  ; account_updates = Call_forest.map account_updates ~f:Account_update.to_mesa
  ; memo
  }
