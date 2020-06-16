open Core
open Import
open Types
open Pickles_types
open Hlist
open Snarky.Request
open Common

module Step = struct
  module type S = sig
    type statement

    type prev_values

    (* TODO: As an optimization this can be the local branching size *)
    type max_branching

    type local_signature

    type local_branches

    type _ t +=
      | Proof_with_datas :
          ( prev_values
          , local_signature
          , local_branches )
          H3.T(Per_proof_witness.Constant).t
          t
      | Me_only :
          ( Zexe_backend.G.Affine.t
          , statement
          , (Zexe_backend.G.Affine.t, max_branching) Vector.t )
          Types.Pairing_based.Proof_state.Me_only.t
          t
  end

  let create
      : type local_signature local_branches statement prev_values max_branching.
         unit
      -> (module S
            with type local_signature = local_signature
             and type local_branches = local_branches
             and type statement = statement
             and type prev_values = prev_values
             and type max_branching = max_branching) =
   fun () ->
    let module R = struct
      type nonrec max_branching = max_branching

      type nonrec statement = statement

      type nonrec prev_values = prev_values

      type nonrec local_signature = local_signature

      type nonrec local_branches = local_branches

      type _ t +=
        | Proof_with_datas :
            ( prev_values
            , local_signature
            , local_branches )
            H3.T(Per_proof_witness.Constant).t
            t
        | Me_only :
            ( Zexe_backend.G.Affine.t
            , statement
            , (Zexe_backend.G.Affine.t, max_branching) Vector.t )
            Types.Pairing_based.Proof_state.Me_only.t
            t
    end in
    (module R)
end
