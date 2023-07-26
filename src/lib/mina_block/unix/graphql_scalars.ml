open Graphql_basic_scalars.Utils
open Graphql_basic_scalars.Testing

module Make (Schema : Schema) = struct
  module type Json_intf =
    Json_intf_any_typ with type ('a, 'b) typ := ('a, 'b) Schema.typ

  module PrecomputedBlockProof :
    Json_intf with type t = Mina_block.Precomputed.Proof.t = struct
    open Mina_block.Precomputed.Proof

    type nonrec t = t

    let parse json = Yojson.Basic.Util.to_string json |> of_bin_string

    let serialize t = `String (to_bin_string t)

    let typ () =
      Schema.scalar "PrecomputedBlockProof" ~doc:"Base-64 encoded proof"
        ~coerce:serialize
  end
end

include Make (Schema)

let%test_module "Roundtrip tests" =
  ( module struct
    include Make (Test_schema)

    let%test_module "PrecomputedBlockProof" =
      ( module struct
        module PrecomputedBlockProof_gen = struct
          open Core_kernel
          module Nat = Pickles_types.Nat
          include Mina_block.Precomputed.Proof

          let compare = Poly.compare

          (* Sample gotten from: lib/prover/prover.ml *)
          let example : t =
            Pickles.Proof.dummy Nat.N2.n Nat.N2.n Nat.N2.n ~domain_log2:16

          (* TODO: find better ways to generate `Mina_block.Precomputed.Proof.t` values *)
          let gen = Quickcheck.Generator.return example
        end

        include Make_test (PrecomputedBlockProof) (PrecomputedBlockProof_gen)
      end )
  end )
