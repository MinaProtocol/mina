open Async
open Core
open Mina_base
open Mina_ledger
open Network_peer

(* For versioning of the types here, see

   RFC 0012, and

   https://ocaml.janestreet.com/ocaml-core/latest/doc/async_rpc_kernel/Async_rpc_kernel/Versioned_rpc/

   The "master" types are the ones used internally in the code base. Each
   version has coercions between their query and response types and the master
   types.
*)

(* The common context passed into all rpc handlers. Add new things here to get them into the scope
   of an rpc handler. Notably, calls back into Gossip_net need to be expicitly wrapped at this
   layer in order to solve a recursive dependency between Gossip_net.Make and this module. *)

module type CONTEXT = sig
  val logger : Logger.t

  val trust_system : Trust_system.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val list_peers : unit -> Peer.t list Deferred.t

  val get_transition_frontier : unit -> Transition_frontier.t option

  val get_snark_pool : unit -> Network_pool.Snark_pool.t option

  val snark_job_state : unit -> Work_selector.State.t option

  val ledger_sync_config : Syncable_ledger.daemon_config

  val proof_cache_db : Proof_cache_tag.cache_db

  val signature_kind : Mina_signature_kind.t
end

type ctx = (module CONTEXT)

let validate_protocol_versions ~logger ~trust_system ~rpc_name ~sender headers =
  let version_errors =
    let invalid_current_versions =
      List.filter headers ~f:(fun header ->
          Mina_block.Header.current_protocol_version header
          |> Protocol_version.is_valid |> not )
    in

    let invalid_next_versions =
      List.filter headers ~f:(fun header ->
          Mina_block.Header.proposed_protocol_version_opt header
          |> Option.for_all ~f:Protocol_version.is_valid
          |> not )
    in
    let current_version_mismatches =
      List.filter headers ~f:(fun header ->
          Mina_block.Header.current_protocol_version header
          |> Protocol_version.compatible_with_daemon |> not )
    in
    List.map invalid_current_versions ~f:(fun x ->
        (`Invalid_current_version, x) )
    @ List.map invalid_next_versions ~f:(fun x -> (`Invalid_next_version, x))
    @ List.map current_version_mismatches ~f:(fun x ->
          (`Current_version_mismatch, x) )
  in
  let%map () =
    (* NB: these errors aren't always accurate... sometimes we are calling this when we were
           requested to serve an outdated block (requested vs sent) *)
    Deferred.List.iter version_errors ~how:`Parallel
      ~f:(fun (version_error, header) ->
        let block_protocol_version =
          Mina_block.Header.current_protocol_version header
        in
        let proposed_protocol_version =
          Mina_block.Header.proposed_protocol_version_opt header
        in
        let action, error_msg, error_metadata =
          match version_error with
          | `Invalid_current_version ->
              ( Trust_system.Actions.Sent_invalid_protocol_version
              , "block with invalid current protocol version"
              , [ ( "block_current_protocol_version"
                  , `String (Protocol_version.to_string block_protocol_version)
                  )
                ] )
          | `Invalid_next_version ->
              ( Trust_system.Actions.Sent_invalid_protocol_version
              , "block with invalid proposed protocol version"
              , [ ( "block_proposed_protocol_version"
                  , `String
                      (Protocol_version.to_string
                         (Option.value_exn proposed_protocol_version) ) )
                ] )
          | `Current_version_mismatch ->
              ( Sent_mismatched_protocol_version
              , "current protocol version in block does not match daemon \
                 current protocol version"
              , [ ( "block_current_protocol_version"
                  , `String (Protocol_version.to_string block_protocol_version)
                  )
                ; ( "daemon_current_protocol_version"
                  , `String Protocol_version.(to_string current) )
                ] )
        in
        let msg =
          Some
            ( Printf.sprintf "$rpc_name: %s" error_msg
            , [ ("rpc_name", `String rpc_name) ] @ error_metadata )
        in
        Trust_system.record_envelope_sender trust_system logger sender
          (action, msg) )
  in
  List.is_empty version_errors

