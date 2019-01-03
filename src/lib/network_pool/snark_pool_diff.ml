open Core_kernel
open Async

module type Inputs_intf = sig
  module Proof : Binable.S

  module Fee : sig
    type t
    include Binable.S with type t := t
    include Sexpable.S with type t := t
  end

  module Statement : sig
    type t
  end

  module Work : sig
    type t
    include Binable.S with type t := t
    include Sexpable.S with type t := t
  end

  module Snark_pool : Snark_pool.S
    with type proof := Proof.t
     and type fee := Fee.t
     and type statement := Statement.t
     and type work := Work.t
end


type ('work, 'priced_proof) diff = Add_solved_work of 'work * 'priced_proof
[@@deriving bin_io, sexp]

module Make (Inputs : Inputs_intf) = struct
  open Inputs

  type priced_proof = {proof: Proof.t sexp_opaque; fee: Fee.t}
  [@@deriving bin_io, sexp]

  type t = (Work.t, priced_proof) diff [@@deriving bin_io, sexp]

  let summary = function
    | Add_solved_work (_, {proof= _; fee}) ->
        Printf.sprintf !"Snark_pool_diff add with fee %{sexp: Fee.t}" fee

  let apply (pool : Snark_pool.t) (t : t Envelope.Incoming.t) :
      t Or_error.t Deferred.t =
    let t = Envelope.Incoming.data t in
    let to_or_error = function
      | `Don't_rebroadcast ->
          Or_error.error_string "Worse fee or already in pool"
      | `Rebroadcast -> Ok t
    in
    ( match t with Add_solved_work (work, {proof; fee}) ->
        Snark_pool.add_snark pool ~work ~proof ~fee )
    |> to_or_error |> Deferred.return
end
