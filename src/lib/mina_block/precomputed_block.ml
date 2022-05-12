open Core_kernel
open Mina_base
open Mina_state

module Proof = struct
  type t = Proof.t

  let to_bin_string proof =
    let proof_string = Binable.to_string (module Proof.Stable.Latest) proof in
    (* We use base64 with the uri-safe alphabet to ensure that encoding and
        decoding is cheap, and that the proof can be easily sent over http
        etc. without escaping or re-encoding.
    *)
    Base64.encode_string ~alphabet:Base64.uri_safe_alphabet proof_string

  let of_bin_string str =
    let str = Base64.decode_exn ~alphabet:Base64.uri_safe_alphabet str in
    Binable.of_string (module Proof.Stable.Latest) str

  let sexp_of_t proof = Sexp.Atom (to_bin_string proof)

  let _sexp_of_t_structured = Proof.sexp_of_t

  (* Supports decoding base64-encoded and structure encoded proofs. *)
  let t_of_sexp = function
    | Sexp.Atom str ->
        of_bin_string str
    | sexp ->
        Proof.t_of_sexp sexp

  let to_yojson proof = `String (to_bin_string proof)

  let _to_yojson_structured = Proof.to_yojson

  let of_yojson = function
    | `String str ->
        Or_error.try_with (fun () -> of_bin_string str)
        |> Result.map_error ~f:(fun err ->
               sprintf "Precomputed_block.Proof.of_yojson: %s"
                 (Error.to_string_hum err) )
    | json ->
        Proof.of_yojson json
end

module T = struct
  type t =
    { scheduled_time : Block_time.t
    ; protocol_state : Protocol_state.value
    ; protocol_state_proof : Proof.t
    ; staged_ledger_diff : Staged_ledger_diff.t
    ; delta_transition_chain_proof :
        Frozen_ledger_hash.t * Frozen_ledger_hash.t list
    }
  [@@deriving sexp, yojson]
end

include T

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t = T.t =
      { scheduled_time : Block_time.Stable.V1.t
      ; protocol_state : Protocol_state.Value.Stable.V1.t
      ; protocol_state_proof : Mina_base.Proof.Stable.V1.t
      ; staged_ledger_diff : Staged_ledger_diff.Stable.V1.t
      ; delta_transition_chain_proof :
          Frozen_ledger_hash.Stable.V1.t * Frozen_ledger_hash.Stable.V1.t list
      }

    let to_latest = Fn.id
  end
end]

let of_block ~scheduled_time (t : Block.t) =
  { scheduled_time
  ; protocol_state = Header.protocol_state (Block.header t)
  ; protocol_state_proof = Header.protocol_state_proof (Block.header t)
  ; staged_ledger_diff = Body.staged_ledger_diff (Block.body t)
  ; delta_transition_chain_proof =
      Header.delta_block_chain_proof (Block.header t)
  }

(* NOTE: This serialization is used externally and MUST NOT change.
    If the underlying types change, you should write a conversion, or add
    optional fields and handle them appropriately.
*)
let%test_unit "Sexp serialization is stable" =
  let serialized_block =
    External_transition_sample_precomputed_block.sample_block_sexp
  in
  ignore @@ t_of_sexp @@ Sexp.of_string serialized_block

let%test_unit "Sexp serialization roundtrips" =
  let serialized_block =
    External_transition_sample_precomputed_block.sample_block_sexp
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
    External_transition_sample_precomputed_block.sample_block_json
  in
  match of_yojson @@ Yojson.Safe.from_string serialized_block with
  | Ok _ ->
      ()
  | Error err ->
      failwith err

let%test_unit "JSON serialization roundtrips" =
  let serialized_block =
    External_transition_sample_precomputed_block.sample_block_json
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
