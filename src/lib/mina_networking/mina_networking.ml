open Core
open Async
open Mina_base
open Mina_stdlib
module Sync_ledger = Mina_ledger.Sync_ledger
open Network_peer
open Network_pool
open Pipe_lib

exception No_initial_peers

type Structured_log_events.t +=
  | Gossip_new_state of { state_hash : State_hash.t }
  [@@deriving register_event { msg = "Broadcasting new state over gossip net" }]

type Structured_log_events.t +=
  | Gossip_transaction_pool_diff of
      { fee_payer_summaries : User_command.fee_payer_summary_t list }
  [@@deriving
    register_event
      { msg =
          "Broadcasting transaction pool diff $fee_payer_summaries over gossip \
           net"
      }]

type Structured_log_events.t +=
  | Gossip_snark_pool_diff of { work : Snark_pool.Resource_pool.Diff.compact }
  [@@deriving
    register_event { msg = "Broadcasting snark pool diff over gossip net" }]

module type CONTEXT = sig
  val logger : Logger.t

  val trust_system : Trust_system.t

  val time_controller : Block_time.Controller.t

  val consensus_local_state : Consensus.Data.Local_state.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val compile_config : Mina_compile_config.t
end

module Node_status = Node_status
module Rpcs = Rpcs
module Sinks = Sinks
module Gossip_net = Gossip_net.Make (Rpcs)

module Config = struct
  type log_gossip_heard =
    { snark_pool_diff : bool; transaction_pool_diff : bool; new_state : bool }
  [@@deriving make]

  type t =
    { genesis_ledger_hash : Ledger_hash.t
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

let create (module Context : CONTEXT) (config : Config.t) ~sinks
    ~(get_transition_frontier : unit -> Transition_frontier.t option)
    ~(get_node_status : unit -> Node_status.t Deferred.Or_error.t) =
  let open Context in
  let gossip_net_ref = ref None in
  let module Rpc_context = struct
    include Context

    let list_peers () =
      match !gossip_net_ref with
      | None ->
          (* should be unreachable; without a network, we wouldn't receive this RPC call *)
          [%log error] "Network not instantiated when initial peers requested" ;
          return []
      | Some gossip_net ->
          Gossip_net.Any.peers gossip_net

    let get_transition_frontier = get_transition_frontier
  end in
  let%map gossip_net =
    O1trace.thread "gossip_net" (fun () ->
        Gossip_net.Any.create config.creatable_gossip_net
          (module Rpc_context)
          (Gossip_net.Message.Any_sinks ((module Sinks), sinks)) )
  in
  gossip_net_ref := Some gossip_net ;
  (* The node status RPC is implemented directly in go, serving a string which
     is periodically updated. This is so that one can make this RPC on a node even
     if that node is at its connection limit. *)
  Clock.every' (Time.Span.of_min 1.) (fun () ->
      O1trace.thread "update_node_status" (fun () ->
          match%bind get_node_status () with
          | Error _ ->
              Deferred.unit
          | Ok data ->
              Gossip_net.Any.set_node_status gossip_net
                (Node_status.to_yojson data |> Yojson.Safe.to_string)
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
  { gossip_net; logger; trust_system }

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
        match Node_status.of_yojson (Yojson.Safe.from_string s) with
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

let get_node_status_from_peers (t : t)
    (addrs : Mina_net2.Multiaddr.t list option) =
  let run = Deferred.List.map ~how:`Parallel ~f:(get_peer_node_status t) in
  match addrs with
  | None ->
      peers t >>= run
  | Some addrs -> (
      match Option.all (List.map ~f:Mina_net2.Multiaddr.to_peer addrs) with
      | Some peers ->
          run peers
      | None ->
          Deferred.return
            (List.map addrs ~f:(fun _ ->
                 Or_error.error_string
                   "Could not parse peers in node status request" ) ) )

(* TODO: Have better pushback behavior *)
let broadcast_state t state =
  [%str_log' trace t.logger]
    (Gossip_new_state
       { state_hash = State_hash.With_state_hashes.state_hash state } ) ;
  Mina_metrics.(Gauge.inc_one Network.new_state_broadcasted) ;
  Gossip_net.Any.broadcast_state t.gossip_net (With_hash.data state)

let broadcast_transaction_pool_diff ?nonce t diff =
  [%str_log' trace t.logger]
    (Gossip_transaction_pool_diff
       { fee_payer_summaries = List.map ~f:User_command.fee_payer_summary diff }
    ) ;
  Mina_metrics.(Gauge.inc_one Network.transaction_pool_diff_broadcasted) ;
  Gossip_net.Any.broadcast_transaction_pool_diff ?nonce t.gossip_net diff

let broadcast_snark_pool_diff ?nonce t diff =
  Mina_metrics.(Gauge.inc_one Network.snark_pool_diff_broadcasted) ;
  [%str_log' trace t.logger]
    (Gossip_snark_pool_diff
       { work = Option.value_exn (Snark_pool.Resource_pool.Diff.to_compact diff)
       } ) ;
  Gossip_net.Any.broadcast_snark_pool_diff ?nonce t.gossip_net diff

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
