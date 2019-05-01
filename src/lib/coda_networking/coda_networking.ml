open Core_kernel
open Async
open Kademlia
open Coda_base
open Pipe_lib
open Network_peer

(* assumption: the Rpcs functor is applied only once in the codebase, so that
   any versions appearing in Inputs represent unique types

   with that assumption, it's legitimate for the choice of versions to be made
   inside the Rpcs functor, rather than at the locus of application
*)

module Rpcs (Inputs : sig
  module Staged_ledger_aux_hash :
    Protocols.Coda_pow.Staged_ledger_aux_hash_intf

  module Staged_ledger_aux : sig
    type t

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving bin_io, version]
        end
      end
      with type V1.t = t
  end

  module Ledger_hash : Protocols.Coda_pow.Ledger_hash_intf

  module Blockchain_state : Blockchain_state.S

  module External_transition : External_transition.S
end) =
struct
  open Inputs

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
          ( Staged_ledger_aux.Stable.V1.t
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
          ( Staged_ledger_aux.Stable.V1.t
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

        type response = Sync_ledger.Answer.Stable.V1.t Or_error.t
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

  module Transition_catchup = struct
    module Master = struct
      let name = "transition_catchup"

      module T = struct
        (* "master" types, do not change *)
        type query = State_hash.Stable.V1.t

        type response =
          External_transition.Stable.V1.t Non_empty_list.Stable.V1.t option
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
          External_transition.Stable.V1.t Non_empty_list.Stable.V1.t option
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

  module Get_ancestry = struct
    module Master = struct
      let name = "get_ancestry"

      module T = struct
        (* "master" types, do not change *)
        type query = Consensus.Consensus_state.Value.t [@@deriving sexp]

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
        type query = Consensus.Consensus_state.Value.Stable.V1.t
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

module Message (Inputs : sig
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

  module External_transition : External_transition.S
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

    let summary = function
      | T.New_state _ ->
          "new state"
      | Snark_pool_diff _ ->
          "snark pool diff"
      | Transaction_pool_diff _ ->
          "transaction pool diff"
  end

  [%%define_locally
  V1.(summary)]
end

module type Inputs_intf = sig
  module External_transition : External_transition.S

  module Staged_ledger_aux_hash :
    Protocols.Coda_pow.Staged_ledger_aux_hash_intf

  module Ledger_hash : Protocols.Coda_pow.Ledger_hash_intf

  (* we omit Staged_ledger_hash, because the available module in Inputs is not versioned; instead, in the
     versioned RPC modules, we use a specific version
   *)
  module Blockchain_state : Coda_base.Blockchain_state.S

  module Staged_ledger_aux : sig
    type t

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving bin_io, version]
        end
      end
      with type V1.t = t

    val hash : t -> Staged_ledger_aux_hash.t
  end

  module Snark_pool_diff : sig
    type t [@@deriving sexp, to_yojson]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io, to_yojson, version]
        end
      end
      with type V1.t = t
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

  module Time : Protocols.Coda_pow.Time_intf
end

module type Config_intf = sig
  type gossip_config

  type time_controller

  type t =
    { logger: Logger.t
    ; gossip_net_params: gossip_config
    ; time_controller: time_controller
    ; consensus_local_state: Consensus.Local_state.t }
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  module Message = Message (Inputs)
  module Gossip_net = Gossip_net.Make (Message)
  module Peer = Peer

  module Config :
    Config_intf
    with type gossip_config := Gossip_net.Config.t
     and type time_controller := Time.Controller.t = struct
    type t =
      { logger: Logger.t
      ; gossip_net_params: Gossip_net.Config.t
      ; time_controller: Time.Controller.t
      ; consensus_local_state: Consensus.Local_state.t }
  end

  module Rpcs = Rpcs (Inputs)
  module Membership = Membership.Haskell

  type t =
    { gossip_net: Gossip_net.t
    ; logger: Logger.t
    ; trust_system: Trust_system.t
    ; states:
        (External_transition.t Envelope.Incoming.t * Time.t)
        Strict_pipe.Reader.t
    ; transaction_pool_diffs:
        Transaction_pool_diff.t Envelope.Incoming.t Linear_pipe.Reader.t
    ; snark_pool_diffs:
        Snark_pool_diff.t Envelope.Incoming.t Linear_pipe.Reader.t
    ; online_status: [`Offline | `Online] Broadcast_pipe.Reader.t }
  [@@deriving fields]

  let offline_time =
    Time.Span.of_ms @@ Int64.of_int Consensus.Constants.inactivity_secs

  let setup_timer time_controller sync_state_broadcaster =
    Time.Timeout.create time_controller offline_time ~f:(fun _ ->
        Broadcast_pipe.Writer.write sync_state_broadcaster `Offline
        |> don't_wait_for )

  let online_broadcaster time_controller received_messages =
    let online_reader, online_writer = Broadcast_pipe.create `Offline in
    let init =
      Time.Timeout.create time_controller
        (Time.Span.of_ms Int64.zero)
        ~f:ignore
    in
    Strict_pipe.Reader.fold received_messages ~init ~f:(fun old_timeout _ ->
        let%map () = Broadcast_pipe.Writer.write online_writer `Online in
        Time.Timeout.cancel time_controller old_timeout () ;
        setup_timer time_controller online_writer )
    |> Deferred.ignore |> don't_wait_for ;
    online_reader

  let wrap_rpc_data_in_envelope conn data =
    let inet_addr = Unix.Inet_addr.of_string conn.Host_and_port.host in
    let sender = Envelope.Sender.Remote inet_addr in
    Envelope.Incoming.wrap ~data ~sender

  let create (config : Config.t)
      ~(get_staged_ledger_aux_and_pending_coinbases_at_hash :
            State_hash.t Envelope.Incoming.t
         -> (Staged_ledger_aux.Stable.V1.t * Ledger_hash.t * Pending_coinbase.t)
            option
            Deferred.t)
      ~(answer_sync_ledger_query :
            (Ledger_hash.t * Ledger.Location.Addr.t Syncable_ledger.Query.t)
            Envelope.Incoming.t
         -> Sync_ledger.Answer.t Deferred.Or_error.t)
      ~(transition_catchup :
            State_hash.t Envelope.Incoming.t
         -> External_transition.t Non_empty_list.t option Deferred.t)
      ~(get_ancestry :
            Consensus.Consensus_state.Value.t Envelope.Incoming.t
         -> ( External_transition.t
            , State_body_hash.t list * External_transition.t )
            Proof_carrying_data.t
            Deferred.Option.t) =
    (* each of the passed-in procedures expects an enveloped input, so
       we wrap the data received via RPC *)
    let get_staged_ledger_aux_and_pending_coinbases_at_hash_rpc conn ~version:_
        hash =
      let hash_in_envelope = wrap_rpc_data_in_envelope conn hash in
      get_staged_ledger_aux_and_pending_coinbases_at_hash hash_in_envelope
    in
    let answer_sync_ledger_query_rpc conn ~version:_ query =
      let query_in_envelope = wrap_rpc_data_in_envelope conn query in
      answer_sync_ledger_query query_in_envelope
    in
    let transition_catchup_rpc conn ~version:_ hash =
      Logger.info config.logger ~module_:__MODULE__ ~location:__LOC__
        "Peer with IP %s sent transition_catchup" conn.Host_and_port.host ;
      let hash_in_envelope = wrap_rpc_data_in_envelope conn hash in
      transition_catchup hash_in_envelope
    in
    let get_ancestry_rpc conn ~version:_ query =
      Logger.info config.logger ~module_:__MODULE__ ~location:__LOC__
        "Sending root proof to peer with IP %s" conn.Host_and_port.host ;
      let query_in_envelope = wrap_rpc_data_in_envelope conn query in
      get_ancestry query_in_envelope
    in
    let implementations =
      List.concat
        [ Rpcs.Get_staged_ledger_aux_and_pending_coinbases_at_hash
          .implement_multi
            get_staged_ledger_aux_and_pending_coinbases_at_hash_rpc
        ; Rpcs.Answer_sync_ledger_query.implement_multi
            answer_sync_ledger_query_rpc
        ; Rpcs.Transition_catchup.implement_multi transition_catchup_rpc
        ; Rpcs.Get_ancestry.implement_multi get_ancestry_rpc
        ; Consensus.Rpcs.implementations ~logger:config.logger
            ~local_state:config.consensus_local_state ]
    in
    let%map gossip_net =
      Gossip_net.create config.gossip_net_params implementations
    in
    (* TODO: Think about buffering:
       I.e., what do we do when too many messages are coming in, or going out.
       For example, some things you really want to not drop (like your outgoing
       block announcment).
    *)
    let received_gossips, online_notifier =
      Strict_pipe.Reader.Fork.two (Gossip_net.received gossip_net)
    in
    let online_status =
      online_broadcaster config.time_controller online_notifier
    in
    let states, snark_pool_diffs, transaction_pool_diffs =
      Strict_pipe.Reader.partition_map3 received_gossips ~f:(fun envelope ->
          match Envelope.Incoming.data envelope with
          | New_state state ->
              Perf_histograms.add_span ~name:"external_transition_latency"
                (Core.Time.abs_diff (Core.Time.now ())
                   (External_transition.timestamp state |> Block_time.to_time)) ;
              `Fst
                ( Envelope.Incoming.map envelope ~f:(fun _ -> state)
                , Time.now config.time_controller )
          | Snark_pool_diff diff ->
              `Snd (Envelope.Incoming.map envelope ~f:(fun _ -> diff))
          | Transaction_pool_diff diff ->
              `Trd (Envelope.Incoming.map envelope ~f:(fun _ -> diff)) )
    in
    { gossip_net
    ; logger= config.logger
    ; trust_system= config.gossip_net_params.trust_system
    ; states
    ; snark_pool_diffs= Strict_pipe.Reader.to_linear_pipe snark_pool_diffs
    ; transaction_pool_diffs=
        Strict_pipe.Reader.to_linear_pipe transaction_pool_diffs
    ; online_status }

  (* TODO: Have better pushback behavior *)
  let broadcast t msg =
    Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
      ~metadata:[("message", Message.msg_to_yojson msg)]
      !"Broadcasting %s over gossip net"
      (Message.summary msg) ;
    Linear_pipe.write_without_pushback (Gossip_net.broadcast t.gossip_net) msg

  let broadcast_state t state = broadcast t (Message.New_state state)

  let broadcast_transaction_pool_diff t diff =
    broadcast t (Message.Transaction_pool_diff diff)

  let broadcast_snark_pool_diff t diff =
    broadcast t (Message.Snark_pool_diff diff)

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

  let peers t = Gossip_net.peers t.gossip_net

  let online_status t = t.online_status

  let random_peers {gossip_net; _} = Gossip_net.random_peers gossip_net

  let random_peers_except {gossip_net; _} n ~(except : Peer.Hash_set.t) =
    Gossip_net.random_peers_except gossip_net n ~except

  let catchup_transition t peer state_hash =
    let%bind () =
      Trust_system.(
        record t.trust_system t.logger peer.Peer.host
          Actions.(Made_request, Some ("transition_catchup", [])))
    in
    Gossip_net.query_peer t.gossip_net peer
      Rpcs.Transition_catchup.dispatch_multi state_hash

  let query_peer :
         t
      -> Network_peer.Peer.t
      -> (Versioned_rpc.Connection_with_menu.t -> 'q -> 'r Deferred.Or_error.t)
      -> 'q
      -> 'r Deferred.Or_error.t =
   fun t peer rpc rpc_input ->
    Gossip_net.query_peer t.gossip_net peer rpc rpc_input

  let try_non_preferred_peers t input peers ~rpc =
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
              Gossip_net.query_peer t.gossip_net peer rpc input
            in
            match response_or_error with
            | Ok (Some response) ->
                let%bind () =
                  Trust_system.(
                    record t.trust_system t.logger peer.host
                      Actions.
                        ( Fulfilled_request
                        , Some ("Nonpreferred peer returned valid response", [])
                        ))
                in
                return (Ok response)
            | Ok None ->
                loop remaining_peers (2 * num_peers)
            | Error _ ->
                loop remaining_peers (2 * num_peers) )
    in
    loop peers 1

  let try_preferred_peer t inet_addr input ~rpc =
    let peers_at_addr =
      Hashtbl.find_multi t.gossip_net.peers_by_ip inet_addr
    in
    (* if there's a single peer at inet_addr, call it the preferred peer *)
    match peers_at_addr with
    | [peer] -> (
        let get_random_peers () =
          let max_peers = 15 in
          let except = Peer.Hash_set.of_list [peer] in
          random_peers_except t max_peers ~except
        in
        let%bind response =
          Gossip_net.query_peer t.gossip_net peer rpc input
        in
        match response with
        | Ok (Some data) ->
            let%bind () =
              Trust_system.(
                record t.trust_system t.logger peer.host
                  Actions.
                    ( Fulfilled_request
                    , Some ("Preferred peer returned valid response", []) ))
            in
            return (Ok data)
        | Ok None ->
            let%bind () =
              Trust_system.(
                record t.trust_system t.logger peer.host
                  Actions.
                    ( Violated_protocol
                    , Some ("When querying preferred peer, got no response", [])
                    ))
            in
            let peers = get_random_peers () in
            try_non_preferred_peers t input peers ~rpc
        | Error _ ->
            (* TODO: determine what punishments apply here *)
            Logger.error t.logger ~module_:__MODULE__ ~location:__LOC__
              !"get error from %{sexp: Peer.t}"
              peer ;
            let peers = get_random_peers () in
            try_non_preferred_peers t input peers ~rpc )
    | _ ->
        (* no preferred peer *)
        let max_peers = 16 in
        let peers = random_peers t max_peers in
        try_non_preferred_peers t input peers ~rpc

  let get_staged_ledger_aux_and_pending_coinbases_at_hash t inet_addr input =
    let%bind () =
      Trust_system.(
        record t.trust_system t.logger inet_addr
          Actions.
            ( Made_request
            , Some ("get_staged_ledger_aux_and_pending_coinbases_at_hash", [])
            ))
    in
    try_preferred_peer t inet_addr input
      ~rpc:
        Rpcs.Get_staged_ledger_aux_and_pending_coinbases_at_hash.dispatch_multi

  let get_ancestry t inet_addr input =
    let%bind () =
      Trust_system.(
        record t.trust_system t.logger inet_addr
          Actions.(Made_request, Some ("get_ancestry", [])))
    in
    try_preferred_peer t inet_addr input ~rpc:Rpcs.Get_ancestry.dispatch_multi

  let glue_sync_ledger t query_reader response_writer =
    (* We attempt to query 3 random peers, retry_max times. We keep track of the
       peers that couldn't answer a particular query and won't try them
       again. *)
    let retry_max = 6 in
    let retry_interval = Core.Time.Span.of_ms 200. in
    let rec answer_query ctr peers_tried query =
      O1trace.trace_event "ask sync ledger query" ;
      let peers =
        Gossip_net.random_peers_except t.gossip_net 3 ~except:peers_tried
      in
      Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
        !"SL: Querying the following peers %{sexp: Peer.t list}"
        peers ;
      match%bind
        find_map peers ~f:(fun peer ->
            Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
              !"Asking %{sexp: Peer.t} query regarding ledger_hash %{sexp: \
                Ledger_hash.t}"
              peer (fst query) ;
            let%bind () =
              Trust_system.(
                record t.trust_system t.logger peer.host
                  Actions.
                    ( Made_request
                    , Some
                        ( "answer_sync_ledger_query: $query"
                        , [("query", Sync_ledger.Query.to_yojson (snd query))]
                        ) ))
            in
            match%map
              Gossip_net.query_peer t.gossip_net peer
                Rpcs.Answer_sync_ledger_query.dispatch_multi query
            with
            | Ok (Ok answer) ->
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
                     ~sender:(Envelope.Sender.Remote inet_addr))
            | Ok (Error e) ->
                Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
                  "Rpc error: %s" (Error.to_string_mach e) ;
                Hash_set.add peers_tried peer ;
                None
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
            !"None of the peers I asked knew; trying more" ;
          if ctr > retry_max then Deferred.unit
          else
            let%bind () = Clock.after retry_interval in
            answer_query (ctr + 1) peers_tried query
    in
    Linear_pipe.iter_unordered ~max_concurrency:8 query_reader
      ~f:(answer_query 0 (Peer.Hash_set.of_list []))
    |> don't_wait_for
end
