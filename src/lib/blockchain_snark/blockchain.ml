open Core_kernel
open Mina_base
open Mina_state

[%%versioned
module Stable = struct
  module V2 = struct
    module T = struct
      type t =
        { state : Protocol_state.Value.Stable.V2.t; proof : Proof.Stable.V2.t }
      [@@deriving fields, sexp, yojson]
    end

    include T

    let to_latest = Fn.id

    include (
      Allocation_functor.Make.Bin_io_and_sexp (struct
        let id = "blockchain_snark"

        include T

        type 'a creator = state:Protocol_state.Value.t -> proof:Proof.t -> 'a

        let map_creator c ~f ~state ~proof = f (c ~state ~proof)

        let create ~state ~proof = { state; proof }
      end) :
        Allocation_functor.Intf.Output.Bin_io_and_sexp_intf
          with type t := T.t
           and type 'a creator :=
            state:Protocol_state.Value.t -> proof:Proof.t -> 'a )
  end
end]

include (
  Stable.Latest :
    sig
      type t = Stable.Latest.t [@@deriving sexp, yojson]
    end )

[%%define_locally Stable.Latest.(create, state, proof)]
