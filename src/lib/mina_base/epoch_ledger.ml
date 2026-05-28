open Core_kernel
open Currency
open Snark_params.Tick

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('ledger_hash, 'amount) t =
            ( 'ledger_hash
            , 'amount )
            Mina_wire_types.Mina_base.Epoch_ledger.Poly.V1.t =
        { hash : 'ledger_hash; total_currency : 'amount; total_stake : 'amount }
      [@@deriving annot, sexp, equal, compare, hash, yojson, hlist, fields]
    end
  end]
end

module Value = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        (Frozen_ledger_hash0.Stable.V1.t, Amount.Stable.V1.t) Poly.Stable.V1.t
      [@@deriving sexp, equal, compare, hash, yojson]

      let to_latest = Fn.id
    end
  end]
end

let to_input ({ hash; total_currency; total_stake } : Value.t) =
  Random_oracle_input.Chunked.(
    append
      (append (field (hash :> Field.t)) (Amount.to_input total_currency))
      (Amount.to_input total_stake))

type var = (Frozen_ledger_hash0.var, Amount.var) Poly.t

let typ : (var, Value.t) Typ.t =
  Typ.of_hlistable
    [ Frozen_ledger_hash0.typ; Amount.typ; Amount.typ ]
    ~var_to_hlist:Poly.to_hlist ~var_of_hlist:Poly.of_hlist
    ~value_to_hlist:Poly.to_hlist ~value_of_hlist:Poly.of_hlist

let var_to_input ({ Poly.hash; total_currency; total_stake } : var) =
  let total_currency = Amount.var_to_input total_currency in
  let total_stake = Amount.var_to_input total_stake in
  Random_oracle_input.Chunked.(
    append
      (append
         (field (Frozen_ledger_hash0.var_to_hash_packed hash))
         total_currency )
      total_stake)

let if_ cond ~(then_ : (Frozen_ledger_hash0.var, Amount.var) Poly.t)
    ~(else_ : (Frozen_ledger_hash0.var, Amount.var) Poly.t) =
  let open Checked.Let_syntax in
  let%map hash =
    Frozen_ledger_hash0.if_ cond ~then_:then_.hash ~else_:else_.hash
  and total_currency =
    Amount.Checked.if_ cond ~then_:then_.total_currency
      ~else_:else_.total_currency
  and total_stake =
    Amount.Checked.if_ cond ~then_:then_.total_stake ~else_:else_.total_stake
  in
  { Poly.hash; total_currency; total_stake }
