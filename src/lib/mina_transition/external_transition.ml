open Core_kernel
open Mina_base
open Mina_state

type t = Block.t

(* this module exists only as a stub to keep the bin_io for external transition from changing *)
module Validate_content = struct
  type t = unit

  let bin_read_t buf ~pos_ref = bin_read_unit buf ~pos_ref

  let bin_write_t buf ~pos _ = bin_write_unit buf ~pos ()

  let bin_shape_t = bin_shape_unit

  let bin_size_t _ = bin_size_unit ()

  let t_of_sexp _ = ()

  let sexp_of_t _ = sexp_of_unit ()

  let compare _ _ = 0

  let __versioned__ = ()
end

module Raw = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      module T = struct
        type t =
          { protocol_state : Protocol_state.Value.Stable.V2.t
          ; protocol_state_proof : Proof.Stable.V2.t [@sexp.opaque]
          ; staged_ledger_diff : Staged_ledger_diff.Stable.V2.t
          ; delta_transition_chain_proof :
              State_hash.Stable.V1.t * State_body_hash.Stable.V1.t list
          ; current_protocol_version : Protocol_version.Stable.V1.t
          ; proposed_protocol_version_opt : Protocol_version.Stable.V1.t option
          ; mutable validation_callback : Validate_content.t
          }
        [@@deriving compare, sexp, fields]
      end

      let to_latest = Fn.id

      include T

      include (
        Allocation_functor.Make.Bin_io_and_sexp (struct
          let id = "external_transition"

          include T

          let create ~protocol_state ~protocol_state_proof ~staged_ledger_diff
              ~delta_transition_chain_proof ?proposed_protocol_version_opt () =
            let current_protocol_version =
              try Protocol_version.get_current ()
              with _ ->
                failwith
                  "Cannot create external transition before setting current \
                   protocol version"
            in
            { protocol_state
            ; protocol_state_proof
            ; staged_ledger_diff
            ; delta_transition_chain_proof
            ; current_protocol_version
            ; proposed_protocol_version_opt
            ; validation_callback = ()
            }

          type 'a creator =
               protocol_state:Protocol_state.Value.t
            -> protocol_state_proof:Proof.t
            -> staged_ledger_diff:Staged_ledger_diff.t
            -> delta_transition_chain_proof:
                 State_hash.t * State_body_hash.t list
            -> ?proposed_protocol_version_opt:Protocol_version.t
            -> unit
            -> 'a

          let map_creator c ~f ~protocol_state ~protocol_state_proof
              ~staged_ledger_diff ~delta_transition_chain_proof
              ?proposed_protocol_version_opt () =
            f
              (c ~protocol_state ~protocol_state_proof ~staged_ledger_diff
                 ~delta_transition_chain_proof ?proposed_protocol_version_opt
                 ())
        end) :
          sig
            val create :
                 protocol_state:Protocol_state.Value.t
              -> protocol_state_proof:Proof.t
              -> staged_ledger_diff:Staged_ledger_diff.t
              -> delta_transition_chain_proof:
                   State_hash.t * State_body_hash.t list
              -> ?proposed_protocol_version_opt:Protocol_version.t
              -> unit
              -> t

            include Binable.S with type t := T.t

            include Sexpable.S with type t := T.t
          end )
    end
  end]

  include T

  [%%define_locally
  Stable.Latest.(protocol_state, create, sexp_of_t, t_of_sexp)]
end

type external_transition = Raw.t

