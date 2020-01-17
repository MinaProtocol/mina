open Core
open Coda_base
open Snark_params
open Snarky
open Tick

module Block_data = struct
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

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = {transaction: 'a; block_data: Block_data.Stable.V1.t}
      [@@deriving sexp]
    end
  end]

  type 'a t = 'a Stable.Latest.t = {transaction: 'a; block_data: Block_data.t}
  [@@deriving sexp]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type 'a t = 'a Poly.Stable.V1.t [@@deriving sexp]
  end
end]

type 'a t = 'a Stable.Latest.t [@@deriving sexp]

let transaction t = t.Poly.transaction

let block_data t = t.Poly.block_data
