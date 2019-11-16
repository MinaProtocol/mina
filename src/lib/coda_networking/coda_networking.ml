open Core
open O1trace
open Async
open Coda_base
open Coda_state
open Pipe_lib
open Network_peer
open Coda_transition

let refused_answer_query_string = "Refused to answer_query"

type exn += No_initial_peers

module Rpcs = struct
  (* for versioning of the types here, see

     RFC 0012, and

     https://ocaml.janestreet.com/ocaml-core/latest/doc/async_rpc_kernel/Async_rpc_kernel/Versioned_rpc/

   *)

  module Get_staged_ledger_aux_and_pending_coinbases_at_hash = struct
    module Master = struct
      let name = "get_staged_ledger_aux_and_pending_coinbases_at_hash"

      module T = struct
        (* "master" types, do not change *)
        type query = State_hash.Stable.V1.t

        type response =
          ( Staged_ledger.Scan_state.Stable.V1.t
          * Ledger_hash.Stable.V1.t
          * Pending_coinbase.Stable.V1.t )
          option
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include Master
    end)

    module V1 = struct
      module T = struct
        type query = State_hash.Stable.V1.t [@@deriving bin_io, version {rpc}]

        type response =
          ( Staged_ledger.Scan_state.Stable.V1.t
          * Ledger_hash.Stable.V1.t
          * Pending_coinbase.Stable.V1.t )
          option
        [@@deriving bin_io, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      include T
      include Register (T)
    end
  end

  module Answer_sync_ledger_query = struct
    module Master = struct
      let name = "answer_sync_ledger_query"

      module T = struct
        (* "master" types, do not change *)
        type query = Ledger_hash.Stable.V1.t * Sync_ledger.Query.Stable.V1.t

        type response =
          Sync_ledger.Answer.Stable.V1.t Core.Or_error.Stable.V1.t
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include Master
    end)

    module V1 = struct
      module T = struct
        type query = Ledger_hash.Stable.V1.t * Sync_ledger.Query.Stable.V1.t
        [@@deriving bin_io, sexp, version {rpc}]

        type response =
          Sync_ledger.Answer.Stable.V1.t Core.Or_error.Stable.V1.t
        [@@deriving bin_io, sexp, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      include T
      include Register (T)
    end
  end

  module Get_transition_chain = struct
    module Master = struct
      let name = "get_transition_chain"

      module T = struct
        type query = State_hash.Stable.V1.t list [@@deriving sexp, to_yojson]

        type response = External_transition.Stable.V1.t list option
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include Master
    end)

    module V1 = struct
      module T = struct
        type query = State_hash.Stable.V1.t list
        [@@deriving bin_io, sexp, version {rpc}]

        type response = External_transition.Stable.V1.t list option
        [@@deriving bin_io, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      include T
      include Register (T)
    end
  end

  module Get_transition_chain_proof = struct
    module Master = struct
      let name = "get_transition_chain_proof"

      module T = struct
        type query = State_hash.Stable.V1.t [@@deriving sexp, to_yojson]

        type response =
          (State_hash.Stable.V1.t * State_body_hash.Stable.V1.t list) option
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include Master
    end)

    module V1 = struct
      module T = struct
        type query = State_hash.Stable.V1.t
        [@@deriving bin_io, sexp, version {rpc}]

        type response =
          (State_hash.Stable.V1.t * State_body_hash.Stable.V1.t list) option
        [@@deriving bin_io, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      include T
      include Register (T)
    end
  end

  module Get_ancestry = struct
    module Master = struct
      let name = "get_ancestry"

      module T = struct
        (* "master" types, do not change *)
        type query = Consensus.Data.Consensus_state.Value.t
        [@@deriving sexp, to_yojson]

        type response =
          ( External_transition.Stable.V1.t
          , State_body_hash.t list * External_transition.t )
          Proof_carrying_data.Stable.V1.t
          option
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include Master
    end)

    module V1 = struct
      module T = struct
        type query = Consensus.Data.Consensus_state.Value.Stable.V1.t
        [@@deriving bin_io, sexp, version {rpc}]

        type response =
          ( External_transition.Stable.V1.t
          , State_body_hash.Stable.V1.t list * External_transition.Stable.V1.t
          )
          Proof_carrying_data.Stable.V1.t
          option
        [@@deriving bin_io, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      include T
      include Register (T)
    end
  end

  module Ban_notify = struct
    module Master = struct
      let name = "ban_notify"

      module T = struct
        (* "master" types, do not change *)

        (* banned until this time *)
        type query = Core.Time.Stable.V1.t [@@deriving sexp]

        type response = unit
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include Master
    end)

    module V1 = struct
      module T = struct
        type query = Core.Time.Stable.V1.t
        [@@deriving bin_io, sexp, version {rpc}]

        type response = unit [@@deriving bin_io, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      include T
      include Register (T)
    end
  end

  module Get_bootstrappable_best_tip = struct
    module Master = struct
      let name = "get_bootstrappable_best_tip"

      module T = struct
        (* "master" types, do not change *)
        type query = Consensus.Data.Consensus_state.Value.t
        [@@deriving sexp, to_yojson]

        type response =
          ( External_transition.Stable.V1.t
          , State_body_hash.Stable.V1.t list * External_transition.Stable.V1.t
          )
          Proof_carrying_data.Stable.V1.t
          option
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include Master
    end)

    module V1 = struct
      module T = struct
        type query = Consensus.Data.Consensus_state.Value.Stable.V1.t
        [@@deriving bin_io, sexp, version {rpc}]

        type response =
          ( External_transition.Stable.V1.t
          , State_body_hash.Stable.V1.t list * External_transition.Stable.V1.t
          )
          Proof_carrying_data.Stable.V1.t
          option
        [@@deriving bin_io, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      include T
      include Register (T)
    end
  end
end

module Make_message (Inputs : sig
  module Snark_pool_diff : sig
    type t [@@deriving sexp]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving bin_io, sexp, to_yojson, version]
        end
      end
      with type V1.t = t
  end

  module Transaction_pool_diff : sig
    type t [@@deriving sexp]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving bin_io, sexp, to_yojson, version]
        end
      end
      with type V1.t = t
  end
