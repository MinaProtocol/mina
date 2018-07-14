open Core_kernel
open Async
open Kademlia

module type Sync_ledger_intf = sig
  type query [@@deriving bin_io]
  type response [@@deriving bin_io]
end

module Rpcs
    (Ledger_hash : Protocols.Minibit_pow.Ledger_hash_intf)
    (Sync_ledger : Sync_ledger_intf)
    (State : Binable.S) =
struct
  module Get_ledger_builder_aux_at_hash = struct
    module T = struct
      let name = "get_ledger_builder_aux_at_hash"

      module T = struct
        type query = Ledger_hash.t

        type response = State.t option
      end

      module Caller = T
      module Callee = T
    end

    include T.T
    include Versioned_rpc.Both_convert.Plain.Make (T)

    module V1 = struct
      module T = struct
        type query = Ledger_hash.t [@@deriving bin_io]

        type response = State.t option [@@deriving bin_io]

        let version = 1

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
    module T = struct
      let name = "answer_sync_ledger_query"

      module T = Sync_ledger

      module Caller = T
      module Callee = T
    end

    include T.T
    include Versioned_rpc.Both_convert.Plain.Make (T)

    module V1 = struct
      module T = struct
        include Sync_ledger

        let version = 1

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

module Message (State_with_witness : Minibit.State_with_witness_intf) = struct
  module T = struct
    module T = struct
      type msg = New_state of State_with_witness.Stripped.t
      [@@deriving bin_io]
    end

    let name = "message"

    module Caller = T
    module Callee = T
  end

  include T.T
  include Versioned_rpc.Both_convert.One_way.Make (T)

  module V1 = struct
    module T = struct
      include T.T

      let version = 1

      let callee_model_of_msg = Fn.id

      let msg_of_caller_model = Fn.id
    end

    include Register (T)
  end
end

module type Inputs_intf = sig
  module State_with_witness : Minibit.State_with_witness_intf

  module Ledger_hash : Protocols.Minibit_pow.Ledger_hash_intf

  module Sync_ledger : Sync_ledger_intf

  module State : Binable.S
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  module Message = Message (State_with_witness)
  module Gossip_net = Gossip_net.Make (Message)

  module Config = struct
    type t =
      { parent_log: Logger.t
      ; gossip_net_params: Gossip_net.Params.t
      ; initial_peers: Peer.t list
      ; me: Peer.t
      ; remap_addr_port: Peer.t -> Peer.t }
  end

  module Rpcs = Rpcs (Ledger_hash) (Sync_ledger) (State)
  module Membership = Membership.Haskell

  type t =
    { gossip_net: Gossip_net.t
    ; log: Logger.t
    ; new_state_reader: State_with_witness.Stripped.t Linear_pipe.Reader.t
    ; new_state_writer: State_with_witness.Stripped.t Linear_pipe.Writer.t }

  type state_with_witness = State_with_witness.t

  let init_gossip_net params initial_peers me log remap_addr_port
      implementations =
    let%map membership =
      match%map Membership.connect ~initial_peers ~me ~parent_log:log with
      | Ok membership -> membership
      | Error e ->
          failwith
            (Printf.sprintf "Failed to connect to kademlia process: %s\n"
               (Error.to_string_hum e))
    in
    let remap_ports peers =
      List.map peers ~f:(fun peer -> remap_addr_port peer)
    in
    let peer_events =
      Linear_pipe.map (Membership.changes membership) ~f:(function
        | Connect peers -> Peer.Event.Connect (remap_ports peers)
        | Disconnect peers -> Disconnect (remap_ports peers) )
    in
    Gossip_net.create peer_events params log implementations

  let create (config: Config.t) ~get_ledger_builder_aux_at_hash ~answer_sync_ledger_query =
    let log = Logger.child config.parent_log "minibit networking" in
    let get_ledger_builder_aux_at_hash_rpc () ~version hash =
      get_ledger_builder_aux_at_hash
    in
    let answer_sync_ledger_query_rpc () ~version query =
      answer_sync_ledger_query query
    in
    let implementations =
      List.append
        (Rpcs.Get_ledger_builder_aux_at_hash.implement_multi get_ledger_builder_aux_at_hash_rpc)
        (Rpcs.Answer_sync_ledger_query.implement_multi answer_sync_ledger_query_rpc)
    in
    let%map gossip_net =
      init_gossip_net config.gossip_net_params config.initial_peers config.me
        log config.remap_addr_port implementations
    in
    let new_state_reader, new_state_writer = Linear_pipe.create () in
    don't_wait_for
      (Linear_pipe.iter_unordered ~max_concurrency:64
           (Gossip_net.received gossip_net) ~f:(function New_state s ->
           Linear_pipe.write_or_drop new_state_writer new_state_reader
             ~capacity:1024 s ;
           Deferred.unit )) ;
    { gossip_net; log; new_state_reader; new_state_writer }

  module State_io = struct
    type net = t

    type t = unit

    let create net ~broadcast_state =
      don't_wait_for
        (Linear_pipe.iter_unordered ~max_concurrency:64
           (Linear_pipe.map broadcast_state ~f:State_with_witness.strip) ~f:
           (fun x ->
             Pipe.write (Gossip_net.broadcast net.gossip_net) (New_state x) )) ;
      ()

    (* TODO: Punish sources that send invalid transactions *)
    let new_states net t =
      Linear_pipe.map net.new_state_reader ~f:State_with_witness.check
  end

  module Ledger_builder_io = struct
    type nonrec t = t

    let create = Fn.id

    let par_find_map xs ~f =
      Deferred.create (fun ivar ->
        don't_wait_for
          (let%map () =
             Deferred.List.iter ~how:`Parallel xs ~f:(fun x ->
                 match%map f x with
                 | Some r -> Ivar.fill_if_empty ivar (Some r)
                 | None -> () )
           in
           Ivar.fill_if_empty ivar None))

    let get_ledger_builder_aux_at_hash t hash =
      let peers = Gossip_net.random_peers t.gossip_net 8 in
      par_find_map peers ~f:(fun peer ->
        match%map
          Gossip_net.query_peer t.gossip_net peer
            Rpcs.Get_ledger_builder_aux_at_hash.dispatch_multi hash
        with
        | Ok (Some ledger_builder_aux) -> Some ledger_builder_aux
        | Ok None -> Logger.info t.log "no ledger builder aux found"; None
        | Error err -> Logger.warn t.log "%s" (Error.to_string_mach err); None)

    let glue_sync_ledger t query_reader response_writer =
      let peers = Gossip_net.random_peers t.gossip_net 3 in
      Linear_pipe.iter_unordered ~max_concurrency:8 query_reader ~f:(fun query ->
        match%bind
          par_find_map peers ~f:(fun peer ->
            match%map
              Gossip_net.query_peer t.gossip_net peer
                Rpcs.Answer_sync_ledger_query.dispatch_multi query
            with
            | Ok answer -> Some answer
            | Error err -> Logger.warn t.log "%s" (Error.to_string_mach err); None)
        with
        | Some answer -> Linear_pipe.write response_writer answer
        | None -> Deferred.return ())
  end
end