(*
type t_ = Raw_versioned__.t =
  { protocol_state: Protocol_state.Value.t
  ; protocol_state_proof: Proof.t [@sexp.opaque]
  ; staged_ledger_diff: Staged_ledger_diff.t
  ; delta_transition_chain_proof: State_hash.t * State_body_hash.t list
  ; current_protocol_version: Protocol_version.t
  ; proposed_protocol_version_opt: Protocol_version.t option
*)

let consensus_state =
  Fn.compose Protocol_state.consensus_state
    (Fn.compose Header.protocol_state Block.header)

let blockchain_state =
  Fn.compose Protocol_state.blockchain_state
    (Fn.compose Header.protocol_state Block.header)

let state_hashes =
  Fn.compose Protocol_state.hashes
    (Fn.compose Header.protocol_state Block.header)

let parent_hash =
  Fn.compose Protocol_state.previous_state_hash
    (Fn.compose Header.protocol_state Block.header)

let blockchain_length =
  Fn.compose Consensus.Data.Consensus_state.blockchain_length consensus_state

let consensus_time_produced_at =
  Fn.compose Consensus.Data.Consensus_state.consensus_time consensus_state

let global_slot =
  Fn.compose Consensus.Data.Consensus_state.curr_global_slot consensus_state

let block_producer =
  Fn.compose Consensus.Data.Consensus_state.block_creator consensus_state

let coinbase_receiver =
  Fn.compose Consensus.Data.Consensus_state.coinbase_receiver consensus_state

let supercharge_coinbase =
  Fn.compose Consensus.Data.Consensus_state.supercharge_coinbase consensus_state

let block_winner =
  Fn.compose Consensus.Data.Consensus_state.block_stake_winner consensus_state

let commands =
  Fn.compose Staged_ledger_diff.commands
    (Fn.compose Body.staged_ledger_diff Block.body)

let completed_works =
  Fn.compose Staged_ledger_diff.completed_works
    (Fn.compose Body.staged_ledger_diff @@ Block.body)

let transactions ~constraint_constants t =
  let open Staged_ledger.Pre_diff_info in
  let coinbase_receiver =
    Consensus.Data.Consensus_state.coinbase_receiver (consensus_state t)
  in
  let supercharge_coinbase =
    Consensus.Data.Consensus_state.supercharge_coinbase (consensus_state t)
  in
  match
    get_transactions ~constraint_constants ~coinbase_receiver
      ~supercharge_coinbase
      (Body.staged_ledger_diff @@ Block.body t)
  with
  | Ok transactions ->
      transactions
  | Error e ->
      Core.Error.raise (Error.to_error e)

let payments t =
  List.filter_map (commands t) ~f:(function
    | { data = Signed_command ({ payload = { body = Payment _; _ }; _ } as c)
      ; status
      } ->
        Some { With_status.data = c; status }
    | _ ->
        None)

let timestamp =
  Fn.compose Blockchain_state.timestamp
    (Fn.compose Protocol_state.blockchain_state Raw.protocol_state)

type protocol_version_status =
  { valid_current : bool; valid_next : bool; matches_daemon : bool }

let protocol_version_status t =
  let header = Block.header t in
  let valid_current =
    Protocol_version.is_valid (Header.current_protocol_version header)
  in
  let valid_next =
    Option.for_all
      (Header.proposed_protocol_version_opt header)
      ~f:Protocol_version.is_valid
  in
  let matches_daemon =
    Protocol_version.compatible_with_daemon
      (Header.current_protocol_version header)
  in
  { valid_current; valid_next; matches_daemon }

let decompose
    { Raw.Stable.V2.protocol_state
    ; protocol_state_proof
    ; staged_ledger_diff
    ; delta_transition_chain_proof
    ; current_protocol_version
    ; proposed_protocol_version_opt
    ; validation_callback = ()
    } =
  let body = Body.create staged_ledger_diff in
  let body_reference = Body_reference.of_body body in
  let header =
    Header.create ~protocol_state ~protocol_state_proof
      ~delta_block_chain_proof:delta_transition_chain_proof
      ?proposed_protocol_version_opt ~body_reference ~current_protocol_version
      ()
  in
  Block.create ~header ~body

let compose block =
  let b = Block.body block in
  let h = Block.header block in
  Raw.create ~protocol_state:(Header.protocol_state h)
    ~protocol_state_proof:(Header.protocol_state_proof h)
    ~staged_ledger_diff:(Body.staged_ledger_diff b)
    ~delta_transition_chain_proof:(Header.delta_block_chain_proof h)
    ?proposed_protocol_version_opt:(Header.proposed_protocol_version_opt h)
    ()

let raw_v1_to_yojson t =
  let open Raw in
  `Assoc
    [ ("protocol_state", Protocol_state.value_to_yojson (protocol_state t))
    ; ("protocol_state_proof", `String "<opaque>")
    ; ("staged_ledger_diff", `String "<opaque>")
    ; ("delta_transition_chain_proof", `String "<opaque>")
    ; ( "current_protocol_version"
      , `String (Protocol_version.to_string t.current_protocol_version) )
    ; ( "proposed_protocol_version"
      , `String
          (Option.value_map t.proposed_protocol_version_opt ~default:"<None>"
             ~f:Protocol_version.to_string) )
    ]

