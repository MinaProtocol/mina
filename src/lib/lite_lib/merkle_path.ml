open Bin_prot.Std
open Fold_lib
open Lite_base

type elem = [`Left of Pedersen.Digest.t | `Right of Pedersen.Digest.t]
[@@deriving bin_io]

type t = elem list [@@deriving bin_io]

let merge ~height h1 h2 =
  let open Pedersen in
  digest_fold
    (State.salt Lite_params.pedersen_params
       (Hash_prefixes.merkle_tree height :> string))
    Fold.(Digest.fold h1 +> Digest.fold h2)

open Base

let implied_root (t : t) leaf_hash =
  List.fold t ~init:(leaf_hash, 0) ~f:(fun (acc, height) elem ->
      let acc =
        match elem with
        | `Left h -> merge ~height acc h
        | `Right h -> merge ~height h acc
      in
      (acc, height + 1) )
  |> fst
