module PrecomputedBlockProof :
  Graphql_basic_scalars.Json_intf with type t = Mina_block.Precomputed.Proof.t =
struct
  open Mina_block.Precomputed.Proof

  type nonrec t = t

  let parse json = Yojson.Basic.Util.to_string json |> of_bin_string

  let serialize t = `String (to_bin_string t)

  let typ () =
    Graphql_async.Schema.scalar "PrecomputedBlockProof"
      ~doc:"Base-64 encoded proof" ~coerce:serialize
end

(* TESTS *)
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

let%test_module "PrecomputedBlockProof" =
  ( module Graphql_basic_scalars.Make_test
             (PrecomputedBlockProof)
             (PrecomputedBlockProof_gen) )
