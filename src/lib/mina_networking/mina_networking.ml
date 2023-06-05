open Core
open Async
open Mina_base
module Sync_ledger = Mina_ledger.Sync_ledger
open Mina_block
open Network_peer
open Network_pool
open Pipe_lib

let refused_answer_query_string = "Refused to answer_query"

exception No_initial_peers

type Structured_log_events.t +=
  | Gossip_new_state of { state_hash : State_hash.t }
  [@@deriving register_event { msg = "Broadcasting new state over gossip net" }]

type Structured_log_events.t +=
  | Gossip_transaction_pool_diff of
      { txns : Transaction_pool.Resource_pool.Diff.t }
  [@@deriving
    register_event
      { msg = "Broadcasting transaction pool diff over gossip net" }]

type Structured_log_events.t +=
  | Gossip_snark_pool_diff of { work : Snark_pool.Resource_pool.Diff.compact }
  [@@deriving
    register_event { msg = "Broadcasting snark pool diff over gossip net" }]

(* INSTRUCTIONS FOR ADDING A NEW RPC:
 *   - define a new module under the Rpcs module
 *   - add an entry to the Rpcs.rpc GADT definition for the new module (type ('query, 'response) rpc, below)
 *   - add the new constructor for Rpcs.rpc to Rpcs.all_of_type_erased_rpc
 *   - add a pattern matching case to Rpcs.implementation_of_rpc mapping the
 *      new constructor to the new module for your RPC
 *   - add a match case to `match_handler`, below
 *)
