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
  (* the accounts_accessed, accounts_created, and tokens_used fields
     are used for storing blocks in the archive db, they're not needed
     for replaying blocks

     in tokens_used, the account id is the token owner
  *)
  type t =
    { scheduled_time : Block_time.t
    ; protocol_state : Protocol_state.value
    ; protocol_state_proof : Proof.t
    ; staged_ledger_diff : Staged_ledger_diff.t
    ; delta_transition_chain_proof :
        Frozen_ledger_hash.t * Frozen_ledger_hash.t list
    ; accounts_accessed : (int * Account.t) list
    ; accounts_created : (Account_id.t * Currency.Fee.t) list
    ; tokens_used : (Token_id.t * Account_id.t option) list
    }
  [@@deriving sexp, yojson]
end

include T

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V3 = struct
    type t = T.t =
      { scheduled_time : Block_time.Stable.V1.t
      ; protocol_state : Protocol_state.Value.Stable.V2.t
      ; protocol_state_proof : Mina_base.Proof.Stable.V2.t
      ; staged_ledger_diff : Staged_ledger_diff.Stable.V2.t
            (* TODO: Delete this or find out why it is here. *)
      ; delta_transition_chain_proof :
          Frozen_ledger_hash.Stable.V1.t * Frozen_ledger_hash.Stable.V1.t list
      ; accounts_accessed : (int * Account.Stable.V2.t) list
      ; accounts_created :
          (Account_id.Stable.V2.t * Currency.Fee.Stable.V1.t) list
      ; tokens_used :
          (Token_id.Stable.V1.t * Account_id.Stable.V2.t option) list
      }

    let to_latest = Fn.id
  end
end]

let of_block ~logger
    ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    ~scheduled_time ~staged_ledger block_with_hash =
  let ledger = Staged_ledger.ledger staged_ledger in
  let block = With_hash.data block_with_hash in
  let state_hash =
    (With_hash.hash block_with_hash).State_hash.State_hashes.state_hash
  in
  let account_ids_accessed = Block.account_ids_accessed block in
  let start = Time.now () in
  let accounts_accessed =
    List.filter_map account_ids_accessed ~f:(fun acct_id ->
        try
          let index = Mina_ledger.Ledger.index_of_account_exn ledger acct_id in
          let account = Mina_ledger.Ledger.get_at_index_exn ledger index in
          Some (index, account)
        with exn ->
          [%log error]
            "When computing accounts accessed for precomputed block, exception \
             when finding account id in staged ledger"
            ~metadata:
              [ ("account_id", Account_id.to_yojson acct_id)
              ; ("exception", `String (Exn.to_string exn))
              ] ;
          None )
  in
  let header = Block.header block in
  let accounts_accessed_time = Time.now () in
  [%log debug]
    "Precomputed block for $state_hash: accounts-accessed took $time ms"
    ~metadata:
      [ ("state_hash", Mina_base.State_hash.to_yojson state_hash)
      ; ( "time"
        , `Float (Time.Span.to_ms (Time.diff accounts_accessed_time start)) )
      ] ;
  let accounts_created =
    let account_creation_fee = constraint_constants.account_creation_fee in
    let previous_block_state_hash =
      Mina_state.Protocol_state.previous_state_hash
        (Header.protocol_state header)
    in
    List.map
      (Staged_ledger.latest_block_accounts_created staged_ledger
         ~previous_block_state_hash ) ~f:(fun acct_id ->
        (acct_id, account_creation_fee) )
  in
  let tokens_used =
    let unique_tokens =
      List.map account_ids_accessed ~f:Account_id.token_id
      |> List.dedup_and_sort ~compare:Token_id.compare
    in
    List.map unique_tokens ~f:(fun token_id ->
        let owner = Mina_ledger.Ledger.token_owner ledger token_id in
        (token_id, owner) )
  in
  let account_created_time = Time.now () in
  [%log debug]
    "Precomputed block for $state_hash: accounts-created took $time ms"
    ~metadata:
      [ ("state_hash", Mina_base.State_hash.to_yojson state_hash)
      ; ( "time"
        , `Float
            (Time.Span.to_ms
               (Time.diff account_created_time accounts_accessed_time) ) )
      ] ;

  { scheduled_time
  ; protocol_state = Header.protocol_state header
  ; protocol_state_proof = Header.protocol_state_proof header
  ; staged_ledger_diff =
      Staged_ledger_diff.Body.staged_ledger_diff (Block.body block)
  ; delta_transition_chain_proof = Header.delta_block_chain_proof header
  ; accounts_accessed
  ; accounts_created
  ; tokens_used
  }

(* NOTE: This serialization is used externally and MUST NOT change.
    If the underlying types change, you should write a conversion, or add
    optional fields and handle them appropriately.
*)
(* But if you really need to update it, see output of CLI command:
   `PRINT_BLOCKS=1 dune runtest src/lib/transition_frontier/tests/ 2> block.txt` *)
let%test_unit "Sexp serialization is stable" =
  let serialized_block = Sample_precomputed_block.sample_block_sexp in
  ignore @@ t_of_sexp @@ Sexp.of_string serialized_block

let%test_unit "Sexp serialization roundtrips" =
  let serialized_block = Sample_precomputed_block.sample_block_sexp in
  let sexp = Sexp.of_string serialized_block in
  let sexp_roundtrip = sexp_of_t @@ t_of_sexp sexp in
  [%test_eq: Sexp.t] sexp sexp_roundtrip

(* NOTE: This serialization is used externally and MUST NOT change.
    If the underlying types change, you should write a conversion, or add
    optional fields and handle them appropriately.
*)
(* But if you really need to update it, see output of CLI command:
   `PRINT_BLOCKS=1 dune runtest src/lib/transition_frontier/tests/ 2> block.txt` *)
let%test_unit "JSON serialization is stable" =
  let serialized_block = Sample_precomputed_block.sample_block_json in
  match of_yojson @@ Yojson.Safe.from_string serialized_block with
  | Ok _ ->
      ()
  | Error err ->
      failwith err

let%test_unit "JSON serialization roundtrips" =
  let serialized_block = Sample_precomputed_block.sample_block_json in
  let json = Yojson.Safe.from_string serialized_block in
  let json_roundtrip =
    match Result.map ~f:to_yojson @@ of_yojson json with
    | Ok json ->
        json
    | Error err ->
        failwith err
  in
  assert (Yojson.Safe.equal json json_roundtrip)