end) =
struct
  open Inputs

  module Master = struct
    module T = struct
      (* "master" types, do not change *)
      type msg =
        | New_state of External_transition.Stable.V1.t
        | Snark_pool_diff of Snark_pool_diff.Stable.V1.t
        | Transaction_pool_diff of Transaction_pool_diff.Stable.V1.t
      [@@deriving bin_io, sexp, to_yojson]
    end

    let name = "message"

    module Caller = T
    module Callee = T
  end

  include Master.T
  include Versioned_rpc.Both_convert.One_way.Make (Master)

  module V1 = struct
    module T = struct
      type msg = Master.T.msg =
        | New_state of External_transition.Stable.V1.t
        | Snark_pool_diff of Snark_pool_diff.Stable.V1.t
        | Transaction_pool_diff of Transaction_pool_diff.Stable.V1.t
      [@@deriving bin_io, sexp, version {rpc}]

      let callee_model_of_msg = Fn.id

      let msg_of_caller_model = Fn.id
    end

    include Register (T)
  end
end

module type Inputs_intf = sig
  module Snark_pool_diff : sig
    type t [@@deriving sexp, to_yojson]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io, to_yojson, version]
        end
      end
      with type V1.t = t

    val compact_json : t -> Yojson.Safe.json
  end

  module Transaction_pool_diff : sig
    type t [@@deriving sexp, to_yojson]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io, to_yojson, version]
        end
      end
      with type V1.t = t
  end
end

module Subscription = Coda_net2.Pubsub.Subscription

