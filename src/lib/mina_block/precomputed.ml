open Core_kernel
open Mina_base
open Mina_state

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t =
      { scheduled_time : Block_time.Stable.V1.t
      ; protocol_state : Protocol_state.Value.Stable.V1.t
      ; protocol_state_proof : Proof.Stable.V1.t
      ; staged_ledger_diff : Staged_ledger_diff.Stable.V1.t
      ; delta_block_chain_proof :
          Frozen_ledger_hash.Stable.V1.t * Frozen_ledger_hash.Stable.V1.t list
      }
    [@@deriving sexp, yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t

[%%define_locally
Stable.Latest.(sexp_of_t, t_of_sexp, to_yojson, of_yojson)]

(* NOTE: This serialization is used externally and MUST NOT change.
   If the underlying types change, you should write a conversion, or add
   optional fields and handle them appropriately.
*)
let%test_unit "Sexp serialization is stable" =
  let serialized_block =
    Sample_precomputed_block.sample_block_sexp
  in
  ignore @@ t_of_sexp @@ Sexp.of_string serialized_block

let%test_unit "Sexp serialization roundtrips" =
  let serialized_block =
    Sample_precomputed_block.sample_block_sexp
  in
  let sexp = Sexp.of_string serialized_block in
  let sexp_roundtrip = sexp_of_t @@ t_of_sexp sexp in
  [%test_eq: Sexp.t] sexp sexp_roundtrip

(* NOTE: This serialization is used externally and MUST NOT change.
   If the underlying types change, you should write a conversion, or add
   optional fields and handle them appropriately.
*)
let%test_unit "JSON serialization is stable" =
  let serialized_block =
    Sample_precomputed_block.sample_block_json
  in
  match of_yojson @@ Yojson.Safe.from_string serialized_block with
  | Ok _ ->
      ()
  | Error err ->
      failwith err

let%test_unit "JSON serialization roundtrips" =
  let serialized_block =
    Sample_precomputed_block.sample_block_json
  in
  let json = Yojson.Safe.from_string serialized_block in
  let json_roundtrip =
    match Result.map ~f:to_yojson @@ of_yojson json with
    | Ok json ->
        json
    | Error err ->
        failwith err
  in
  assert (Yojson.Safe.equal json json_roundtrip)