module Rpcs = struct
  (* for versioning of the types here, see

     RFC 0012, and

     https://ocaml.janestreet.com/ocaml-core/latest/doc/async_rpc_kernel/Async_rpc_kernel/Versioned_rpc/

     The "master" types are the ones used internally in the code base. Each
     version has coercions between their query and response types and the master
     types.
  *)

  [%%versioned_rpc
  module Get_some_initial_peers = struct
    module Master = struct
      let name = "get_some_initial_peers"

      module T = struct
        type query = unit [@@deriving sexp, yojson]

        type response = Network_peer.Peer.t list [@@deriving sexp, yojson]
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
  end]

  [%%versioned_rpc
  module Get_staged_ledger_aux_and_pending_coinbases_at_hash = struct
    module Master = struct
      let name = "get_staged_ledger_aux_and_pending_coinbases_at_hash"

      module T = struct
        type query = State_hash.t

        type response =
          ( Staged_ledger.Scan_state.t
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
          ( Staged_ledger.Scan_state.Stable.V2.t
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
  end]

  [%%versioned_rpc
  module Answer_sync_ledger_query = struct
    module Master = struct
      let name = "answer_sync_ledger_query"

      module T = struct
        type query = Ledger_hash.t * Sync_ledger.Query.t

        type response = Sync_ledger.Answer.t Core.Or_error.t
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

    module V2 = struct
      module T = struct
        type query = Ledger_hash.Stable.V1.t * Sync_ledger.Query.Stable.V1.t
        [@@deriving sexp]

        type response = Sync_ledger.Answer.Stable.V2.t Core.Or_error.Stable.V1.t
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
  end]

  [%%versioned_rpc
  module Get_transition_chain = struct
    module Master = struct
      let name = "get_transition_chain"

      module T = struct
        type query = State_hash.t list [@@deriving sexp, to_yojson]

        type response = Mina_block.t list option
      end

      module Caller = T
      module Callee = T
    end

    include Master.T

    let sent_counter = Mina_metrics.Network.get_transition_chain_rpcs_sent

    let received_counter =
      Mina_metrics.Network.get_transition_chain_rpcs_received

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
  end]

  [%%versioned_rpc
  module Get_transition_chain_proof = struct
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
  end]

  [%%versioned_rpc
  module Get_transition_knowledge = struct
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
  end]

  [%%versioned_rpc
  module Get_ancestry = struct
    module Master = struct
      let name = "get_ancestry"

      module T = struct
        (** NB: The state hash sent in this query should not be trusted, as it can be forged. This is ok for how this RPC is implented, as we only use the state hash for tie breaking when checking whether or not the proof is worth serving. *)
        type query =
          (Consensus.Data.Consensus_state.Value.t, State_hash.t) With_hash.t
        [@@deriving sexp, to_yojson]

        type response =
          ( Mina_block.t
          , State_body_hash.t list * Mina_block.t )
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
  end]

  [%%versioned_rpc
  module Ban_notify = struct
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
  end]

  [%%versioned_rpc
  module Get_best_tip = struct
    module Master = struct
      let name = "get_best_tip"

      module T = struct
        type query = unit [@@deriving sexp, to_yojson]

        type response =
          ( Mina_block.t
          , State_body_hash.t list * Mina_block.t )
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
  end]

  [%%versioned_rpc
  module Get_node_status = struct
    module Node_status = struct
      [%%versioned
      module Stable = struct
        module V2 = struct
          type t =
            { node_ip_addr : Core.Unix.Inet_addr.Stable.V1.t
                  [@to_yojson
                    fun ip_addr -> `String (Unix.Inet_addr.to_string ip_addr)]
                  [@of_yojson
                    function
                    | `String s ->
                        Ok (Unix.Inet_addr.of_string s)
                    | _ ->
                        Error "expected string"]
            ; node_peer_id : Network_peer.Peer.Id.Stable.V1.t
                  [@to_yojson fun peer_id -> `String peer_id]
                  [@of_yojson
                    function `String s -> Ok s | _ -> Error "expected string"]
            ; sync_status : Sync_status.Stable.V1.t
            ; peers : Network_peer.Peer.Stable.V1.t list
            ; block_producers :
                Signature_lib.Public_key.Compressed.Stable.V1.t list
            ; protocol_state_hash : State_hash.Stable.V1.t
            ; ban_statuses :
                ( Network_peer.Peer.Stable.V1.t
                * Trust_system.Peer_status.Stable.V1.t )
                list
            ; k_block_hashes_and_timestamps :
                (State_hash.Stable.V1.t * string) list
            ; git_commit : string
            ; uptime_minutes : int
            ; block_height_opt : int option [@default None]
            }
          [@@deriving to_yojson, of_yojson]

          let to_latest = Fn.id
        end

        module V1 = struct
          type t =
            { node_ip_addr : Core.Unix.Inet_addr.Stable.V1.t
                  [@to_yojson
                    fun ip_addr -> `String (Unix.Inet_addr.to_string ip_addr)]
                  [@of_yojson
                    function
                    | `String s ->
                        Ok (Unix.Inet_addr.of_string s)
                    | _ ->
                        Error "expected string"]
            ; node_peer_id : Network_peer.Peer.Id.Stable.V1.t
                  [@to_yojson fun peer_id -> `String peer_id]
                  [@of_yojson
                    function `String s -> Ok s | _ -> Error "expected string"]
            ; sync_status : Sync_status.Stable.V1.t
            ; peers : Network_peer.Peer.Stable.V1.t list
            ; block_producers :
                Signature_lib.Public_key.Compressed.Stable.V1.t list
            ; protocol_state_hash : State_hash.Stable.V1.t
            ; ban_statuses :
                ( Network_peer.Peer.Stable.V1.t
                * Trust_system.Peer_status.Stable.V1.t )
                list
            ; k_block_hashes_and_timestamps :
                (State_hash.Stable.V1.t * string) list
            ; git_commit : string
            ; uptime_minutes : int
            }
          [@@deriving to_yojson, of_yojson]

          let to_latest status : Latest.t =
            { node_ip_addr = status.node_ip_addr
            ; node_peer_id = status.node_peer_id
            ; sync_status = status.sync_status
            ; peers = status.peers
            ; block_producers = status.block_producers
            ; protocol_state_hash = status.protocol_state_hash
            ; ban_statuses = status.ban_statuses
            ; k_block_hashes_and_timestamps =
                status.k_block_hashes_and_timestamps
            ; git_commit = status.git_commit
            ; uptime_minutes = status.uptime_minutes
            ; block_height_opt = None
            }
        end
      end]
    end

    module Master = struct
      let name = "get_node_status"

      module T = struct
        type query = unit [@@deriving sexp, to_yojson]

        type response = Node_status.t Or_error.t
      end

      module Caller = T
      module Callee = T
    end

    include Master.T

    let sent_counter = Mina_metrics.Network.get_node_status_rpcs_sent

    let received_counter = Mina_metrics.Network.get_node_status_rpcs_received

    let failed_request_counter =
      Mina_metrics.Network.get_node_status_rpc_requests_failed

    let failed_response_counter =
      Mina_metrics.Network.get_node_status_rpc_responses_failed

    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    let response_to_yojson response =
      match response with
      | Ok status ->
          Node_status.Stable.Latest.to_yojson status
      | Error err ->
          `Assoc [ ("error", Error_json.error_to_yojson err) ]

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include Master
    end)

    module V2 = struct
      module T = struct
        type query = unit [@@deriving sexp]

        type response = Node_status.Stable.V2.t Core_kernel.Or_error.Stable.V1.t

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

    module V1 = struct
      module T = struct
        type query = unit [@@deriving sexp]

        type response = Node_status.Stable.V1.t Core_kernel.Or_error.Stable.V1.t

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = function
          | Error err ->
              Error err
          | Ok (status : Node_status.Stable.Latest.t) ->
              Ok
                { Node_status.Stable.V1.node_ip_addr = status.node_ip_addr
                ; node_peer_id = status.node_peer_id
                ; sync_status = status.sync_status
                ; peers = status.peers
                ; block_producers = status.block_producers
                ; protocol_state_hash = status.protocol_state_hash
                ; ban_statuses = status.ban_statuses
                ; k_block_hashes_and_timestamps =
                    status.k_block_hashes_and_timestamps
                ; git_commit = status.git_commit
                ; uptime_minutes = status.uptime_minutes
                }

        let caller_model_of_response = function
          | Error err ->
              Error err
          | Ok (status : Node_status.Stable.V1.t) ->
              Ok (Node_status.Stable.V1.to_latest status)
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
  end]

  type ('query, 'response) rpc =
    | Get_some_initial_peers
        : (Get_some_initial_peers.query, Get_some_initial_peers.response) rpc
    | Get_staged_ledger_aux_and_pending_coinbases_at_hash
        : ( Get_staged_ledger_aux_and_pending_coinbases_at_hash.query
          , Get_staged_ledger_aux_and_pending_coinbases_at_hash.response )
          rpc
    | Answer_sync_ledger_query
        : ( Answer_sync_ledger_query.query
          , Answer_sync_ledger_query.response )
          rpc
    | Get_transition_chain
        : (Get_transition_chain.query, Get_transition_chain.response) rpc
    | Get_transition_knowledge
        : ( Get_transition_knowledge.query
          , Get_transition_knowledge.response )
          rpc
    | Get_transition_chain_proof
        : ( Get_transition_chain_proof.query
          , Get_transition_chain_proof.response )
          rpc
    | Get_node_status : (Get_node_status.query, Get_node_status.response) rpc
    | Get_ancestry : (Get_ancestry.query, Get_ancestry.response) rpc
    | Ban_notify : (Ban_notify.query, Ban_notify.response) rpc
    | Get_best_tip : (Get_best_tip.query, Get_best_tip.response) rpc

  type rpc_handler =
    | Rpc_handler :
        { rpc : ('q, 'r) rpc
        ; f : ('q, 'r) Rpc_intf.rpc_fn
        ; cost : 'q -> int
        ; budget : int * [ `Per of Time.Span.t ]
        }
        -> rpc_handler

  let implementation_of_rpc :
      type q r. (q, r) rpc -> (q, r) Rpc_intf.rpc_implementation = function
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
    | Get_node_status ->
        (module Get_node_status)
    | Get_ancestry ->
        (module Get_ancestry)
    | Ban_notify ->
        (module Ban_notify)
    | Get_best_tip ->
        (module Get_best_tip)

  let match_handler :
      type q r.
         rpc_handler
      -> (q, r) rpc
      -> do_:((q, r) Rpc_intf.rpc_fn -> 'a)
      -> 'a option =
   fun (Rpc_handler { rpc = impl_rpc; f; cost = _; budget = _ }) rpc ~do_ ->
    match (rpc, impl_rpc) with
    | Get_some_initial_peers, Get_some_initial_peers ->
        Some (do_ f)
    | Get_some_initial_peers, _ ->
        None
    | ( Get_staged_ledger_aux_and_pending_coinbases_at_hash
      , Get_staged_ledger_aux_and_pending_coinbases_at_hash ) ->
        Some (do_ f)
    | Get_staged_ledger_aux_and_pending_coinbases_at_hash, _ ->
        None
    | Answer_sync_ledger_query, Answer_sync_ledger_query ->
        Some (do_ f)
    | Answer_sync_ledger_query, _ ->
        None
    | Get_transition_chain, Get_transition_chain ->
        Some (do_ f)
    | Get_transition_chain, _ ->
        None
    | Get_transition_knowledge, Get_transition_knowledge ->
        Some (do_ f)
    | Get_transition_knowledge, _ ->
        None
    | Get_transition_chain_proof, Get_transition_chain_proof ->
        Some (do_ f)
    | Get_transition_chain_proof, _ ->
        None
    | Get_node_status, Get_node_status ->
        Some (do_ f)
    | Get_node_status, _ ->
        None
    | Get_ancestry, Get_ancestry ->
        Some (do_ f)
    | Get_ancestry, _ ->
        None
    | Ban_notify, Ban_notify ->
        Some (do_ f)
    | Ban_notify, _ ->
        None
    | Get_best_tip, Get_best_tip ->
        Some (do_ f)
    | Get_best_tip, _ ->
        None
end

module Sinks = Sinks
module Gossip_net = Gossip_net.Make (Rpcs)

module Config = struct
  type log_gossip_heard =
    { snark_pool_diff : bool; transaction_pool_diff : bool; new_state : bool }
  [@@deriving make]

  type t =
    { logger : Logger.t
    ; trust_system : Trust_system.t
    ; time_controller : Block_time.Controller.t
    ; consensus_constants : Consensus.Constants.t
    ; consensus_local_state : Consensus.Data.Local_state.t
    ; genesis_ledger_hash : Ledger_hash.t
    ; constraint_constants : Genesis_constants.Constraint_constants.t
    ; precomputed_values : Precomputed_values.t
    ; creatable_gossip_net : Gossip_net.Any.creatable
    ; is_seed : bool
    ; log_gossip_heard : log_gossip_heard
    }
  [@@deriving make]
end

type t =
  { logger : Logger.t
  ; trust_system : Trust_system.t
  ; gossip_net : Gossip_net.Any.t
  }
[@@deriving fields]

let wrap_rpc_data_in_envelope conn data =
  Envelope.Incoming.wrap_peer ~data ~sender:conn

type protocol_version_status =
  { valid_current : bool; valid_next : bool; matches_daemon : bool }

let protocol_version_status t =
  let header = Mina_block.header t in
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

let create (config : Config.t) ~sinks
    ~(get_some_initial_peers :
          Rpcs.Get_some_initial_peers.query Envelope.Incoming.t
       -> Rpcs.Get_some_initial_peers.response Deferred.t )
    ~(get_staged_ledger_aux_and_pending_coinbases_at_hash :
          Rpcs.Get_staged_ledger_aux_and_pending_coinbases_at_hash.query
          Envelope.Incoming.t
       -> Rpcs.Get_staged_ledger_aux_and_pending_coinbases_at_hash.response
          Deferred.t )
    ~(answer_sync_ledger_query :
          Rpcs.Answer_sync_ledger_query.query Envelope.Incoming.t
       -> Rpcs.Answer_sync_ledger_query.response Deferred.t )
    ~(get_ancestry :
          Rpcs.Get_ancestry.query Envelope.Incoming.t
       -> Rpcs.Get_ancestry.response Deferred.t )
    ~(get_best_tip :
          Rpcs.Get_best_tip.query Envelope.Incoming.t
       -> Rpcs.Get_best_tip.response Deferred.t )
    ~(get_node_status :
          Rpcs.Get_node_status.query Envelope.Incoming.t
       -> Rpcs.Get_node_status.response Deferred.t )
    ~(get_transition_chain_proof :
          Rpcs.Get_transition_chain_proof.query Envelope.Incoming.t
       -> Rpcs.Get_transition_chain_proof.response Deferred.t )
    ~(get_transition_chain :
          Rpcs.Get_transition_chain.query Envelope.Incoming.t
       -> Rpcs.Get_transition_chain.response Deferred.t )
    ~(get_transition_knowledge :
          Rpcs.Get_transition_knowledge.query Envelope.Incoming.t
       -> Rpcs.Get_transition_knowledge.response Deferred.t ) =
  let module Context = struct
    let logger = config.logger
  end in
  let open Context in
  let run_for_rpc_result conn data ~f action_msg msg_args =
    let data_in_envelope = wrap_rpc_data_in_envelope conn data in
    let sender = Envelope.Incoming.sender data_in_envelope in
    let%bind () =
      Trust_system.(
        record_envelope_sender config.trust_system config.logger sender
          Actions.(Made_request, Some (action_msg, msg_args)))
    in
    let%bind result = f data_in_envelope in
    return (result, sender)
  in
  let incr_failed_response = Mina_metrics.Counter.inc_one in
  let record_unknown_item result sender action_msg msg_args
      failed_response_counter =
    let%map () =
      if Option.is_none result then (
        incr_failed_response failed_response_counter ;
        Trust_system.(
          record_envelope_sender config.trust_system config.logger sender
            Actions.(Requested_unknown_item, Some (action_msg, msg_args))) )
      else return ()
    in
    result
  in
  let validate_protocol_versions ~rpc_name sender external_transition =
    let open Trust_system.Actions in
    let { valid_current; valid_next; matches_daemon } =
      protocol_version_status external_transition
    in
    let%bind () =
      if valid_current then return ()
      else
        let actions =
          ( Sent_invalid_protocol_version
          , Some
              ( "$rpc_name: external transition with invalid current protocol \
                 version"
              , [ ("rpc_name", `String rpc_name)
                ; ( "current_protocol_version"
                  , `String
                      (Protocol_version.to_string
                         (Header.current_protocol_version
                            (Mina_block.header external_transition) ) ) )
                ] ) )
        in
        Trust_system.record_envelope_sender config.trust_system config.logger
          sender actions
    in
    let%bind () =
      if valid_next then return ()
      else
        let actions =
          ( Sent_invalid_protocol_version
          , Some
              ( "$rpc_name: external transition with invalid proposed protocol \
                 version"
              , [ ("rpc_name", `String rpc_name)
                ; ( "proposed_protocol_version"
                  , `String
                      (Protocol_version.to_string
                         (Option.value_exn
                            (Header.proposed_protocol_version_opt
                               (Mina_block.header external_transition) ) ) ) )
                ] ) )
        in
        Trust_system.record_envelope_sender config.trust_system config.logger
          sender actions
    in
    let%map () =
      if matches_daemon then return ()
      else
        let actions =
          ( Sent_mismatched_protocol_version
          , Some
              ( "$rpc_name: current protocol version in external transition \
                 does not match daemon current protocol version"
              , [ ("rpc_name", `String rpc_name)
                ; ( "current_protocol_version"
                  , `String
                      (Protocol_version.to_string
                         (Header.current_protocol_version
                            (Mina_block.header external_transition) ) ) )
                ; ( "daemon_current_protocol_version"
                  , `String Protocol_version.(to_string @@ get_current ()) )
                ] ) )
        in
        Trust_system.record_envelope_sender config.trust_system config.logger
          sender actions
    in
    valid_current && valid_next && matches_daemon
  in
  (* each of the passed-in procedures expects an enveloped input, so
     we wrap the data received via RPC *)
  let get_staged_ledger_aux_and_pending_coinbases_at_hash_rpc conn ~version:_
      hash =
    let action_msg = "Staged ledger and pending coinbases at hash: $hash" in
    let msg_args = [ ("hash", State_hash.to_yojson hash) ] in
    let%bind result, sender =
      run_for_rpc_result conn hash
        ~f:get_staged_ledger_aux_and_pending_coinbases_at_hash action_msg
        msg_args
    in
    record_unknown_item result sender action_msg msg_args
      Rpcs.Get_staged_ledger_aux_and_pending_coinbases_at_hash
      .failed_response_counter
  in
  let answer_sync_ledger_query_rpc conn ~version:_ ((hash, query) as sync_query)
      =
    let%bind result, sender =
      run_for_rpc_result conn sync_query ~f:answer_sync_ledger_query
        "Answer_sync_ledger_query: $query"
        [ ("query", Sync_ledger.Query.to_yojson query) ]
    in
    let%bind () =
      match result with
      | Ok _ ->
          return ()
      | Error err ->
          (* N.B.: to_string_mach double-quotes the string, don't want that *)
          incr_failed_response
            Rpcs.Answer_sync_ledger_query.failed_response_counter ;
          let err_msg = Error.to_string_hum err in
          if String.is_prefix err_msg ~prefix:refused_answer_query_string then
            Trust_system.(
              record_envelope_sender config.trust_system config.logger sender
                Actions.
                  ( Requested_unknown_item
                  , Some
                      ( "Sync ledger query with hash: $hash, query: $query, \
                         with error: $error"
                      , [ ("hash", Ledger_hash.to_yojson hash)
                        ; ( "query"
                          , Syncable_ledger.Query.to_yojson
                              Mina_ledger.Ledger.Addr.to_yojson query )
                        ; ("error", Error_json.error_to_yojson err)
                        ] ) ))
          else return ()
    in
    return result
  in
  let md p = [ ("peer", Peer.to_yojson p) ] in
  let get_ancestry_rpc conn ~version:_ query =
    [%log debug] "Sending root proof to $peer" ~metadata:(md conn) ;
    let action_msg = "Get_ancestry query: $query" in
    let msg_args = [ ("query", Rpcs.Get_ancestry.query_to_yojson query) ] in
    let%bind result, sender =
      run_for_rpc_result conn query ~f:get_ancestry action_msg msg_args
    in
    match result with
    | None ->
        record_unknown_item result sender action_msg msg_args
          Rpcs.Get_ancestry.failed_response_counter
    | Some { proof = _, ext_trans; _ } ->
        let%map valid_protocol_versions =
          validate_protocol_versions ~rpc_name:"Get_ancestry" sender ext_trans
        in
        if valid_protocol_versions then result else None
  in
  let get_some_initial_peers_rpc (conn : Peer.t) ~version:_ () =
    [%log trace] "Sending some initial peers to $peer" ~metadata:(md conn) ;
    let action_msg = "Get_some_initial_peers query: $query" in
    let msg_args = [ ("query", `Assoc []) ] in
    let%map result, _sender =
      run_for_rpc_result conn () ~f:get_some_initial_peers action_msg msg_args
    in
    if List.is_empty result then
      incr_failed_response Rpcs.Get_some_initial_peers.failed_response_counter ;
    result
  in
  let get_best_tip_rpc conn ~version:_ () =
    [%log debug] "Sending best_tip to $peer" ~metadata:(md conn) ;
    let action_msg = "Get_best_tip. query: $query" in
    let msg_args = [ ("query", Rpcs.Get_best_tip.query_to_yojson ()) ] in
    let%bind result, sender =
      run_for_rpc_result conn () ~f:get_best_tip action_msg msg_args
    in
    match result with
    | None ->
        record_unknown_item result sender action_msg msg_args
          Rpcs.Get_best_tip.failed_response_counter
    | Some { data = data_ext_trans; proof = _, proof_ext_trans } ->
        let%bind valid_data_protocol_versions =
          validate_protocol_versions ~rpc_name:"Get_best_tip (data)" sender
            data_ext_trans
        in
        let%map valid_proof_protocol_versions =
          validate_protocol_versions ~rpc_name:"Get_best_tip (proof)" sender
            proof_ext_trans
        in
        if valid_data_protocol_versions && valid_proof_protocol_versions then
          result
        else None
  in
  let get_transition_chain_proof_rpc conn ~version:_ query =
    [%log info] "Sending transition_chain_proof to $peer" ~metadata:(md conn) ;
    let action_msg = "Get_transition_chain_proof query: $query" in
    let msg_args =
      [ ("query", Rpcs.Get_transition_chain_proof.query_to_yojson query) ]
    in
    let%bind result, sender =
      run_for_rpc_result conn query ~f:get_transition_chain_proof action_msg
        msg_args
    in
    record_unknown_item result sender action_msg msg_args
      Rpcs.Get_transition_chain_proof.failed_response_counter
  in
  let get_transition_knowledge_rpc conn ~version:_ query =
    [%log info] "Sending transition_knowledge to $peer" ~metadata:(md conn) ;
    let action_msg = "Get_transition_knowledge query: $query" in
    let msg_args =
      [ ("query", Rpcs.Get_transition_knowledge.query_to_yojson query) ]
    in
    let%map result =
      run_for_rpc_result conn query ~f:get_transition_knowledge action_msg
        msg_args
      >>| fst
    in
    if List.is_empty result then
      incr_failed_response Rpcs.Get_transition_knowledge.failed_response_counter ;
    result
  in
  let get_transition_chain_rpc conn ~version:_ query =
    [%log info] "Sending transition_chain to $peer" ~metadata:(md conn) ;
    let action_msg = "Get_transition_chain query: $query" in
    let msg_args =
      [ ("query", Rpcs.Get_transition_chain.query_to_yojson query) ]
    in
    let%bind result, sender =
      run_for_rpc_result conn query ~f:get_transition_chain action_msg msg_args
    in
    match result with
    | None ->
        record_unknown_item result sender action_msg msg_args
          Rpcs.Get_transition_chain.failed_response_counter
    | Some ext_trans ->
        let%map valid_protocol_versions =
          Deferred.List.map ext_trans
            ~f:
              (validate_protocol_versions ~rpc_name:"Get_transition_chain"
                 sender )
        in
        if List.for_all valid_protocol_versions ~f:(Bool.equal true) then result
        else None
  in
  let ban_notify_rpc conn ~version:_ ban_until =
    (* the port in `conn' is an ephemeral port, not of interest *)
    [%log warn] "Node banned by peer $peer until $ban_until"
      ~metadata:
        [ ("peer", Peer.to_yojson conn)
        ; ( "ban_until"
          , `String (Time.to_string_abs ~zone:Time.Zone.utc ban_until) )
        ] ;
    (* no computation to do; we're just getting notification *)
    Deferred.unit
  in
  let rpc_handlers =
    let open Rpcs in
    let open Time.Span in
    let unit _ = 1 in
    [ Rpc_handler
        { rpc = Get_some_initial_peers
        ; f = get_some_initial_peers_rpc
        ; budget = (1, `Per minute)
        ; cost = unit
        }
    ; Rpc_handler
        { rpc = Get_staged_ledger_aux_and_pending_coinbases_at_hash
        ; f = get_staged_ledger_aux_and_pending_coinbases_at_hash_rpc
        ; budget = (4, `Per minute)
        ; cost = unit
        }
    ; Rpc_handler
        { rpc = Answer_sync_ledger_query
        ; f = answer_sync_ledger_query_rpc
        ; budget =
            (Int.pow 2 17, `Per minute) (* Not that confident about this one. *)
        ; cost = unit
        }
    ; Rpc_handler
        { rpc = Get_best_tip
        ; f = get_best_tip_rpc
        ; budget = (3, `Per minute)
        ; cost = unit
        }
    ; Rpc_handler
        { rpc = Get_ancestry
        ; f = get_ancestry_rpc
        ; budget = (5, `Per minute)
        ; cost = unit
        }
    ; Rpc_handler
        { rpc = Get_transition_knowledge
        ; f = get_transition_knowledge_rpc
        ; budget = (1, `Per minute)
        ; cost = unit
        }
    ; Rpc_handler
        { rpc = Get_transition_chain
        ; f = get_transition_chain_rpc
        ; budget = (1, `Per second) (* Not that confident about this one. *)
        ; cost = (fun x -> Int.max 1 (List.length x))
        }
    ; Rpc_handler
        { rpc = Get_transition_chain_proof
        ; f = get_transition_chain_proof_rpc
        ; budget = (3, `Per minute)
        ; cost = unit
        }
    ; Rpc_handler
        { rpc = Ban_notify
        ; f = ban_notify_rpc
        ; budget = (1, `Per minute)
        ; cost = unit
        }
    ]
  in
  let%map gossip_net =
    O1trace.thread "gossip_net" (fun () ->
        Gossip_net.Any.create config.creatable_gossip_net rpc_handlers
          (Gossip_net.Message.Any_sinks ((module Sinks), sinks)) )
  in
  (* The node status RPC is implemented directly in go, serving a string which
     is periodically updated. This is so that one can make this RPC on a node even
     if that node is at its connection limit. *)
  let fake_time = Time.now () in
  Clock.every' (Time.Span.of_min 1.) (fun () ->
      O1trace.thread "update_node_status" (fun () ->
          match%bind
            get_node_status
              { data = (); sender = Local; received_at = fake_time }
          with
          | Error _ ->
              Deferred.unit
          | Ok data ->
              Gossip_net.Any.set_node_status gossip_net
                ( Rpcs.Get_node_status.Node_status.to_yojson data
                |> Yojson.Safe.to_string )
              >>| ignore ) ) ;
  don't_wait_for
    (Gossip_net.Any.on_first_connect gossip_net ~f:(fun () ->
         (* After first_connect this list will only be empty if we filtered out all the peers due to mismatched chain id. *)
         don't_wait_for
           (let%map initial_peers = Gossip_net.Any.peers gossip_net in
            if List.is_empty initial_peers && not config.is_seed then (
              [%log fatal]
                "Failed to connect to any initial peers, possible chain id \
                 mismatch" ;
              raise No_initial_peers ) ) ) ) ;
  (* TODO: Think about buffering:
        I.e., what do we do when too many messages are coming in, or going out.
        For example, some things you really want to not drop (like your outgoing
        block announcment).
  *)
  { gossip_net; logger = config.logger; trust_system = config.trust_system }

(* lift and expose select gossip net functions *)
include struct
  open Gossip_net.Any

  let lift f { gossip_net; _ } = f gossip_net

  let peers = lift peers

  let bandwidth_info = lift bandwidth_info

  let get_peer_node_status t peer =
    let open Deferred.Or_error.Let_syntax in
    let%bind s = get_peer_node_status t.gossip_net peer in
    Or_error.try_with (fun () ->
        match
          Rpcs.Get_node_status.Node_status.of_yojson (Yojson.Safe.from_string s)
        with
        | Ok x ->
            x
        | Error e ->
            failwith e )
    |> Deferred.return

  let add_peer = lift add_peer

  let initial_peers = lift initial_peers

  let ban_notification_reader = lift ban_notification_reader

  let random_peers = lift random_peers

  let query_peer ?heartbeat_timeout ?timeout { gossip_net; _ } =
    query_peer ?heartbeat_timeout ?timeout gossip_net

  let query_peer' ?how ?heartbeat_timeout ?timeout { gossip_net; _ } =
    query_peer' ?how ?heartbeat_timeout ?timeout gossip_net

  let restart_helper { gossip_net; _ } = restart_helper gossip_net

  (* these cannot be directly lifted due to the value restriction *)
  let on_first_connect t = lift on_first_connect t

  let on_first_high_connectivity t = lift on_first_high_connectivity t

  let connection_gating_config t = lift connection_gating t

  let set_connection_gating_config t ?clean_added_peers config =
    lift (set_connection_gating ?clean_added_peers) t config
end

(* TODO: Have better pushback behavior *)
let log_gossip logger ~log_msg msg =
  [%str_log' trace logger]
    ~metadata:[ ("message", Gossip_net.Message.msg_to_yojson msg) ]
    log_msg

let broadcast_state t state =
  let msg = With_hash.data state in
  log_gossip t.logger (Gossip_net.Message.New_state msg)
    ~log_msg:
      (Gossip_new_state
         { state_hash = State_hash.With_state_hashes.state_hash state } ) ;
  Mina_metrics.(Gauge.inc_one Network.new_state_broadcasted) ;
  Gossip_net.Any.broadcast_state t.gossip_net msg

let broadcast_transaction_pool_diff t diff =
  log_gossip t.logger (Gossip_net.Message.Transaction_pool_diff diff)
    ~log_msg:(Gossip_transaction_pool_diff { txns = diff }) ;
  Mina_metrics.(Gauge.inc_one Network.transaction_pool_diff_broadcasted) ;
  Gossip_net.Any.broadcast_transaction_pool_diff t.gossip_net diff

let broadcast_snark_pool_diff t diff =
  Mina_metrics.(Gauge.inc_one Network.snark_pool_diff_broadcasted) ;
  log_gossip t.logger (Gossip_net.Message.Snark_pool_diff diff)
    ~log_msg:
      (Gossip_snark_pool_diff
         { work =
             Option.value_exn (Snark_pool.Resource_pool.Diff.to_compact diff)
         } ) ;
  Gossip_net.Any.broadcast_snark_pool_diff t.gossip_net diff

let find_map xs ~f =
  let open Async in
  let ds = List.map xs ~f in
  let filter ~f =
    Deferred.bind ~f:(fun x -> if f x then return x else Deferred.never ())
  in
  let none_worked =
    Deferred.bind (Deferred.all ds) ~f:(fun ds ->
        (* TODO: Validation applicative here *)
        if List.for_all ds ~f:Or_error.is_error then
          return (Or_error.error_string "all none")
        else Deferred.never () )
  in
  Deferred.any (none_worked :: List.map ~f:(filter ~f:Or_error.is_ok) ds)

let make_rpc_request ?heartbeat_timeout ?timeout ~rpc ~label t peer input =
  let open Deferred.Let_syntax in
  match%map
    query_peer ?heartbeat_timeout ?timeout t peer.Peer.peer_id rpc input
  with
  | Connected { data = Ok (Some response); _ } ->
      Ok response
  | Connected { data = Ok None; _ } ->
      Or_error.errorf
        !"Peer %{sexp:Network_peer.Peer.Id.t} doesn't have the requested %s"
        peer.peer_id label
  | Connected { data = Error e; _ } ->
      Error e
  | Failed_to_connect e ->
      Error (Error.tag e ~tag:"failed-to-connect")

let get_transition_chain_proof ?heartbeat_timeout ?timeout t =
  make_rpc_request ?heartbeat_timeout ?timeout
    ~rpc:Rpcs.Get_transition_chain_proof ~label:"transition chain proof" t

let get_transition_chain ?heartbeat_timeout ?timeout t =
  make_rpc_request ?heartbeat_timeout ?timeout ~rpc:Rpcs.Get_transition_chain
    ~label:"chain of transitions" t

let get_best_tip ?heartbeat_timeout ?timeout t peer =
  make_rpc_request ?heartbeat_timeout ?timeout ~rpc:Rpcs.Get_best_tip
    ~label:"best tip" t peer ()

let ban_notify t peer banned_until =
  query_peer t peer.Peer.peer_id Rpcs.Ban_notify banned_until
  >>| Fn.const (Ok ())

let try_non_preferred_peers (type b) t input peers ~rpc :
    b Envelope.Incoming.t Deferred.Or_error.t =
  let max_current_peers = 8 in
  let rec loop peers num_peers =
    if num_peers > max_current_peers then
      return
        (Or_error.error_string
           "None of randomly-chosen peers can handle the request" )
    else
      let current_peers, remaining_peers = List.split_n peers num_peers in
      find_map current_peers ~f:(fun peer ->
          let%bind response_or_error =
            query_peer t peer.Peer.peer_id rpc input
          in
          match response_or_error with
          | Connected ({ data = Ok (Some data); _ } as envelope) ->
              let%bind () =
                Trust_system.(
                  record t.trust_system t.logger peer
                    Actions.
                      ( Fulfilled_request
                      , Some ("Nonpreferred peer returned valid response", [])
                      ))
              in
              return (Ok (Envelope.Incoming.map envelope ~f:(Fn.const data)))
          | Connected { data = Ok None; _ } ->
              loop remaining_peers (2 * num_peers)
          | _ ->
              loop remaining_peers (2 * num_peers) )
  in
  loop peers 1

let rpc_peer_then_random (type b) t peer_id input ~rpc :
    b Envelope.Incoming.t Deferred.Or_error.t =
  let retry () =
    let%bind peers = random_peers t 8 in
    try_non_preferred_peers t input peers ~rpc
  in
  match%bind query_peer t peer_id rpc input with
  | Connected { data = Ok (Some response); sender; _ } ->
      let%bind () =
        match sender with
        | Local ->
            return ()
        | Remote peer ->
            Trust_system.(
              record t.trust_system t.logger peer
                Actions.
                  ( Fulfilled_request
                  , Some ("Preferred peer returned valid response", []) ))
      in
      return (Ok (Envelope.Incoming.wrap ~data:response ~sender))
  | Connected { data = Ok None; sender; _ } ->
      let%bind () =
        match sender with
        | Remote peer ->
            Trust_system.(
              record t.trust_system t.logger peer
                Actions.
                  ( No_reply_from_preferred_peer
                  , Some ("When querying preferred peer, got no response", [])
                  ))
        | Local ->
            return ()
      in
      retry ()
  | Connected { data = Error e; sender; _ } ->
      (* FIXME #4094: determine if more specific actions apply here *)
      let%bind () =
        match sender with
        | Remote peer ->
            Trust_system.(
              record t.trust_system t.logger peer
                Actions.
                  ( Outgoing_connection_error
                  , Some
                      ( "Error while doing RPC"
                      , [ ("error", Error_json.error_to_yojson e) ] ) ))
        | Local ->
            return ()
      in
      retry ()
  | Failed_to_connect _ ->
      (* Since we couldn't connect, we have no IP to ban. *)
      retry ()

let get_staged_ledger_aux_and_pending_coinbases_at_hash t inet_addr input =
  rpc_peer_then_random t inet_addr input
    ~rpc:Rpcs.Get_staged_ledger_aux_and_pending_coinbases_at_hash
  >>|? Envelope.Incoming.data

let get_ancestry t inet_addr input =
  rpc_peer_then_random t inet_addr input ~rpc:Rpcs.Get_ancestry

module Sl_downloader = struct
  module Key = struct
    module T = struct
      type t = Ledger_hash.t * Sync_ledger.Query.t
      [@@deriving hash, compare, sexp, to_yojson]
    end

    include T
    include Comparable.Make (T)
    include Hashable.Make (T)
  end

  include
    Downloader.Make
      (Key)
      (struct
        type t = unit [@@deriving to_yojson]

        let download : t = ()

        let worth_retrying () = true
      end)
      (struct
        type t =
          (Mina_base.Ledger_hash.t * Sync_ledger.Query.t) * Sync_ledger.Answer.t
        [@@deriving to_yojson]

        let key = fst
      end)
      (Ledger_hash)
end

let glue_sync_ledger :
       t
    -> preferred:Peer.t list
    -> (Mina_base.Ledger_hash.t * Sync_ledger.Query.t)
       Pipe_lib.Linear_pipe.Reader.t
    -> ( Mina_base.Ledger_hash.t
       * Sync_ledger.Query.t
       * Sync_ledger.Answer.t Network_peer.Envelope.Incoming.t )
       Pipe_lib.Linear_pipe.Writer.t
    -> unit =
 fun t ~preferred query_reader response_writer ->
  let downloader =
    let heartbeat_timeout = Time_ns.Span.of_sec 20. in
    let global_stop = Pipe_lib.Linear_pipe.closed query_reader in
    let knowledge h peer =
      match%map
        query_peer ~heartbeat_timeout ~timeout:(Time.Span.of_sec 10.) t
          peer.Peer.peer_id Rpcs.Answer_sync_ledger_query (h, Num_accounts)
      with
      | Connected { data = Ok _; _ } ->
          `Call (fun (h', _) -> Ledger_hash.equal h' h)
      | Failed_to_connect _ | Connected { data = Error _; _ } ->
          `Some []
    in
    let%bind _ = Linear_pipe.values_available query_reader in
    let root_hash_r, root_hash_w =
      Broadcast_pipe.create
        (Option.value_exn (Linear_pipe.peek query_reader) |> fst)
    in
    Sl_downloader.create ~preferred ~max_batch_size:100
      ~peers:(fun () -> peers t)
      ~knowledge_context:root_hash_r ~knowledge ~stop:global_stop
      ~trust_system:t.trust_system
      ~get:(fun (peer : Peer.t) qs ->
        List.iter qs ~f:(fun (h, _) ->
            if
              not (Ledger_hash.equal h (Broadcast_pipe.Reader.peek root_hash_r))
            then don't_wait_for (Broadcast_pipe.Writer.write root_hash_w h) ) ;
        let%map rs =
          query_peer' ~how:`Parallel ~heartbeat_timeout
            ~timeout:(Time.Span.of_sec (Float.of_int (List.length qs) *. 2.))
            t peer.peer_id Rpcs.Answer_sync_ledger_query qs
        in
        match rs with
        | Failed_to_connect e ->
            Error e
        | Connected res -> (
            match res.data with
            | Error e ->
                Error e
            | Ok rs -> (
                match List.zip qs rs with
                | Unequal_lengths ->
                    Or_error.error_string "mismatched lengths"
                | Ok ps ->
                    Ok
                      (List.filter_map ps ~f:(fun (q, r) ->
                           match r with Ok r -> Some (q, r) | Error _ -> None )
                      ) ) ) )
  in
  don't_wait_for
    (let%bind downloader = downloader in
     Linear_pipe.iter_unordered ~max_concurrency:400 query_reader ~f:(fun q ->
         match%bind
           Sl_downloader.Job.result
             (Sl_downloader.download downloader ~key:q ~attempts:Peer.Map.empty)
         with
         | Error _ ->
             Deferred.unit
         | Ok (a, _) ->
             Linear_pipe.write_if_open response_writer
               (fst q, snd q, { a with data = snd a.data }) ) )
