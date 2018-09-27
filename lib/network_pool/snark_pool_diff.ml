open Core_kernel
open Async

type ('work, 'priced_proof) diff = Add_solved_work of 'work * 'priced_proof
[@@deriving bin_io, sexp]

module type Inputs_intf = sig
  include Snark_pool.Inputs_intf

  module Snark_pool :
    Snark_pool.S
    with type statement := Statement.t
     and type work := Work.t
     and type proof := Proof.t
     and type fee := Fee.t
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs

  type priced_proof = {proof: Proof.t sexp_opaque; fee: Fee.t}
  [@@deriving bin_io, sexp]

  type t = (Work.t, priced_proof) diff [@@deriving bin_io, sexp]

  let summary = function
    | Add_solved_work (_, {proof= _; fee}) ->
        Printf.sprintf !"Snark_pool_diff add with fee %{sexp: Fee.t}" fee

  let apply (pool: Snark_pool.t) (t: t) : t Or_error.t Deferred.t =
    let to_or_error = function
      | `Don't_rebroadcast ->
          Or_error.error_string "Worse fee or already in pool"
      | `Rebroadcast -> Ok t
    in
    ( match t with Add_solved_work (work, {proof; fee}) ->
        Snark_pool.add_snark pool ~work ~proof ~fee )
    |> to_or_error |> Deferred.return
end
