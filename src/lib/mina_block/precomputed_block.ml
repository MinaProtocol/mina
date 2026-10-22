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
    ; staged_ledger_diff : Legacy_format.Staged_ledger_diff.Stable.Latest.t
    ; delta_transition_chain_proof :
        Frozen_ledger_hash.t * Frozen_ledger_hash.t list
    ; protocol_version : Protocol_version.t
    ; proposed_protocol_version : Protocol_version.t option [@default None]
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

  [@@@with_versioned_json]

  module V5 = struct
    type t = T.t =
      { scheduled_time : Block_time.Stable.V1.t
      ; protocol_state : Protocol_state.Value.Stable.V4.t
      ; protocol_state_proof : Mina_base.Proof.Stable.V2.t
      ; staged_ledger_diff : Legacy_format.Staged_ledger_diff.Stable.V3.t
            (* TODO: Delete this or find out why it is here. *)
      ; delta_transition_chain_proof :
          Frozen_ledger_hash.Stable.V1.t * Frozen_ledger_hash.Stable.V1.t list
      ; protocol_version : Protocol_version.Stable.V2.t
      ; proposed_protocol_version : Protocol_version.Stable.V2.t option
      ; accounts_accessed : (int * Account.Stable.V3.t) list
      ; accounts_created :
          (Account_id.Stable.V2.t * Currency.Fee.Stable.V1.t) list
      ; tokens_used :
          (Token_id.Stable.V2.t * Account_id.Stable.V2.t option) list
      }

    let to_latest = Fn.id
  end

  module V4 = struct
    type t =
      { scheduled_time : Block_time.Stable.V1.t
      ; protocol_state : Protocol_state.Value.Stable.V3.t
      ; protocol_state_proof :
          (Mina_base.Proof.Stable.V2.t
          [@to_yojson Proof.to_yojson] [@of_yojson Proof.of_yojson] )
      ; staged_ledger_diff : Legacy_format.Staged_ledger_diff.Stable.V2.t
            (* TODO: Delete this or find out why it is here. *)
      ; delta_transition_chain_proof :
          Frozen_ledger_hash.Stable.V1.t * Frozen_ledger_hash.Stable.V1.t list
      ; protocol_version : Protocol_version.Stable.V2.t
      ; proposed_protocol_version : Protocol_version.Stable.V2.t option
            [@default None]
      ; accounts_accessed : (int * Account.Stable.V3.t) list
      ; accounts_created :
          (Account_id.Stable.V2.t * Currency.Fee.Stable.V1.t) list
      ; tokens_used :
          (Token_id.Stable.V2.t * Account_id.Stable.V2.t option) list
      }
    [@@deriving yojson]

    let to_latest
        ({ scheduled_time
         ; protocol_state
         ; protocol_state_proof
         ; staged_ledger_diff
         ; delta_transition_chain_proof
         ; protocol_version
         ; proposed_protocol_version
         ; accounts_accessed
         ; accounts_created
         ; tokens_used
         } :
          t ) : Latest.t =
      { scheduled_time
      ; protocol_state = Protocol_state.Value.Stable.V3.to_latest protocol_state
      ; protocol_state_proof
      ; staged_ledger_diff =
          Legacy_format.Staged_ledger_diff.Stable.V2.to_latest
            staged_ledger_diff
      ; delta_transition_chain_proof
      ; protocol_version
      ; proposed_protocol_version
      ; accounts_accessed
      ; accounts_created
      ; tokens_used
      }
  end
end]

(* functions for the versioned json, not the unversioned ones provided by `T` *)
[%%define_locally Stable.Latest.(to_yojson, of_yojson)]

