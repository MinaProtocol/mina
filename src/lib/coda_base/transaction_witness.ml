open Core_kernel
open Snark_params.Tick

module State_hash_witness = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = State_body_hash.Stable.V1.t option [@@deriving sexp]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp]

  type var = State_body_hash.var * Boolean.var

  let typ =
    let spec =
      let open Data_spec in
      [State_body_hash.typ; Boolean.typ]
    in
    let var_to_hlist (sbh, push_state) = H_list.[sbh; push_state] in
    let var_of_hlist :
        (unit, State_body_hash.var -> Boolean.var -> unit) H_list.t -> var =
      let open H_list in
      fun [sbh; push_state] -> (sbh, push_state)
    in
    let value_to_hlist = function
      | Some sbh ->
          H_list.[sbh; true]
      | None ->
          H_list.[State_body_hash.dummy; false]
    in
    let value_of_hlist :
        (unit, State_body_hash.t -> bool -> unit) H_list.t -> t =
      let open H_list in
      fun [sbh; push_state] -> if push_state then Some sbh else None
    in
    Typ.of_hlistable spec ~var_to_hlist ~var_of_hlist ~value_to_hlist
      ~value_of_hlist

  module Checked = struct
    let push_state var = snd var

    let state_body_hash var = fst var
  end
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      { ledger: Sparse_ledger.Stable.V1.t
      ; state_body_hash: State_hash_witness.Stable.V1.t }
    [@@deriving sexp]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t =
  { ledger: Sparse_ledger.Stable.V1.t
  ; state_body_hash: State_hash_witness.Stable.V1.t }
[@@deriving sexp]