module type Config_intf = sig
  type log_gossip_heard =
    {snark_pool_diff: bool; transaction_pool_diff: bool; new_state: bool}
  [@@deriving make, fields]

  type t =
    { logger: Logger.t
    ; trust_system: Trust_system.t
    ; time_controller: Block_time.Controller.t
    ; addrs_and_ports: Node_addrs_and_ports.t
    ; conf_dir: string
    ; chain_id: string
    ; log_gossip_heard: log_gossip_heard
    ; keypair: Coda_net2.Keypair.t option
    ; peers: Coda_net2.Multiaddr.t list
    ; consensus_local_state: Consensus.Data.Local_state.t }
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  module Peer = Peer

  type snark_pool_diff = Inputs.Snark_pool_diff.t

  type transaction_pool_diff = Inputs.Transaction_pool_diff.t

  type ban_notification = {banned_peer: Peer.t; banned_until: Time.t}
  [@@deriving fields]

  module Config = struct
    type log_gossip_heard =
      {snark_pool_diff: bool; transaction_pool_diff: bool; new_state: bool}
    [@@deriving make, fields]

    type t =
      { logger: Logger.t
      ; trust_system: Trust_system.t
      ; time_controller: Block_time.Controller.t
      ; addrs_and_ports: Node_addrs_and_ports.t
      ; conf_dir: string
      ; chain_id: string
      ; log_gossip_heard: log_gossip_heard
      ; keypair: Coda_net2.Keypair.t option
      ; peers: Coda_net2.Multiaddr.t list
      ; consensus_local_state: Consensus.Data.Local_state.t }
  end

  type subscriptions =
    { new_states: External_transition.Stable.V1.t Subscription.t
    ; transaction_pool_diffs: Transaction_pool_diff.Stable.V1.t Subscription.t
    ; snark_pool_diffs: Snark_pool_diff.Stable.V1.t Subscription.t }

  type pipes =
    { new_states:
        (External_transition.Stable.V1.t Envelope.Incoming.t * Block_time.t)
        Strict_pipe.Reader.t
    ; transaction_pool_diffs:
        Transaction_pool_diff.Stable.V1.t Envelope.Incoming.t
        Strict_pipe.Reader.t
    ; snark_pool_diffs:
        Snark_pool_diff.Stable.V1.t Envelope.Incoming.t Strict_pipe.Reader.t }

  type t =
    { net2: Coda_net2.net
    ; config: Config.t
    ; logger: Logger.t
    ; trust_system: Trust_system.t
    ; subscriptions: subscriptions
    ; pipes: pipes
    ; online_status: [`Offline | `Online] Broadcast_pipe.Reader.t
    ; first_received_message: unit Ivar.t }
  [@@deriving fields]

  let transaction_pool_diffs t = t.pipes.transaction_pool_diffs

  let snark_pool_diffs t = t.pipes.snark_pool_diffs

  let states t = t.pipes.new_states

  let offline_time =
    Block_time.Span.of_ms @@ Int64.of_int Consensus.Constants.inactivity_ms

  let setup_timer time_controller sync_state_broadcaster =
    Block_time.Timeout.create time_controller offline_time ~f:(fun _ ->
        Broadcast_pipe.Writer.write sync_state_broadcaster `Offline
        |> don't_wait_for )

  let online_broadcaster time_controller received_messages =
    let online_reader, online_writer = Broadcast_pipe.create `Offline in
    let init =
      Block_time.Timeout.create time_controller
        (Block_time.Span.of_ms Int64.zero)
        ~f:ignore
    in
    Strict_pipe.Reader.fold received_messages ~init ~f:(fun old_timeout _ ->
        let%map () = Broadcast_pipe.Writer.write online_writer `Online in
        Block_time.Timeout.cancel time_controller old_timeout () ;
        setup_timer time_controller online_writer )
    |> Deferred.ignore |> don't_wait_for ;
    online_reader

  let wrap_rpc_data_in_envelope (conn : Network_peer.Peer.t) data =
    let sender = Envelope.Sender.Remote (conn.host, conn.peer_id) in
    Envelope.Incoming.wrap ~data ~sender

  let net2 t = t.net2

  let create_libp2p (config : Config.t) =
    let fail m = failwithf "Failed to connect to Kademlia process: %s" m () in
    match%bind
      Monitor.try_with (fun () ->
          trace "coda_net2" (fun () ->
              Coda_net2.create ~logger:config.logger
                ~conf_dir:(config.conf_dir ^/ "coda_net2") ) )
    with
    | Ok (Ok net2) -> (
        let open Coda_net2 in
        (* Make an ephemeral keypair for this session TODO: persist in the config dir *)
        let%bind me =
          match config.keypair with
          | Some kp ->
              return kp
          | None ->
              Keypair.random net2
        in
        let peerid = Keypair.to_peer_id me |> Peer.Id.to_string in
        Logger.info config.logger "libp2p peer ID this session is $peer_id"
          ~location:__LOC__ ~module_:__MODULE__
          ~metadata:[("peer_id", `String peerid)] ;
        let initializing_libp2p_result : unit Deferred.Or_error.t =
          let open Deferred.Or_error.Let_syntax in
          let%bind () =
            configure net2 ~me ~maddrs:[]
              ~external_maddr:
                (Multiaddr.of_string
                   (sprintf "/ip4/%s/tcp/%d"
                      (Unix.Inet_addr.to_string
                         config.addrs_and_ports.external_ip)
                      (Option.value_exn config.addrs_and_ports.peer).libp2p_port))
              ~network_id:"libp2p phase3 test network"
              ~on_new_peer:(Fn.const ())
          in
          (* TODO: chain ID as network ID. *)
          let%map _ =
            listen_on net2
              (Multiaddr.of_string
                 (sprintf "/ip4/%s/tcp/%d"
                    (config.addrs_and_ports.bind_ip |> Unix.Inet_addr.to_string)
                    (Option.value_exn config.addrs_and_ports.peer).libp2p_port))
          in
          Deferred.ignore
            (Deferred.bind
               ~f:(fun _ -> Coda_net2.begin_advertising net2)
               (* TODO: timeouts here in addition to the libp2p side? *)
               (Deferred.all
                  (List.map ~f:(Coda_net2.add_peer net2) config.peers)))
          |> don't_wait_for ;
          ()
        in
        match%map initializing_libp2p_result with
        | Ok () ->
            Some net2
        | Error e ->
            fail (Error.to_string_hum e) )
    | Ok (Error e) ->
        fail (Error.to_string_hum e)
    | Error e ->
        fail (Exn.to_string e)

  let rpc_transport_proto = "coda/rpc/0.0.1"

  let create (config : Config.t)
      ~(get_staged_ledger_aux_and_pending_coinbases_at_hash :
            State_hash.t Envelope.Incoming.t
         -> (Staged_ledger.Scan_state.t * Ledger_hash.t * Pending_coinbase.t)
            option
            Deferred.t)
      ~(answer_sync_ledger_query :
            (Ledger_hash.t * Ledger.Location.Addr.t Syncable_ledger.Query.t)
            Envelope.Incoming.t
         -> Sync_ledger.Answer.t Deferred.Or_error.t)
      ~(get_ancestry :
            Consensus.Data.Consensus_state.Value.t Envelope.Incoming.t
         -> ( External_transition.t
            , State_body_hash.t list * External_transition.t )
            Proof_carrying_data.t
            Deferred.Option.t)
      ~(get_bootstrappable_best_tip :
            Consensus.Data.Consensus_state.Value.t Envelope.Incoming.t
         -> ( External_transition.t
            , State_body_hash.t list * External_transition.t )
            Proof_carrying_data.t
            Deferred.Option.t)
      ~(get_transition_chain_proof :
            State_hash.t Envelope.Incoming.t
         -> (State_hash.t * State_body_hash.t list) Deferred.Option.t)
      ~(get_transition_chain :
            State_hash.t list Envelope.Incoming.t
         -> External_transition.t list Deferred.Option.t) =
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
    let record_unknown_item result sender action_msg msg_args =
      let%bind () =
        if Option.is_none result then
          Trust_system.(
            record_envelope_sender config.trust_system config.logger sender
              Actions.(Requested_unknown_item, Some (action_msg, msg_args)))
        else return ()
      in
      return result
    in
    (* each of the passed-in procedures expects an enveloped input, so
       we wrap the data received via RPC *)
    let get_staged_ledger_aux_and_pending_coinbases_at_hash_rpc conn ~version:_
        hash =
      let action_msg = "Staged ledger and pending coinbases at hash: $hash" in
      let msg_args = [("hash", State_hash.to_yojson hash)] in
      let%bind result, sender =
        run_for_rpc_result conn hash
          ~f:get_staged_ledger_aux_and_pending_coinbases_at_hash action_msg
          msg_args
      in
      record_unknown_item result sender action_msg msg_args
    in
    let answer_sync_ledger_query_rpc conn ~version:_
        ((hash, query) as sync_query) =
      let%bind result, sender =
        run_for_rpc_result conn sync_query ~f:answer_sync_ledger_query
          "Answer_sync_ledger_query: $query"
          [("query", Sync_ledger.Query.to_yojson query)]
      in
      let%bind () =
        match result with
        | Ok _ ->
            return ()
        | Error err ->
            (* N.B.: to_string_mach double-quotes the string, don't want that *)
            let err_msg = Error.to_string_hum err in
            if String.is_prefix err_msg ~prefix:refused_answer_query_string
            then
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
                                Ledger.Addr.to_yojson query )
                          ; ("error", `String err_msg) ] ) ))
            else return ()
      in
      return result
    in
    let get_ancestry_rpc conn ~version:_ query =
      Logger.debug config.logger ~module_:__MODULE__ ~location:__LOC__
        "Sending root proof to peer with IP %s"
        (Unix.Inet_addr.to_string conn.Peer.host) ;
      let action_msg = "Get_ancestry query: $query" in
      let msg_args = [("query", Rpcs.Get_ancestry.query_to_yojson query)] in
      let%bind result, sender =
        run_for_rpc_result conn query ~f:get_ancestry action_msg msg_args
      in
      record_unknown_item result sender action_msg msg_args
    in
    let get_bootstrappable_best_tip_rpc conn ~version:_ query =
      Logger.debug config.logger ~module_:__MODULE__ ~location:__LOC__
        "Sending best_tip to peer with IP %s"
        (Unix.Inet_addr.to_string conn.Peer.host) ;
      let action_msg = "Get_bootstrappable_best_tip query: $query" in
      let msg_args =
        [("query", Rpcs.Get_bootstrappable_best_tip.query_to_yojson query)]
      in
      let%bind result, sender =
        run_for_rpc_result conn query ~f:get_bootstrappable_best_tip action_msg
          msg_args
      in
      record_unknown_item result sender action_msg msg_args
    in
    let get_transition_chain_proof_rpc conn ~version:_ query =
      Logger.info config.logger ~module_:__MODULE__ ~location:__LOC__
        "Sending transition_chain_proof to peer with IP %s"
        (Unix.Inet_addr.to_string conn.Peer.host) ;
      let action_msg = "Get_transition_chain_proof query: $query" in
      let msg_args =
        [("query", Rpcs.Get_transition_chain_proof.query_to_yojson query)]
      in
      let%bind result, sender =
        run_for_rpc_result conn query ~f:get_transition_chain_proof action_msg
          msg_args
      in
      record_unknown_item result sender action_msg msg_args
    in
    let get_transition_chain_rpc conn ~version:_ query =
      Logger.info config.logger ~module_:__MODULE__ ~location:__LOC__
        "Sending transition_chain to peer with IP %s"
        (Unix.Inet_addr.to_string conn.Peer.host) ;
      let action_msg = "Get_transition_chain query: $query" in
      let msg_args =
        [("query", Rpcs.Get_transition_chain.query_to_yojson query)]
      in
      let%bind result, sender =
        run_for_rpc_result conn query ~f:get_transition_chain action_msg
          msg_args
      in
      record_unknown_item result sender action_msg msg_args
    in
    let ban_notify_rpc conn ~version:_ ban_until =
      (* the port in `conn' is an ephemeral port, not of interest *)
      Logger.warn config.logger ~module_:__MODULE__ ~location:__LOC__
        "Node banned by peer $peer until $ban_until"
        ~metadata:
          [ ("peer", `String (Unix.Inet_addr.to_string conn.Peer.host))
          ; ( "ban_until"
            , `String (Time.to_string_abs ~zone:Time.Zone.utc ban_until) ) ] ;
      (* no computation to do; we're just getting notification *)
      Deferred.unit
    in
    let _implementations =
      List.concat
        [ Rpcs.Get_staged_ledger_aux_and_pending_coinbases_at_hash
          .implement_multi
            get_staged_ledger_aux_and_pending_coinbases_at_hash_rpc
        ; Rpcs.Answer_sync_ledger_query.implement_multi
            answer_sync_ledger_query_rpc
        ; Rpcs.Get_bootstrappable_best_tip.implement_multi
            get_bootstrappable_best_tip_rpc
        ; Rpcs.Get_ancestry.implement_multi get_ancestry_rpc
        ; Rpcs.Get_transition_chain_proof.implement_multi
            get_transition_chain_proof_rpc
        ; Rpcs.Get_transition_chain.implement_multi get_transition_chain_rpc
        ; Rpcs.Ban_notify.implement_multi ban_notify_rpc
        ; Consensus.Hooks.Rpcs.implementations ~logger:config.logger
            ~local_state:config.consensus_local_state ]
    in
    let%bind net2 = create_libp2p config >>| fun x -> Option.value_exn x in
    (* TODO: after we've meshed, make sure we managed to actually connect to a peer *)
    don't_wait_for
      (let%map () = Deferred.return () in
       raise No_initial_peers) ;
    (* TODO: Think about buffering:
       I.e., what do we do when too many messages are coming in, or going out.
       For example, some things you really want to not drop (like your outgoing
       block announcment).
    *)
    let online_notifier, bump_online =
      Strict_pipe.create ~name:"online notifier"
        (Buffered (`Capacity 1, `Overflow Drop_head))
    in
    (* TODO: replace this online_broadcaster pipe with an externally driven state machine *)
    let online_status =
      online_broadcaster config.time_controller online_notifier
    in
    let first_received_message = Ivar.create () in
    (* *)
    let%bind new_states =
      Coda_net2.Pubsub.subscribe_encode net2 "coda/blocks/0.0.1"
        ~should_forward_message:(fun ~sender:_ ~data:_ -> Deferred.return true)
        ~bin_prot:External_transition.Stable.V1.bin_t
        ~on_decode_failure:`Ignore
      (*TODO: trust *)
      >>| Or_error.ok_exn
    in
    let%bind snark_pool_diffs =
      Coda_net2.Pubsub.subscribe_encode net2 "coda/snark-pool/0.0.1"
        ~should_forward_message:(fun ~sender:_ ~data:_ -> Deferred.return true)
        ~bin_prot:Snark_pool_diff.Stable.V1.bin_t ~on_decode_failure:`Ignore
      >>| Or_error.ok_exn
    in
    let%bind transaction_pool_diffs =
      Coda_net2.Pubsub.subscribe_encode net2 "coda/txn-pool/0.0.1"
        ~should_forward_message:(fun ~sender:_ ~data:_ -> Deferred.return true)
        ~bin_prot:Transaction_pool_diff.Stable.V1.bin_t
        ~on_decode_failure:`Ignore
      >>| Or_error.ok_exn
    in
    let annotate_with_log ~name ~field ~to_yojson ~metadata_name ~map =
      let msg = sprintf "Received %s from $sender" name in
      fun envelope ->
        Strict_pipe.Writer.write bump_online () ;
        if field config.log_gossip_heard then
          Logger.debug config.logger "%s" msg ~module_:__MODULE__
            ~location:__LOC__
            ~metadata:
              [ (metadata_name, to_yojson (Envelope.Incoming.data envelope))
              ; ( "sender"
                , Envelope.(Sender.to_yojson (Incoming.sender envelope)) ) ] ;
        map envelope
    in
    let states_pipe =
      Strict_pipe.Reader.map
        (Coda_net2.Pubsub.Subscription.message_pipe new_states)
        ~f:
          (annotate_with_log ~name:"block" ~field:Config.new_state
             ~to_yojson:External_transition.to_yojson ~metadata_name:"block"
             ~map:(fun envelope ->
               let state = Envelope.Incoming.data envelope in
               Perf_histograms.add_span ~name:"external_transition_latency"
                 (Core.Time.abs_diff
                    Block_time.(now config.time_controller |> to_time)
                    ( External_transition.protocol_state state
                    |> Protocol_state.blockchain_state
                    |> Blockchain_state.timestamp |> Block_time.to_time )) ;
               (envelope, Block_time.now config.time_controller) ))
    in
    let snark_pool_pipe =
      Strict_pipe.Reader.map
        (Coda_net2.Pubsub.Subscription.message_pipe snark_pool_diffs)
        ~f:
          (annotate_with_log ~name:"Snark-pool diff"
             ~field:Config.snark_pool_diff
             ~to_yojson:Snark_pool_diff.compact_json ~metadata_name:"work"
             ~map:(fun envelope ->
               Coda_metrics.(
                 Counter.inc_one
                   Snark_work.completed_snark_work_received_gossip) ;
               envelope ))
    in
    let transaction_pool_pipe =
      Strict_pipe.Reader.map
        (Coda_net2.Pubsub.Subscription.message_pipe transaction_pool_diffs)
        ~f:
          (annotate_with_log ~name:"transaction-pool diff"
             ~field:Config.transaction_pool_diff
             ~to_yojson:Transaction_pool_diff.to_yojson ~metadata_name:"work"
             ~map:Fn.id)
    in
    Deferred.return
      { net2
      ; config
      ; logger= config.logger
      ; trust_system= config.trust_system
      ; subscriptions= {new_states; snark_pool_diffs; transaction_pool_diffs}
      ; pipes=
          { new_states= states_pipe
          ; snark_pool_diffs= snark_pool_pipe
          ; transaction_pool_diffs= transaction_pool_pipe }
      ; online_status
      ; first_received_message }

  let first_message {first_received_message; _} = first_received_message

  (* TODO: what should this be? fulfilled after first gossip? *)
  let first_connection _net =
    let iv = Ivar.create () in
    don't_wait_for (after (Time.Span.of_sec 30.) >>| fun () -> Ivar.fill iv ()) ;
    iv

  let high_connectivity _net =
    let iv = Ivar.create () in
    don't_wait_for (after (Time.Span.of_sec 45.) >>| fun () -> Ivar.fill iv ()) ;
    iv

  (* TODO: log these broadcasts? *)
  let broadcast_state t state =
    Coda_net2.Pubsub.Subscription.publish t.subscriptions.new_states state
    |> don't_wait_for

  let broadcast_transaction_pool_diff t diff =
    Coda_net2.Pubsub.Subscription.publish
      t.subscriptions.transaction_pool_diffs diff
    |> don't_wait_for

  let broadcast_snark_pool_diff t diff =
    Coda_net2.Pubsub.Subscription.publish t.subscriptions.snark_pool_diffs diff
    |> don't_wait_for

  (* TODO: This is kinda inefficient *)
  let find_map xs ~f =
    let open Async in
    let ds = List.map xs ~f in
    let filter ~f =
      Deferred.bind ~f:(fun x -> if f x then return x else Deferred.never ())
    in
    let none_worked =
      Deferred.bind (Deferred.all ds) ~f:(fun ds ->
          if List.for_all ds ~f:Option.is_none then return None
          else Deferred.never () )
    in
    Deferred.any (none_worked :: List.map ~f:(filter ~f:Option.is_some) ds)

  (* TODO: Don't copy and paste *)
  let find_map' xs ~f =
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

  let peers t = Coda_net2.peers t.net2

  let random_peers t n =
    let%map peers = peers t >>| Array.of_list in
    Array.permute peers ;
    List.take (Array.to_list peers) n

  let initial_peers (t : t) = t.config.peers

  let ban_notification_reader _t =
    (* TODO: make bans and surface them *)
    let reader, _really_bad_leak = Linear_pipe.create () in
    reader

  let online_status t = t.online_status

  type ('q, 'r) dispatch =
    Versioned_rpc.Connection_with_menu.t -> 'q -> 'r Deferred.Or_error.t

  let try_call_rpc :
        'r 'q.    t -> Unix.Inet_addr.t -> string Pipe.Reader.t
        -> string Pipe.Writer.t -> ('r, 'q) dispatch -> 'r
        -> 'q Deferred.Or_error.t =
   fun t addr rd wr dispatch query ->
    let call () =
      Monitor.try_with (fun () ->
          Async_rpc_kernel.Rpc.Connection.with_close
            ~connection_state:(fun _ -> ())
            ~dispatch_queries:(fun conn ->
              Versioned_rpc.Connection_with_menu.create conn
              >>=? fun conn' -> dispatch conn' query )
            Async_rpc_kernel.Pipe_transport.(create Kind.string rd wr)
            ~on_handshake_error:
              (`Call
                (fun exn ->
                  let%map () =
                    Trust_system.(
                      record t.trust_system t.logger addr
                        Actions.
                          ( Outgoing_connection_error
                          , Some
                              ( "Handshake error: $exn"
                              , [("exn", `String (Exn.to_string exn))] ) ))
                  in
                  Or_error.error_string "handshake error" )) )
      >>= function
      | Ok (Ok result) ->
          (* call succeeded, result is valid *)
          Deferred.return (Ok result)
      | Ok (Error err) -> (
          (* call succeeded, result is an error *)
          Logger.error t.logger ~module_:__MODULE__ ~location:__LOC__
            "RPC call error: $error, same error in machine format: \
             $machine_error"
            ~metadata:
              [ ("error", `String (Error.to_string_hum err))
              ; ("machine_error", `String (Error.to_string_mach err)) ] ;
          match (Error.to_exn err, Error.sexp_of_t err) with
          | ( _
            , Sexp.List
                [ Sexp.List
                    [ Sexp.Atom "rpc_error"
                    ; Sexp.List [Sexp.Atom "Connection_closed"; _] ]
                ; _connection_description
                ; _rpc_tag
                ; _rpc_version ] ) ->
              let%map () =
                Trust_system.(
                  record t.trust_system t.logger addr
                    Actions.
                      ( Outgoing_connection_error
                      , Some ("Closed connection", []) ))
              in
              Error err
          | _ ->
              let%map () =
                Trust_system.(
                  record t.trust_system t.logger addr
                    Actions.
                      ( Violated_protocol
                      , Some
                          ( "RPC call failed, reason: $exn"
                          , [("exn", `String (Error.to_string_hum err))] ) ))
              in
              Error err )
      | Error monitor_exn -> (
          (* call itself failed *)
          (* TODO: learn what other exceptions are raised here *)
          let exn = Monitor.extract_exn monitor_exn in
          match exn with
          | _ ->
              Logger.error t.logger ~module_:__MODULE__ ~location:__LOC__
                "RPC call raised an exception: $exn"
                ~metadata:[("exn", `String (Exn.to_string exn))] ;
              Deferred.return (Or_error.of_exn exn) )
    in
    call ()

  let query_peer t (peer : Peer.Id.t) rpc rpc_input =
    let open Deferred.Or_error.Let_syntax in
    let%bind stream =
      Coda_net2.open_stream t.net2 ~protocol:rpc_transport_proto peer
    in
    let rd, wr = Coda_net2.Stream.pipes stream in
    let peer = Coda_net2.Stream.remote_peer stream in
    try_call_rpc t peer.host rd wr rpc rpc_input
    >>| fun data -> Envelope.Incoming.wrap_peer ~data ~sender:peer

  let make_rpc_request ~(rpc_dispatch : ('a, 'b option) dispatch) ~label : _ -> _ -> _ -> 'b Envelope.Incoming.t Deferred.Or_error.t =
    let open Deferred.Let_syntax in
    fun t peer input ->
      match%map query_peer t peer rpc_dispatch input with
      | Ok resp -> (
        match resp.data with
        | Some data ->
            Ok (Envelope.Incoming.wrap ~data ~sender:resp.sender)
        | None ->
            Or_error.errorf
              !"Peer %{sexp:Network_peer.Peer.Id.t} doesn't have the
                requested %s"
              peer label )
      | Error e ->
          Error e

  let get_transition_chain_proof =
    make_rpc_request
      ~rpc_dispatch:Rpcs.Get_transition_chain_proof.dispatch_multi
      ~label:"transition"

  let get_transition_chain =
    make_rpc_request ~rpc_dispatch:Rpcs.Get_transition_chain.dispatch_multi
      ~label:"chain of transitions"

  let get_bootstrappable_best_tip =
    make_rpc_request
      ~rpc_dispatch:Rpcs.Get_bootstrappable_best_tip.dispatch_multi
      ~label:"best tip"

  let ban_notify t peer banned_until =
      query_peer t peer.Peer.peer_id Rpcs.Ban_notify.dispatch_multi
        banned_until

  let try_non_preferred_peers (type b) t input peers ~(rpc : (_, b option) dispatch) : b Envelope.Incoming.t Deferred.Or_error.t =
    let max_current_peers = 8 in
    let rec loop peers num_peers =
      if num_peers > max_current_peers then
        return
          (Or_error.error_string
             "None of randomly-chosen peers can handle the request")
      else
        let current_peers, remaining_peers = List.split_n peers num_peers in
        find_map' current_peers ~f:(fun peer ->
            let%bind response_or_error =
              query_peer t peer.Peer.peer_id rpc input
            in
            match response_or_error with
            | Ok envelope ->
              (match envelope.data with
              | Some data ->
                let%bind () =
                  Trust_system.(
                    record t.trust_system t.logger peer.host
                      Actions.
                        ( Fulfilled_request
                        , Some ("Nonpreferred peer returned valid response", [])
                        ))
                in
                return (Ok (Envelope.Incoming.map envelope ~f:(Fn.const data)))
              | None -> loop remaining_peers (2 * num_peers))
            | Error _ ->
                loop remaining_peers (2 * num_peers) )
    in
    loop peers 1

  let rpc_peer_then_random (type b) t peer_id input ~(rpc : ('a, b option) dispatch) : b Envelope.Incoming.t Deferred.Or_error.t =
    match%bind query_peer t peer_id rpc input with
    | Ok envelope ->
      (match envelope.data with
      | Some response ->
        let%bind () = (match envelope.Envelope.Incoming.sender with
        | Local -> return ()
        | Remote (sender, _) ->
          Trust_system.(
            record t.trust_system t.logger sender
              Actions.
                ( Fulfilled_request
                , Some ("Preferred peer returned valid response", []) )))
        in
        return (Ok (Envelope.Incoming.map envelope ~f:(Fn.const response)))
      | None  ->
        let%bind () = (
          match envelope.sender with
          | Remote (sender, _) -> Trust_system.(
            record t.trust_system t.logger sender
              Actions.
                ( Violated_protocol
                , Some ("When querying preferred peer, got no response", []) ))
          | Local -> return ()
        ) in
        let%bind peers = random_peers t 8 in
        try_non_preferred_peers t input peers ~rpc)
    | Error _ ->
        (* TODO: determine what punishments apply here *)
        Logger.error t.logger ~module_:__MODULE__ ~location:__LOC__
          !"get error from %{sexp: Peer.Id.t}"
          peer_id ;
        let%bind peers = random_peers t 8 in
        try_non_preferred_peers t input peers ~rpc

  let get_staged_ledger_aux_and_pending_coinbases_at_hash t peer input =
    rpc_peer_then_random t peer input
      ~rpc:
        Rpcs.Get_staged_ledger_aux_and_pending_coinbases_at_hash.dispatch_multi

  let get_ancestry t peer input =
    rpc_peer_then_random t peer input ~rpc:Rpcs.Get_ancestry.dispatch_multi

  let glue_sync_ledger t query_reader response_writer =
    (* We attempt to query 3 random peers, retry_max times. We keep track of the
       peers that couldn't answer a particular query and won't try them
       again. *)
    let retry_max = 6 in
    let retry_interval = Core.Time.Span.of_ms 200. in
    let rec answer_query ctr peers_tried query =
      O1trace.trace_event "ask sync ledger query" ;
      let%bind peers = random_peers t 3 in
      Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
        !"SL: Querying the following peers %{sexp: Peer.t list}"
        peers ;
      match%bind
        find_map peers ~f:(fun peer ->
            Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
              !"Asking %{sexp: Peer.t} query regarding ledger_hash %{sexp: \
                Ledger_hash.t}"
              peer (fst query) ;
            match%map
              query_peer t peer.peer_id
                Rpcs.Answer_sync_ledger_query.dispatch_multi query
            with
            | Ok response ->
            (match response.data with
            | Ok answer ->
                Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
                  !"Received answer from peer %{sexp: Peer.t} on ledger_hash \
                    %{sexp: Ledger_hash.t}"
                  peer (fst query) ;
                (* TODO : here is a place where an envelope could contain
                   a Peer.t, and not just an IP address, if desired
                *)
                let inet_addr = peer.host in
                Some
                  (Envelope.Incoming.wrap ~data:answer
                     ~sender:(Envelope.Sender.Remote (inet_addr, peer.peer_id)))
            | Error e ->
                Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
                  "Peer $peer didn't have enough information to answer \
                   ledger_hash query. See error for more details: $error"
                  ~metadata:[("error", `String (Error.to_string_hum e))] ;
                Hash_set.add peers_tried peer ;
                None)
            | Error err ->
                Logger.warn t.logger ~module_:__MODULE__ ~location:__LOC__
                  "Network error: %s" (Error.to_string_mach err) ;
                None )
      with
      | Some answer ->
          Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
            !"Succeeding with answer on ledger_hash %{sexp: Ledger_hash.t}"
            (fst query) ;
          (* TODO *)
          Linear_pipe.write_if_open response_writer
            (fst query, snd query, answer)
      | None ->
          Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
            !"None of the peers contacted were able to answer ledger_hash \
              query -- trying more" ;
          if ctr > retry_max then Deferred.unit
          else
            let%bind () = Clock.after retry_interval in
            answer_query (ctr + 1) peers_tried query
    in
    Linear_pipe.iter_unordered ~max_concurrency:8 query_reader
      ~f:(answer_query 0 (Peer.Hash_set.of_list []))
    |> don't_wait_for
end

include Make (struct
  open Coda_transition
  module Ledger_proof = Ledger_proof
  module Verifier = Verifier
  module Transaction_snark_work = Transaction_snark_work
  module Staged_ledger_diff = Staged_ledger_diff
  module External_transition = External_transition
  module Internal_transition = Internal_transition
  module Staged_ledger = Staged_ledger
  module Transaction_pool_diff =
    Network_pool.Transaction_pool.Resource_pool.Diff
  module Snark_pool_diff = Network_pool.Snark_pool.Resource_pool.Diff
end)
