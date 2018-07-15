open Core_kernel
open Async
open Kademlia

module type Sync_ledger_intf = sig
  type query [@@deriving bin_io]

  type response [@@deriving bin_io]
end

module Rpcs
    (Ledger_builder_aux_hash : Protocols.Coda_pow.Ledger_builder_aux_hash_intf)
    (Sync_ledger : Sync_ledger_intf)
    (Ledger_builder_aux : Binable.S) =
struct
  module Get_ledger_builder_aux_at_hash = struct
    module T = struct
      let name = "get_ledger_builder_aux_at_hash"

      module T = struct
        type query = Ledger_builder_aux_hash.t

        type response = Ledger_builder_aux.t option
      end

      module Caller = T
      module Callee = T
    end

    include T.T
    include Versioned_rpc.Both_convert.Plain.Make (T)

    module V1 = struct
      module T = struct
        type query = Ledger_builder_aux_hash.t [@@deriving bin_io]

        type response = Ledger_builder_aux.t option [@@deriving bin_io]

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

module Message (Inputs : sig
    module Snark_pool_diff : Binable.S
    module Transaction_pool_diff : Binable.S
    module State_with_witness : Coda.State_with_witness_intf
  end)
= struct
  open Inputs
  module T = struct
    module T = struct
      type msg =
        | New_state of State_with_witness.Stripped.t
        | Snark_pool_diff of Snark_pool_diff.t
        | Transaction_pool_diff of Transaction_pool_diff.t
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
  module State_with_witness : Coda.State_with_witness_intf

  module Ledger_builder_aux_hash : Protocols.Coda_pow.Ledger_builder_aux_hash_intf

  module Sync_ledger : Sync_ledger_intf

  module Ledger_builder_aux : sig
    type t [@@deriving bin_io]
    val hash : t -> Ledger_builder_aux_hash.t
  end

  module Snark_pool_diff : Binable.S
  module Transaction_pool_diff : Binable.S
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  module Message = Message (Inputs)
  module Gossip_net = Gossip_net.Make (Message)

  module Config = struct
    type t =
      { parent_log: Logger.t
      ; gossip_net_params: Gossip_net.Params.t
      ; initial_peers: Peer.t list
      ; me: Peer.t
      ; remap_addr_port: Peer.t -> Peer.t }
  end

  module Rpcs = Rpcs (Ledger_builder_aux_hash) (Sync_ledger) (Ledger_builder_aux)
  module Membership = Membership.Haskell

  type t =
    { gossip_net: Gossip_net.t
    ; log: Logger.t
    ; new_states: State_with_witness.Stripped.t Linear_pipe.Reader.t
    ; transaction_pool_diffs: Transaction_pool_diff.t Linear_pipe.Reader.t
    ; snark_pool_diffs: Snark_pool_diff.t Linear_pipe.Reader.t
    }

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

  let create (config: Config.t) ~get_ledger_builder_aux_at_hash
      ~answer_sync_ledger_query =
    let log = Logger.child config.parent_log "minibit networking" in
    let get_ledger_builder_aux_at_hash_rpc () ~version hash =
      get_ledger_builder_aux_at_hash
    in
    let answer_sync_ledger_query_rpc () ~version query =
      answer_sync_ledger_query query
    in
    let implementations =
      List.append
        (Rpcs.Get_ledger_builder_aux_at_hash.implement_multi
           get_ledger_builder_aux_at_hash_rpc)
        (Rpcs.Answer_sync_ledger_query.implement_multi
           answer_sync_ledger_query_rpc)
    in
    let%map gossip_net =
      init_gossip_net config.gossip_net_params config.initial_peers config.me
        log config.remap_addr_port implementations
    in
    (* TODO: Think about buffering:
       I.e., what do we do when too many messages are coming in, or going out.
       For example, some things you really want to not drop (like your outgoing
       block announcment).
    *)
    let new_states, snark_pool_diffs, transaction_pool_diffs =
      Linear_pipe.partition_map3 (Gossip_net.received gossip_net) ~f:(function
        | New_state s -> `Fst s
        | Snark_pool_diff d -> `Snd d
        | Transaction_pool_diff d -> `Trd d)
    in
    {gossip_net; log; new_states; snark_pool_diffs; transaction_pool_diffs}

  (* TODO: Have better pushback behavior *)
  let broadcast t x =
    Linear_pipe.write_without_pushback (Gossip_net.broadcast t.gossip_net) x

  let broadcast_state t x = broadcast t (New_state x)
  let broadcast_transaction_pool_diff t x = broadcast t (Transaction_pool_diff x)
  let broadcast_snark_pool_diff t x = broadcast t (Snark_pool_diff x)

  (* TODO: Have better pushback behavior *)
  let broadcast_state t s =
    Linear_pipe.write_without_pushback
      (Gossip_net.broadcast t.gossip_net) (New_state s)

  module Ledger_builder_io = struct
    type nonrec t = t

    let create = Fn.id

    (* TODO: This is kinda inefficient *)
    let find_map xs ~f =
      let open Async in
      let ds = List.map xs ~f in
      let filter ~f =
        Deferred.bind ~f:(fun x ->
          if f x then return x else Deferred.never ())
      in
      let none_worked =
        Deferred.bind (Deferred.all ds) ~f:(fun ds ->
          if List.for_all ds ~f:Option.is_none
          then return None
          else Deferred.never ())
      in
      Deferred.any (none_worked :: List.map ~f:(filter ~f:Option.is_some) ds)

    let get_ledger_builder_aux_at_hash t hash =
      let peers = Gossip_net.random_peers t.gossip_net 8 in
      find_map peers ~f:(fun peer ->
        match%map
          Gossip_net.query_peer t.gossip_net peer
            Rpcs.Get_ledger_builder_aux_at_hash.dispatch_multi hash
        with
        | Ok (Some ledger_builder_aux) ->
          if Ledger_builder_aux_hash.equal
               (Ledger_builder_aux.hash ledger_builder_aux) hash
          then Some ledger_builder_aux
          else None
        | Ok None ->
            Logger.info t.log "no ledger builder aux found" ;
            None
        | Error err ->
            Logger.warn t.log "%s" (Error.to_string_mach err) ;
            None)

    (* TODO: Check whether responses are good or not. *)
    let glue_sync_ledger t query_reader response_writer =
      let peers = Gossip_net.random_peers t.gossip_net 3 in
      Linear_pipe.iter_unordered ~max_concurrency:8 query_reader ~f:
        (fun query ->
          match%bind
            find_map peers ~f:(fun peer ->
              match%map
                Gossip_net.query_peer t.gossip_net peer
                  Rpcs.Answer_sync_ledger_query.dispatch_multi query
              with
              | Ok answer -> Some answer
              | Error err ->
                  Logger.warn t.log "%s" (Error.to_string_mach err) ;
                  None )
          with
          | Some answer -> Linear_pipe.write response_writer answer
          | None -> Deferred.return () )
  end
end
