
open Core_kernel
open Async
open Kademlia

module Rpcs (Ledger : Protocols.Minibit_pow.Ledger_intf) (Hash : Protocols.Minibit_pow.Hash_intf) = struct
  module Get_ledger_at_hash = struct
    module T = struct
      let name = "get_ledger_at_hash"
      module T = struct
        type query = Ledger.t Hash.t
        type response = Ledger.t option
      end
      module Caller = T
      module Callee = T
    end
    include T.T
    include Versioned_rpc.Both_convert.Plain.Make(T)

    module V1 = struct
      module T = struct
        type query = Ledger.t Hash.t [@@deriving bin_io]
        type response = Ledger.t option [@@deriving bin_io]
        let version = 1
        let query_of_caller_model = Fn.id
        let callee_model_of_query = Fn.id
        let response_of_callee_model = Fn.id
        let caller_model_of_response = Fn.id
      end
      include T
      include Register(T)
    end
  end

  module Check_ledger_at_hash = struct
    module T = struct
      let name = "check_ledger_at_hash"
      module T = struct
        type query = Ledger.t Hash.t
        type response = bool
      end
      module Caller = T
      module Callee = T
    end
    include T.T
    include Versioned_rpc.Both_convert.Plain.Make(T)

    module V1 = struct
      module T = struct
        type query = Ledger.t Hash.t [@@deriving bin_io]
        type response = bool [@@deriving bin_io]
        let version = 1
        let query_of_caller_model = Fn.id
        let callee_model_of_query = Fn.id
        let response_of_callee_model = Fn.id
        let caller_model_of_response = Fn.id
      end
      include T
      include Register(T)
    end
  end
end

module Message (State_with_witness : Minibit.State_with_witness_intf) = struct

  module T = struct
    module T = struct
      type msg =
        | New_state of State_with_witness.Stripped.t
      [@@deriving bin_io]
    end
    let name = "message"
    module Caller = T
    module Callee = T
  end
  include T.T
  include Versioned_rpc.Both_convert.One_way.Make(T)

  module V1 = struct
    module T = struct
      include T.T
      let version = 1
      let callee_model_of_msg = Fn.id
      let msg_of_caller_model = Fn.id
    end
    include Register(T)
  end
end

module Make
  (State_with_witness : Minibit.State_with_witness_intf)
  (Hash : Protocols.Minibit_pow.Hash_intf)
  (Ledger : Protocols.Minibit_pow.Ledger_intf)
= struct

  module Message = Message (State_with_witness)
  module Gossip_net = Gossip_net.Make (Message)

  module Config = struct
    type t = 
      { parent_log : Logger.t
      ; gossip_net_params : Gossip_net.Params.t
      ; initial_peers : Peer.t list
      ; me : Peer.t
      ; remap_addr_port : Peer.t -> Peer.t
      }
  end

  module Rpcs = Rpcs (Ledger) (Hash)

  module Membership = Membership.Haskell

  type t =
    { gossip_net : Gossip_net.t 
    ; new_state_reader : State_with_witness.Stripped.t Linear_pipe.Reader.t
    ; new_state_writer : State_with_witness.Stripped.t Linear_pipe.Writer.t }

  type ledger = Ledger.t
  type stripped_state_with_witness = State_with_witness.Stripped.t
  type 'a hash = 'a Hash.t


  let init_gossip_net 
    params
    initial_peers
    me
    log
    remap_addr_port
    implementations
    =
    let%map membership =
      match%map (Membership.connect ~initial_peers ~me ~parent_log:log) with
      | Ok membership -> membership
      | Error e -> failwith (Printf.sprintf "Failed to connect to kademlia process: %s\n" (Error.to_string_hum e))
    in
    let remap_ports peers = 
      List.map peers ~f:(fun peer -> remap_addr_port peer)
    in
    let peer_events = 
      (Linear_pipe.map 
         (Membership.changes membership) 
         ~f:(function
           | Connect peers -> Peer.Event.Connect (remap_ports peers)
           | Disconnect peers -> Disconnect (remap_ports peers)
         )) 
    in
    Gossip_net.create 
      peer_events
      params
      log
      implementations

  let create 
        (config : Config.t)
        check_ledger_at_hash 
        get_ledger_at_hash 
    = 
    let log = Logger.child config.parent_log "minibit networking" in
    let check_ledger_at_hash_rpc () ~version hash = check_ledger_at_hash hash in
    let get_ledger_at_hash_rpc () ~version hash = get_ledger_at_hash hash in
    let implementations = 
      List.append
        (Rpcs.Check_ledger_at_hash.implement_multi check_ledger_at_hash_rpc)
        (Rpcs.Get_ledger_at_hash.implement_multi get_ledger_at_hash_rpc)
    in
    let%map gossip_net = 
      init_gossip_net 
        config.gossip_net_params 
        config.initial_peers
        config.me 
        log 
        config.remap_addr_port 
        implementations
    in
    let new_state_reader, new_state_writer = Linear_pipe.create () in
    don't_wait_for begin
      Linear_pipe.iter_unordered 
        ~max_concurrency:64 
        (Gossip_net.received gossip_net)
        ~f:(function 
          | New_state s -> Linear_pipe.write_or_drop new_state_writer new_state_reader ~capacity:1024 s; Deferred.unit
        )
    end;
    { gossip_net
    ; new_state_reader
    ; new_state_writer }

  module State_io = struct
    type net = t
    type t = unit

    let create net ~broadcast_state = 
      don't_wait_for begin
        Linear_pipe.iter_unordered 
          ~max_concurrency:64 
          broadcast_state
          ~f:(fun x -> 
            Pipe.write 
              (Gossip_net.broadcast net.gossip_net) 
              (New_state x))
      end;
      ()

    let new_states net t = net.new_state_reader
  end

  module Ledger_fetcher_io = struct
    type net = t
    type t

    let get_ledger_at_hash net t hash = 
      let peers = Gossip_net.random_peers net.gossip_net 8 in
      let par_find_map xs ~f =
        Deferred.create
          (fun ivar -> 
             don't_wait_for begin
               let%map () = 
                 Deferred.List.iter
                   ~how:`Parallel
                   xs
                   ~f:(fun x -> 
                     let%map result = f x in
                     match result with 
                     | Some r -> Ivar.fill_if_empty ivar (Some r)
                     | None -> ()
                   )
               in
               Ivar.fill_if_empty ivar None
            end
          )
      in
      let%bind ledger_peer = 
        par_find_map
          peers
          ~f:(fun peer -> 
            match%map
              Gossip_net.query_peer 
                net.gossip_net 
                peer 
                Rpcs.Check_ledger_at_hash.dispatch_multi 
                hash 
            with
            | Ok true -> Some peer 
            | _ -> None
          )
      in
      match ledger_peer with
      | None -> Deferred.Or_error.error_string "no ledger peer found"
      | Some ledger_peer -> 
        let%bind ledger =
          Gossip_net.query_peer
            net.gossip_net
            ledger_peer
            Rpcs.Get_ledger_at_hash.dispatch_multi
            hash
        in
        match ledger with
        | Ok (Some ledger) -> Deferred.Or_error.return ledger
        | Ok None -> Deferred.Or_error.error_string "no ledger found"
        | Error s -> Deferred.Or_error.error_string (Error.to_string_hum s)
  end
end