module Validated = struct
  [%%versioned
  module Stable = struct
    module V3 = struct
      type t =
        Raw.Stable.V2.t State_hash.With_state_hashes.Stable.V1.t
        * State_hash.Stable.V1.t Non_empty_list.Stable.V1.t
      [@@deriving sexp]

      let to_yojson (transition_with_hash, _) =
        State_hash.With_state_hashes.to_yojson raw_v1_to_yojson
          transition_with_hash

      let to_latest = Fn.id
    end
  end]

  [%%define_locally Stable.Latest.(to_yojson)]

  let lift validated_block =
    let transition =
      validated_block |> Mina_block.Validated.forget |> With_hash.map ~f:compose
    in
    let delta_block_chain_proof =
      Mina_block.Validated.delta_block_chain_proof validated_block
    in
    (transition, delta_block_chain_proof)

  let lower (transition, delta_block_chain_proof) =
    let block = With_hash.map transition ~f:decompose in
    Mina_block.Validated.unsafe_of_trusted_block ~delta_block_chain_proof
      (`This_block_is_trusted_to_be_safe block)
end

let proposed_protocol_version_opt =
  Fn.compose Header.proposed_protocol_version_opt Block.header

let current_protocol_version =
  Fn.compose Header.current_protocol_version Block.header

let delta_transition_chain_proof =
  Fn.compose Header.delta_block_chain_proof Block.header

let staged_ledger_diff = Fn.compose Body.staged_ledger_diff Block.body

let protocol_state_proof = Fn.compose Header.protocol_state_proof Block.header

let protocol_state = Fn.compose Header.protocol_state Block.header

[%%define_locally Block.(t_of_sexp, sexp_of_t, to_yojson)]

module Precomputed_block = struct
  (* precomputed blocks serve two purposes:
     - to start the daemon with replayed blocks
     - for archiving, so that blocks can be added to the archive database
        if blocks are missing
  *)
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
                 sprintf
                   "External_transition.Precomputed_block.Proof.of_yojson: %s"
                   (Error.to_string_hum err))
      | json ->
          Proof.of_yojson json
  end

  module T = struct
    (* the accounts_accessed and accounts_created fields are used
       for storing blocks in the archive db, they're not needed
       for replaying blocks
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
            (* TODO : list of token ids and owners created *)
      }
    [@@deriving sexp, yojson]
  end

  include T

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
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
        }

      let to_latest = Fn.id
    end
  end]

  let of_block ~logger
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~scheduled_time ~staged_ledger block =
    let ledger = Staged_ledger.ledger staged_ledger in
    let account_ids_accessed = Mina_block.account_ids_accessed block in
    let accounts_accessed =
      List.filter_map account_ids_accessed ~f:(fun acct_id ->
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
            None)
    in
    let accounts_created =
      let account_creation_fee = constraint_constants.account_creation_fee in
      let previous_block_state_hash =
        protocol_state block |> Mina_state.Protocol_state.previous_state_hash
      in
      List.map
        (Staged_ledger.latest_block_accounts_created staged_ledger
           ~previous_block_state_hash) ~f:(fun acct_id ->
          (acct_id, account_creation_fee))
    in
    { scheduled_time
    ; protocol_state = protocol_state block
    ; protocol_state_proof = protocol_state_proof block
    ; staged_ledger_diff = staged_ledger_diff block
    ; delta_transition_chain_proof = delta_transition_chain_proof block
    ; accounts_accessed
    ; accounts_created
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
end