let of_block ~logger
    ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    ~scheduled_time ~staged_ledger ~accounts_created block_with_hash =
  let ledger = Staged_ledger.ledger staged_ledger in
  let block = With_hash.data block_with_hash in
  let state_hash =
    (With_hash.hash block_with_hash).State_hash.State_hashes.state_hash
  in
  let account_ids_accessed =
    Block.account_ids_accessed ~constraint_constants block
  in
  let start = Time.now () in
  let accounts_accessed =
    List.filter_map account_ids_accessed ~f:(fun (acct_id, status) ->
        match status with
        | `Not_accessed ->
            None
        | `Accessed -> (
            try
              let index =
                Mina_ledger.Ledger.index_of_account_exn ledger acct_id
              in
              let account = Mina_ledger.Ledger.get_at_index_exn ledger index in
              Some (index, account)
            with exn ->
              [%log error]
                "When computing accounts accessed for precomputed block, \
                 exception when finding account id in staged ledger"
                ~metadata:
                  [ ("account_id", Account_id.to_yojson acct_id)
                  ; ("exception", `String (Exn.to_string exn))
                  ] ;
              None ) )
  in
  let header = Block.header block in
  let protocol_version = Header.current_protocol_version header in
  let proposed_protocol_version = Header.proposed_protocol_version_opt header in
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
    List.map accounts_created ~f:(fun acct_id ->
        (acct_id, account_creation_fee) )
  in
  let tokens_used =
    let unique_tokens =
      (* a token is used regardless of status *)
      List.map account_ids_accessed ~f:(fun (acct_id, _status) ->
          Account_id.token_id acct_id )
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
      |> Staged_ledger_diff.read_all_proofs_from_disk
  ; delta_transition_chain_proof = Header.delta_block_chain_proof header
  ; protocol_version
  ; proposed_protocol_version
  ; accounts_accessed
  ; accounts_created
  ; tokens_used
  }

module V3 = struct
  type t =
    { scheduled_time : Block_time.Stable.V1.t
    ; protocol_state : Protocol_state.Value.Stable.V3.t
    ; protocol_state_proof : Proof.t
    ; staged_ledger_diff : Berkeley_types.Diff.t
    ; delta_transition_chain_proof :
        Frozen_ledger_hash.Stable.V1.t * Frozen_ledger_hash.Stable.V1.t list
    ; protocol_version : Protocol_version.Stable.V2.t
    ; proposed_protocol_version : Protocol_version.Stable.V2.t option
          [@default None]
    ; accounts_accessed : (int * Berkeley_types.Account.Stable.V2.t) list
    ; accounts_created :
        (Account_id.Stable.V2.t * Currency.Fee.Stable.V1.t) list
    ; tokens_used : (Token_id.Stable.V2.t * Account_id.Stable.V2.t option) list
    }
  [@@deriving yojson]
end

module Versioned = struct
  type t = V5 of Stable.V5.t | V4 of Stable.V4.t | V3 of V3.t

  let version = function V5 _ -> 5 | V4 _ -> 4 | V3 _ -> 3

  let of_latest (t : Stable.Latest.t) = V5 t

  let latest = function V5 t -> Some t | V4 _ | V3 _ -> None

  let to_yojson = function
    | V5 t ->
        Stable.V5.to_yojson t
    | V4 t ->
        Stable.V4.to_yojson t
    | V3 t ->
        `Assoc [ ("version", `Int 3); ("data", V3.to_yojson t) ]

  let of_yojson json =
    let open Result.Let_syntax in
    let%bind fields =
      match json with
      | `Assoc fields ->
          Ok fields
      | _ ->
          Error "Precomputed.Versioned.of_yojson: expected an object"
    in
    let%bind version =
      match List.Assoc.find fields ~equal:String.equal "version" with
      | Some (`Int version) ->
          Ok version
      | _ ->
          Error "Precomputed.Versioned.of_yojson: missing version tag"
    in
    match version with
    | 5 ->
        Stable.V5.of_yojson json >>| fun t -> V5 t
    | 4 ->
        Stable.V4.of_yojson json >>| fun t -> V4 t
    | 3 -> (
        match List.Assoc.find fields ~equal:String.equal "data" with
        | Some data ->
            V3.of_yojson data >>| fun t -> V3 t
        | None ->
            Error "Precomputed.Versioned.of_yojson: missing data" )
    | _ ->
        Error
          (sprintf "Precomputed.Versioned.of_yojson: unsupported version %d"
             version )

  module V5 = struct
    let state_hashes (t : Stable.V5.t) = Protocol_state.hashes t.protocol_state
  end

  module V4 = struct
    let state_hashes (t : Stable.V4.t) =
      Protocol_state.Value.Stable.V3.hashes t.protocol_state
  end

  module V3 = struct
    (* The protocol state of a V3 block has the type of a V4 block's, and its
       hash is computed in the same way. *)
    let state_hashes (t : V3.t) =
      Protocol_state.Value.Stable.V3.hashes t.protocol_state
  end

  let state_hashes = function
    | V5 t ->
        V5.state_hashes t
    | V4 t ->
        V4.state_hashes t
    | V3 t ->
        V3.state_hashes t
end