[%%versioned_rpc
module Get_some_initial_peers = struct
  type nonrec ctx = ctx

  module Master = struct
    let name = "get_some_initial_peers"

    module T = struct
      type query = unit [@@deriving sexp, yojson]

      type response = Peer.t list [@@deriving sexp, yojson]
    end

    module Caller = T
    module Callee = T
  end

  include Master.T

  let sent_counter = Mina_metrics.Network.get_some_initial_peers_rpcs_sent

  let received_counter =
    Mina_metrics.Network.get_some_initial_peers_rpcs_received

  let failed_request_counter =
    Mina_metrics.Network.get_some_initial_peers_rpc_requests_failed

  let failed_response_counter =
    Mina_metrics.Network.get_some_initial_peers_rpc_responses_failed

  module M = Versioned_rpc.Both_convert.Plain.Make (Master)
  include M

  include Perf_histograms.Rpc.Plain.Extend (struct
    include M
    include Master
  end)

  module V1 = struct
    module T = struct
      type query = unit

      type response = Network_peer.Peer.Stable.V1.t list

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model = Fn.id

      let caller_model_of_response = Fn.id
    end

    module T' =
      Perf_histograms.Rpc.Plain.Decorate_bin_io
        (struct
          include M
          include Master
        end)
        (T)

    include T'
    include Register (T')
  end

  let receipt_trust_action_message _ = ("Get_some_initial_peers query", [])

  let log_request_received ~logger ~sender () =
    [%log trace] "Sending some initial peers to $peer"
      ~metadata:[ ("peer", Peer.to_yojson sender) ]

  let response_is_successful peer_list = not (List.is_empty peer_list)

  let handle_request (module Context : CONTEXT) ~version:_ _request =
    Context.list_peers ()

  let rate_limit_budget = (1, `Per Time.Span.minute)

  let rate_limit_cost = Fn.const 1
end]

[%%versioned_rpc
module Get_staged_ledger_aux_and_pending_coinbases_at_hash = struct
  type nonrec ctx = ctx

  module Master = struct
    let name = "get_staged_ledger_aux_and_pending_coinbases_at_hash"

    module T = struct
      type query = State_hash.t

      type response =
        ( Staged_ledger.Scan_state.Serializable_type.Stable.Latest.t
        * Ledger_hash.t
        * Pending_coinbase.t
        * Mina_state.Protocol_state.value list )
        option
    end

    module Caller = T
    module Callee = T
  end

  include Master.T

  let sent_counter =
    Mina_metrics.Network
    .get_staged_ledger_aux_and_pending_coinbases_at_hash_rpcs_sent

  let received_counter =
    Mina_metrics.Network
    .get_staged_ledger_aux_and_pending_coinbases_at_hash_rpcs_received

  let failed_request_counter =
    Mina_metrics.Network
    .get_staged_ledger_aux_and_pending_coinbases_at_hash_rpc_requests_failed

  let failed_response_counter =
    Mina_metrics.Network
    .get_staged_ledger_aux_and_pending_coinbases_at_hash_rpc_responses_failed

  module M = Versioned_rpc.Both_convert.Plain.Make (Master)
  include M

  include Perf_histograms.Rpc.Plain.Extend (struct
    include M
    include Master
  end)

  module V2 = struct
    module T = struct
      type query = State_hash.Stable.V1.t

      type response =
        ( Staged_ledger.Scan_state.Serializable_type.Stable.V2.t
        * Ledger_hash.Stable.V1.t
        * Pending_coinbase.Stable.V2.t
        * Mina_state.Protocol_state.Value.Stable.V2.t list )
        option

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model = Fn.id

      let caller_model_of_response = Fn.id
    end

    module T' =
      Perf_histograms.Rpc.Plain.Decorate_bin_io
        (struct
          include M
          include Master
        end)
        (T)

    include T'
    include Register (T')
  end

  let receipt_trust_action_message hash =
    ( "Staged ledger and pending coinbases at hash: $hash"
    , [ ("hash", State_hash.to_yojson hash) ] )

  let log_request_received ~logger:_ ~sender:_ _request = ()

  let response_is_successful = Option.is_some

  let handle_request (module Context : CONTEXT) ~version:_ request =
    let open Context in
    let hash = Envelope.Incoming.data request in
    let result =
      let%bind.Option frontier = get_transition_frontier () in
      Sync_handler.get_staged_ledger_aux_and_pending_coinbases_at_hash ~logger
        ~frontier hash
    in
    match result with
    | None ->
        Trust_system.(
          record_envelope_sender trust_system logger
            (Envelope.Incoming.sender request)
            Actions.
              (Requested_unknown_item, Some (receipt_trust_action_message hash)))
        >>| const None
    | Some (scan_state, expected_merkle_root, pending_coinbases, protocol_states)
      ->
        return
          (Some
             ( Staged_ledger.Scan_state.to_serializable_type scan_state
             , expected_merkle_root
             , pending_coinbases
             , protocol_states ) )

  let rate_limit_budget = (4, `Per Time.Span.minute)

  let rate_limit_cost = Fn.const 1
end]

[%%versioned_rpc
module Answer_sync_ledger_query = struct
  type nonrec ctx = ctx

  module Master = struct
    let name = "answer_sync_ledger_query"

    module T = struct
      type query = Ledger_hash.t * Sync_ledger.Query.t

      type response =
        (( Sync_ledger.Answer.t
         , Mina_stdlib.Bounded_types.Wrapped_error.Stable.V1.t )
         Result.t
        [@version_asserted] )
    end

    module Caller = T
    module Callee = T
  end

  include Master.T

  let sent_counter = Mina_metrics.Network.answer_sync_ledger_query_rpcs_sent

  let received_counter =
    Mina_metrics.Network.answer_sync_ledger_query_rpcs_received

  let failed_request_counter =
    Mina_metrics.Network.answer_sync_ledger_query_rpc_requests_failed

  let failed_response_counter =
    Mina_metrics.Network.answer_sync_ledger_query_rpc_responses_failed

  module M = Versioned_rpc.Both_convert.Plain.Make (Master)
  include M

  include Perf_histograms.Rpc.Plain.Extend (struct
    include M
    include Master
  end)

  module V4 = struct
    module T = struct
      type query = Ledger_hash.Stable.V1.t * Sync_ledger.Query.Stable.V2.t
      [@@deriving sexp]

      type response =
        (( Sync_ledger.Answer.Stable.V3.t
         , Mina_stdlib.Bounded_types.Wrapped_error.Stable.V1.t )
         Result.t
        [@version_asserted] )
      [@@deriving sexp]

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model = Fn.id

      let caller_model_of_response = Fn.id
    end

    module T' =
      Perf_histograms.Rpc.Plain.Decorate_bin_io
        (struct
          include M
          include Master
        end)
        (T)

    include T'
    include Register (T')
  end

  module V3 = struct
    module T = struct
      type query = Ledger_hash.Stable.V1.t * Sync_ledger.Query.Stable.V1.t
      [@@deriving sexp]

      type response =
        (( Sync_ledger.Answer.Stable.V2.t
         , Mina_stdlib.Bounded_types.Wrapped_error.Stable.V1.t )
         Result.t
        [@version_asserted] )
      [@@deriving sexp]

      let query_of_caller_model : Master.T.query -> query =
       fun (h, q) -> (h, Sync_ledger.Query.Stable.V1.from_v2 q)

      let callee_model_of_query : query -> Master.T.query =
       fun (h, q) -> (h, Sync_ledger.Query.Stable.V1.to_latest q)

      let response_of_callee_model : Master.T.response -> response = function
        | Ok a ->
            Sync_ledger.Answer.Stable.V2.from_v3 a
        | Error e ->
            Error e

      let caller_model_of_response : response -> Master.T.response = function
        | Ok a ->
            Ok (Sync_ledger.Answer.Stable.V2.to_latest a)
        | Error e ->
            Error e
    end

    module T' =
      Perf_histograms.Rpc.Plain.Decorate_bin_io
        (struct
          include M
          include Master
        end)
        (T)

    include T'
    include Register (T')
  end

  let receipt_trust_action_message (_, query) =
    ( "Answer_sync_ledger_query: $query"
    , [ ("query", Sync_ledger.Query.to_yojson query) ] )

  let log_request_received ~logger:_ ~sender:_ _request = ()

  let response_is_successful = Result.is_ok

  let handle_request (module Context : CONTEXT) ~version:_ request =
    let open Context in
    let ledger_hash, _ = Envelope.Incoming.data request in
    let query = Envelope.Incoming.map request ~f:Tuple2.get2 in
    let%bind answer =
      match get_transition_frontier () with
      | Some frontier ->
          Sync_handler.answer_query ~frontier ledger_hash query
            ~context:(module Context)
            ~trust_system
      | None ->
          return (Or_error.error_string "No Frontier")
    in
    let result =
      Result.map_error answer ~f:(fun e ->
          Error.createf
            !"Refusing to answer sync ledger query for ledger_hash: \
              %{sexp:Ledger_hash.t}. Error: %s"
            ledger_hash (Error.to_string_hum e) )
    in
    let%map () =
      match result with
      | Ok _ ->
          return ()
      | Error err ->
          Trust_system.(
            record_envelope_sender trust_system logger
              (Envelope.Incoming.sender request)
              Actions.
                ( Requested_unknown_item
                , Some
                    ( "Sync ledger query with hash: $hash, query: $query, with \
                       error: $error"
                    , [ ("hash", Ledger_hash.to_yojson ledger_hash)
                      ; ( "query"
                        , Syncable_ledger.Query.to_yojson
                            Mina_ledger.Ledger.Addr.to_yojson
                            (Envelope.Incoming.data query) )
                      ; ("error", Error_json.error_to_yojson err)
                      ] ) ))
    in
    result

  let rate_limit_budget = (Int.pow 2 17, `Per Time.Span.minute)

  let rate_limit_cost = Fn.const 1
end]

[%%versioned_rpc
module Get_transition_chain = struct
  type nonrec ctx = ctx

  module Master = struct
    let name = "get_transition_chain"

    module T = struct
      type query = State_hash.t list [@@deriving sexp, to_yojson]

      type response = Mina_block.Stable.Latest.t list option
    end

    module Caller = T
    module Callee = T
  end

  include Master.T

  let sent_counter = Mina_metrics.Network.get_transition_chain_rpcs_sent

  let received_counter = Mina_metrics.Network.get_transition_chain_rpcs_received

  let failed_request_counter =
    Mina_metrics.Network.get_transition_chain_rpc_requests_failed

  let failed_response_counter =
    Mina_metrics.Network.get_transition_chain_rpc_responses_failed

  module M = Versioned_rpc.Both_convert.Plain.Make (Master)
  include M

  include Perf_histograms.Rpc.Plain.Extend (struct
    include M
    include Master
  end)

  module V2 = struct
    module T = struct
      type query = State_hash.Stable.V1.t list [@@deriving sexp]

      type response = Mina_block.Stable.V2.t list option

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model = ident

      let caller_model_of_response = ident
    end

    module T' =
      Perf_histograms.Rpc.Plain.Decorate_bin_io
        (struct
          include M
          include Master
        end)
        (T)

    include T'
    include Register (T')
  end

  let receipt_trust_action_message query =
    ("Get_transition_chain query: $query", [ ("query", query_to_yojson query) ])

  let log_request_received ~logger ~sender _request =
    [%log info] "Sending transition_chain to $peer"
      ~metadata:[ ("peer", Peer.to_yojson sender) ]

  let response_is_successful = Option.is_some

  let handle_request (module Context : CONTEXT) ~version:_ request =
    let open Context in
    let hashes = Envelope.Incoming.data request in
    let result =
      let%bind.Option frontier = get_transition_frontier () in
      Sync_handler.get_transition_chain ~frontier hashes
    in
    match result with
    | Some blocks ->
        let%map valid_versions =
          validate_protocol_versions ~logger ~trust_system
            ~rpc_name:"Get_transition_chain"
            ~sender:(Envelope.Incoming.sender request)
            (List.map blocks ~f:Mina_block.header)
        in
        Option.some_if valid_versions
        @@ List.map ~f:Mina_block.read_all_proofs_from_disk blocks
    | None ->
        let%map () =
          Trust_system.(
            record_envelope_sender trust_system logger
              (Envelope.Incoming.sender request)
              Actions.
                ( Requested_unknown_item
                , Some (receipt_trust_action_message hashes) ))
        in
        None

  let rate_limit_budget = (1, `Per Time.Span.second)

  let rate_limit_cost hashes = Int.max 1 (List.length hashes)
end]

[%%versioned_rpc
module Get_transition_knowledge = struct
  type nonrec ctx = ctx

  module Master = struct
    let name = "Get_transition_knowledge"

    module T = struct
      type query = unit [@@deriving sexp, to_yojson]

      type response = State_hash.t list
    end

    module Caller = T
    module Callee = T
  end

  include Master.T

  let sent_counter = Mina_metrics.Network.get_transition_knowledge_rpcs_sent

  let received_counter =
    Mina_metrics.Network.get_transition_knowledge_rpcs_received

  let failed_request_counter =
    Mina_metrics.Network.get_transition_knowledge_rpc_requests_failed

  let failed_response_counter =
    Mina_metrics.Network.get_transition_knowledge_rpc_responses_failed

  module M = Versioned_rpc.Both_convert.Plain.Make (Master)
  include M

  include Perf_histograms.Rpc.Plain.Extend (struct
    include M
    include Master
  end)

  module V1 = struct
    module T = struct
      type query = unit [@@deriving sexp]

      type response = State_hash.Stable.V1.t list

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model = Fn.id

      let caller_model_of_response = Fn.id
    end

    module T' =
      Perf_histograms.Rpc.Plain.Decorate_bin_io
        (struct
          include M
          include Master
        end)
        (T)

    include T'
    include Register (T')
  end

  let receipt_trust_action_message query =
    ( "Get_transition_knowledge query: $query"
    , [ ("query", query_to_yojson query) ] )

  let log_request_received ~logger ~sender _request =
    [%log info] "Sending transition_knowledge to $peer"
      ~metadata:[ ("peer", Peer.to_yojson sender) ]

  let response_is_successful hashes = not (List.is_empty hashes)

  let handle_request (module Context : CONTEXT) ~version:_ _request =
    let open Context in
    let result =
      let%map.Option frontier = get_transition_frontier () in
      Sync_handler.best_tip_path ~frontier
    in
    return (Option.value result ~default:[])

  let rate_limit_budget = (1, `Per Time.Span.minute)

  let rate_limit_cost = Fn.const 1
end]

[%%versioned_rpc
module Get_transition_chain_proof = struct
  type nonrec ctx = ctx

  module Master = struct
    let name = "get_transition_chain_proof"

    module T = struct
      type query = State_hash.t [@@deriving sexp, to_yojson]

      type response = (State_hash.t * State_body_hash.t list) option
    end

    module Caller = T
    module Callee = T
  end

  include Master.T

  let sent_counter = Mina_metrics.Network.get_transition_chain_proof_rpcs_sent

  let received_counter =
    Mina_metrics.Network.get_transition_chain_proof_rpcs_received

  let failed_request_counter =
    Mina_metrics.Network.get_transition_chain_proof_rpc_requests_failed

  let failed_response_counter =
    Mina_metrics.Network.get_transition_chain_proof_rpc_responses_failed

  module M = Versioned_rpc.Both_convert.Plain.Make (Master)
  include M

  include Perf_histograms.Rpc.Plain.Extend (struct
    include M
    include Master
  end)

  module V1 = struct
    module T = struct
      type query = State_hash.Stable.V1.t [@@deriving sexp]

      type response =
        (State_hash.Stable.V1.t * State_body_hash.Stable.V1.t list) option

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model = Fn.id

      let caller_model_of_response = Fn.id
    end

    module T' =
      Perf_histograms.Rpc.Plain.Decorate_bin_io
        (struct
          include M
          include Master
        end)
        (T)

    include T'
    include Register (T')
  end

  let receipt_trust_action_message query =
    ( "Get_transition_chain_proof query: $query"
    , [ ("query", query_to_yojson query) ] )

  let log_request_received ~logger ~sender _request =
    [%log info] "Sending transition_chain_proof to $peer"
      ~metadata:[ ("peer", Peer.to_yojson sender) ]

  let response_is_successful = Option.is_some

  let handle_request (module Context : CONTEXT) ~version:_ request =
    let open Context in
    let hash = Envelope.Incoming.data request in
    let result =
      let%bind.Option frontier = get_transition_frontier () in
      Transition_chain_prover.prove ~frontier hash
    in
    let%map () =
      if Option.is_none result then
        Trust_system.(
          record_envelope_sender trust_system logger
            (Envelope.Incoming.sender request)
            Actions.
              (Requested_unknown_item, Some (receipt_trust_action_message hash)))
      else return ()
    in
    result

  let rate_limit_budget = (3, `Per Time.Span.minute)

  let rate_limit_cost = Fn.const 1
end]

[%%versioned_rpc
module Get_completed_snarks = struct
  type nonrec ctx = ctx

  module Master = struct
    let name = "get_completed_snarks"

    module T = struct
      type query = unit [@@deriving sexp, to_yojson]

      type response = Transaction_snark_work.Stable.V2.t list option
    end

    module Caller = T
    module Callee = T
  end

  include Master.T

  let sent_counter = Mina_metrics.Network.get_completed_snarks_rpcs_sent

  let received_counter = Mina_metrics.Network.get_completed_snarks_rpcs_received

  let failed_request_counter =
    Mina_metrics.Network.get_completed_snarks_rpc_requests_failed

  let failed_response_counter =
    Mina_metrics.Network.get_completed_snarks_rpc_responses_failed

  module M = Versioned_rpc.Both_convert.Plain.Make (Master)
  include M

  include Perf_histograms.Rpc.Plain.Extend (struct
    include M
    include Master
  end)

  module V1 = struct
    module T = struct
      type query = unit [@@deriving sexp]

      type response = Transaction_snark_work.Stable.V2.t list option

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model = ident

      let caller_model_of_response = ident
    end

    module T' =
      Perf_histograms.Rpc.Plain.Decorate_bin_io
        (struct
          include M
          include Master
        end)
        (T)

    include T'
    include Register (T')
  end

  let receipt_trust_action_message query =
    ("Get_completed_snarks query", [ ("query", query_to_yojson query) ])

  let log_request_received ~logger ~sender _request =
    [%log debug] "Sending completed snarks to $peer"
      ~metadata:[ ("peer", Peer.to_yojson sender) ]

  let response_is_successful = Option.is_some

  let handle_request (module Context : CONTEXT) ~version:_ _request =
    let open Context in
    (* the maximum number of completed snarks to return over rpc *)
    let limit = 32 in
    match (get_snark_pool (), snark_job_state ()) with
    | Some snark_pool, Some snark_state ->
        Work_selector.completed_work_statements ~snark_pool snark_state
        |> Fn.flip List.take limit
        |> List.map
             ~f:
               Transaction_snark_work.(
                 Fn.compose read_all_proofs_from_disk forget)
        |> Option.some |> return
    | _, _ ->
        return None

  let rate_limit_budget = (1, `Per Time.Span.minute)

  let rate_limit_cost = Fn.const 1
end]

[%%versioned_rpc
module Get_ancestry = struct
  type nonrec ctx = ctx

  module Master = struct
    let name = "get_ancestry"

    module T = struct
      (** NB: The state hash sent in this query should not be trusted, as it can be forged. This is ok for how this RPC is implented, as we only use the state hash for tie breaking when checking whether or not the proof is worth serving. *)
      type query =
        (Consensus.Data.Consensus_state.Value.t, State_hash.t) With_hash.t
      [@@deriving sexp, to_yojson]

      type response =
        ( Mina_block.Stable.Latest.t
        , State_body_hash.t list * Mina_block.Stable.Latest.t )
        Proof_carrying_data.t
        option
    end

    module Caller = T
    module Callee = T
  end

  include Master.T

  let sent_counter = Mina_metrics.Network.get_ancestry_rpcs_sent

  let received_counter = Mina_metrics.Network.get_ancestry_rpcs_received

  let failed_request_counter =
    Mina_metrics.Network.get_ancestry_rpc_requests_failed

  let failed_response_counter =
    Mina_metrics.Network.get_ancestry_rpc_responses_failed

  module M = Versioned_rpc.Both_convert.Plain.Make (Master)
  include M

  include Perf_histograms.Rpc.Plain.Extend (struct
    include M
    include Master
  end)

  module V2 = struct
    module T = struct
      type query =
        ( Consensus.Data.Consensus_state.Value.Stable.V2.t
        , State_hash.Stable.V1.t )
        With_hash.Stable.V1.t
      [@@deriving sexp]

      type response =
        ( Mina_block.Stable.V2.t
        , State_body_hash.Stable.V1.t list * Mina_block.Stable.V2.t )
        Proof_carrying_data.Stable.V1.t
        option

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model = ident

      let caller_model_of_response = ident
    end

    module T' =
      Perf_histograms.Rpc.Plain.Decorate_bin_io
        (struct
          include M
          include Master
        end)
        (T)

    include T'
    include Register (T')
  end

  let receipt_trust_action_message query =
    ("Get_ancestry query: $query", [ ("query", query_to_yojson query) ])

  let log_request_received ~logger ~sender _request =
    [%log debug] "Sending root proof to $peer"
      ~metadata:[ ("peer", Peer.to_yojson sender) ]

  let response_is_successful = Option.is_some

  let handle_request (module Context : CONTEXT) ~version:_ request =
    let open Context in
    let consensus_state_with_hash = Envelope.Incoming.data request in
    let result =
      let%bind.Option frontier = get_transition_frontier () in
      consensus_state_with_hash
      |> With_hash.map_hash ~f:(fun state_hash ->
             { State_hash.State_hashes.state_hash; state_body_hash = None } )
      |> Sync_handler.Root.prove ~context:(module Context) ~frontier
    in
    match result with
    | None ->
        let%map () =
          Trust_system.(
            record_envelope_sender trust_system logger
              (Envelope.Incoming.sender request)
              Actions.
                ( Requested_unknown_item
                , Some (receipt_trust_action_message consensus_state_with_hash)
                ))
        in
        None
    | Some { proof = chain, base_block; data = block } ->
        let block = Frontier_base.Breadcrumb.block block in
        let base_block = Frontier_base.Breadcrumb.block base_block in
        let%map valid_versions =
          validate_protocol_versions ~logger ~trust_system
            ~rpc_name:"Get_ancestry"
            ~sender:(Envelope.Incoming.sender request)
            [ Mina_block.header base_block ]
        in
        Option.some_if valid_versions
          { Proof_carrying_data.proof =
              (chain, Mina_block.read_all_proofs_from_disk base_block)
          ; data = Mina_block.read_all_proofs_from_disk block
          }

  let rate_limit_budget = (5, `Per Time.Span.minute)

  let rate_limit_cost = Fn.const 1
end]

[%%versioned_rpc
module Ban_notify = struct
  type nonrec ctx = ctx

  module Master = struct
    let name = "ban_notify"

    module T = struct
      (* banned until this time *)
      type query = Core.Time.t [@@deriving sexp]

      type response = unit
    end

    module Caller = T
    module Callee = T
  end

  include Master.T

  let sent_counter = Mina_metrics.Network.ban_notify_rpcs_sent

  let received_counter = Mina_metrics.Network.ban_notify_rpcs_received

  let failed_request_counter =
    Mina_metrics.Network.ban_notify_rpc_requests_failed

  let failed_response_counter =
    Mina_metrics.Network.ban_notify_rpc_responses_failed

  module M = Versioned_rpc.Both_convert.Plain.Make (Master)
  include M

  include Perf_histograms.Rpc.Plain.Extend (struct
    include M
    include Master
  end)

  module V1 = struct
    module T = struct
      type query = Core.Time.Stable.V1.t [@@deriving sexp]

      type response = unit

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model = Fn.id

      let caller_model_of_response = Fn.id
    end

    module T' =
      Perf_histograms.Rpc.Plain.Decorate_bin_io
        (struct
          include M
          include Master
        end)
        (T)

    include T'
    include Register (T')
  end

  let receipt_trust_action_message _request = ("Ban_notify query", [])

  let log_request_received ~logger ~sender ban_until =
    [%log warn] "Node banned by peer $peer until $ban_until"
      ~metadata:
        [ ("peer", Peer.to_yojson sender)
        ; ( "ban_until"
          , `String (Time.to_string_abs ~zone:Time.Zone.utc ban_until) )
        ]

  let response_is_successful = Fn.const true

  let handle_request _ctx ~version:_ _request = Deferred.unit

  let rate_limit_budget = (1, `Per Time.Span.minute)

  let rate_limit_cost = Fn.const 1
end]

[%%versioned_rpc
module Get_best_tip = struct
  type nonrec ctx = ctx

  module Master = struct
    let name = "get_best_tip"

    module T = struct
      type query = unit [@@deriving sexp, to_yojson]

      type response =
        ( Mina_block.Stable.Latest.t
        , State_body_hash.t list * Mina_block.Stable.Latest.t )
        Proof_carrying_data.t
        option
    end

    module Caller = T
    module Callee = T
  end

  include Master.T

  let sent_counter = Mina_metrics.Network.get_best_tip_rpcs_sent

  let received_counter = Mina_metrics.Network.get_best_tip_rpcs_received

  let failed_request_counter =
    Mina_metrics.Network.get_best_tip_rpc_requests_failed

  let failed_response_counter =
    Mina_metrics.Network.get_best_tip_rpc_responses_failed

  module M = Versioned_rpc.Both_convert.Plain.Make (Master)
  include M

  include Perf_histograms.Rpc.Plain.Extend (struct
    include M
    include Master
  end)

  module V2 = struct
    module T = struct
      type query = unit [@@deriving sexp]

      type response =
        ( Mina_block.Stable.V2.t
        , State_body_hash.Stable.V1.t list * Mina_block.Stable.V2.t )
        Proof_carrying_data.Stable.V1.t
        option

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model = ident

      let caller_model_of_response = ident
    end

    module T' =
      Perf_histograms.Rpc.Plain.Decorate_bin_io
        (struct
          include M
          include Master
        end)
        (T)

    include T'
    include Register (T')
  end

  let receipt_trust_action_message _request = ("Get_best_tip query", [])

  let log_request_received ~logger ~sender _request =
    [%log debug] "Sending best_tip to $peer"
      ~metadata:[ ("peer", Peer.to_yojson sender) ]

  let response_is_successful = Option.is_some

  let handle_request (module Context : CONTEXT) ~version:_ request =
    let open Context in
    let result =
      let open Option.Let_syntax in
      let%bind frontier = get_transition_frontier () in
      Best_tip_prover.prove ~context:(module Context) frontier
    in
    match result with
    | None ->
        let%map () =
          Trust_system.(
            record_envelope_sender trust_system logger
              (Envelope.Incoming.sender request)
              Actions.
                (Requested_unknown_item, Some (receipt_trust_action_message ())))
        in
        None
    | Some { data = data_block; proof = chain, proof_block } ->
        let data_block = Frontier_base.Breadcrumb.block data_block in
        let proof_block = Frontier_base.Breadcrumb.block proof_block in
        let%map data_valid_versions =
          validate_protocol_versions ~logger ~trust_system
            ~rpc_name:"Get_best_tip (data)"
            ~sender:(Envelope.Incoming.sender request)
            [ Mina_block.header data_block ]
        and proof_valid_versions =
          validate_protocol_versions ~logger ~trust_system
            ~rpc_name:"Get_best_tip (proof)"
            ~sender:(Envelope.Incoming.sender request)
            [ Mina_block.header proof_block ]
        in
        Option.some_if
          (data_valid_versions && proof_valid_versions)
          { Proof_carrying_data.data =
              Mina_block.read_all_proofs_from_disk data_block
          ; proof = (chain, Mina_block.read_all_proofs_from_disk proof_block)
          }

  let rate_limit_budget = (3, `Per Time.Span.minute)

  let rate_limit_cost = Fn.const 1
end]

type ('query, 'response) rpc =
  | Get_some_initial_peers
      : (Get_some_initial_peers.query, Get_some_initial_peers.response) rpc
  | Get_staged_ledger_aux_and_pending_coinbases_at_hash
      : ( Get_staged_ledger_aux_and_pending_coinbases_at_hash.query
        , Get_staged_ledger_aux_and_pending_coinbases_at_hash.response )
        rpc
  | Answer_sync_ledger_query
      : (Answer_sync_ledger_query.query, Answer_sync_ledger_query.response) rpc
  | Get_transition_chain
      : (Get_transition_chain.query, Get_transition_chain.response) rpc
  | Get_transition_knowledge
      : (Get_transition_knowledge.query, Get_transition_knowledge.response) rpc
  | Get_transition_chain_proof
      : ( Get_transition_chain_proof.query
        , Get_transition_chain_proof.response )
        rpc
  | Get_ancestry : (Get_ancestry.query, Get_ancestry.response) rpc
  | Ban_notify : (Ban_notify.query, Ban_notify.response) rpc
  | Get_best_tip : (Get_best_tip.query, Get_best_tip.response) rpc
  | Get_completed_snarks
      : (Get_completed_snarks.query, Get_completed_snarks.response) rpc

type any_rpc = Rpc : ('q, 'r) rpc -> any_rpc

let all_rpcs =
  [ Rpc Get_some_initial_peers
  ; Rpc Get_staged_ledger_aux_and_pending_coinbases_at_hash
  ; Rpc Answer_sync_ledger_query
  ; Rpc Get_best_tip
  ; Rpc Get_ancestry
  ; Rpc Get_transition_knowledge
  ; Rpc Get_transition_chain
  ; Rpc Get_transition_chain_proof
  ; Rpc Ban_notify
  ; Rpc Get_completed_snarks
  ]

let implementation :
    type q r. (q, r) rpc -> (ctx, q, r) Gossip_net.rpc_implementation = function
  | Get_some_initial_peers ->
      (module Get_some_initial_peers)
  | Get_staged_ledger_aux_and_pending_coinbases_at_hash ->
      (module Get_staged_ledger_aux_and_pending_coinbases_at_hash)
  | Answer_sync_ledger_query ->
      (module Answer_sync_ledger_query)
  | Get_transition_chain ->
      (module Get_transition_chain)
  | Get_transition_knowledge ->
      (module Get_transition_knowledge)
  | Get_transition_chain_proof ->
      (module Get_transition_chain_proof)
  | Get_ancestry ->
      (module Get_ancestry)
  | Ban_notify ->
      (module Ban_notify)
  | Get_best_tip ->
      (module Get_best_tip)
  | Get_completed_snarks ->
      (module Get_completed_snarks)
