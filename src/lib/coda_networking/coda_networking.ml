open Core_kernel
open Async
open Kademlia
open Coda_base

module type Sync_ledger_intf = sig
  type query [@@deriving bin_io]

  type answer [@@deriving bin_io]
end

module Rpcs (Inputs : sig
  module Ledger_builder_aux_hash :
    Protocols.Coda_pow.Ledger_builder_aux_hash_intf

  module Ledger_builder_aux : Binable.S

  module Ledger_hash : Protocols.Coda_pow.Ledger_hash_intf

  module Ledger_builder_hash :
    Protocols.Coda_pow.Ledger_builder_hash_intf
    with type ledger_builder_aux_hash := Ledger_builder_aux_hash.t
     and type ledger_hash := Ledger_hash.t

  module Blockchain_state : Blockchain_state.S

  module Protocol_state : sig
    type value [@@deriving bin_io]

    val equal_value : value -> value -> bool

    val hash : value -> State_hash.t

    val blockchain_state : value -> Blockchain_state.value
  end

  module Sync_ledger : Sync_ledger_intf
end) =
struct
  open Inputs

  module Get_ledger_builder_aux_at_hash = struct
    module T = struct
      let name = "get_ledger_builder_aux_at_hash"

      module T = struct
        type query = Ledger_builder_hash.t

        type response = (Ledger_builder_aux.t * Ledger_hash.t) option
      end

      module Caller = T
      module Callee = T
    end

    include T.T
    include Versioned_rpc.Both_convert.Plain.Make (T)

    module V1 = struct
      module T = struct
        type query = Ledger_builder_hash.t [@@deriving bin_io]

        type response = (Ledger_builder_aux.t * Ledger_hash.t) option
        [@@deriving bin_io]

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

      module T = struct
        type query = Ledger_hash.t * Sync_ledger.query [@@deriving bin_io]

        type response = (Ledger_hash.t * Sync_ledger.answer) Or_error.t
        [@@deriving bin_io]
      end

      module Caller = T
      module Callee = T
    end

    include T.T
    include Versioned_rpc.Both_convert.Plain.Make (T)

    module V1 = struct
      module T = struct
        include T.T

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
  module Snark_pool_diff : sig
    type t [@@deriving bin_io, sexp]
  end

  module Transaction_pool_diff : sig
    type t [@@deriving bin_io, sexp]
  end

  module External_transition : sig
    type t [@@deriving bin_io, sexp]
  end
end) =
struct
  open Inputs

  module T = struct
    module T = struct
      type msg =
        | New_state of External_transition.t
        | Snark_pool_diff of Snark_pool_diff.t
        | Transaction_pool_diff of Transaction_pool_diff.t
      [@@deriving sexp, bin_io]
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
  module External_transition : sig
    type t [@@deriving sexp, bin_io]

    val timestamp : t -> Block_time.t
  end

  module Ledger_builder_aux_hash :
    Protocols.Coda_pow.Ledger_builder_aux_hash_intf

  module Ledger_hash : Protocols.Coda_pow.Ledger_hash_intf

  module Ledger_builder_hash :
    Protocols.Coda_pow.Ledger_builder_hash_intf
    with type ledger_builder_aux_hash := Ledger_builder_aux_hash.t
     and type ledger_hash := Ledger_hash.t

  module Blockchain_state : Coda_base.Blockchain_state.S

  module Protocol_state : sig
    type value [@@deriving bin_io]

    val equal_value : value -> value -> bool

    val hash : value -> State_hash.t

    val blockchain_state : value -> Blockchain_state.value
  end

  module Sync_ledger : Sync_ledger_intf

  module Ledger_builder_aux : sig
    type t [@@deriving bin_io]

    val hash : t -> Ledger_builder_aux_hash.t
  end

  module Snark_pool_diff : sig
    type t [@@deriving sexp, bin_io]
  end

  module Transaction_pool_diff : sig
    type t [@@deriving sexp, bin_io]
  end
end

module type Config_intf = sig
  type gossip_config

  type t = {parent_log: Logger.t; gossip_net_params: gossip_config}
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  module Message = Message (Inputs)
  module Gossip_net = Gossip_net.Make (Message)
  module Peer = Peer

  module Config : Config_intf with type gossip_config := Gossip_net.Config.t =
  struct
    type t = {parent_log: Logger.t; gossip_net_params: Gossip_net.Config.t}
  end

  module Rpcs = Rpcs (Inputs)
  module Membership = Membership.Haskell

  type t =
    { gossip_net: Gossip_net.t
    ; log: Logger.t
    ; states: (External_transition.t * Unix_timestamp.t) Linear_pipe.Reader.t
    ; transaction_pool_diffs: Transaction_pool_diff.t Linear_pipe.Reader.t
    ; snark_pool_diffs: Snark_pool_diff.t Linear_pipe.Reader.t }
  [@@deriving fields]

  let create (config : Config.t)
      ~(get_ledger_builder_aux_at_hash :
            Ledger_builder_hash.t
         -> (Ledger_builder_aux.t * Ledger_hash.t) option Deferred.t)
      ~(answer_sync_ledger_query :
            Ledger_hash.t * Sync_ledger.query
         -> (Ledger_hash.t * Sync_ledger.answer) Deferred.Or_error.t) =
    let log = Logger.child config.parent_log "coda networking" in
    let get_ledger_builder_aux_at_hash_rpc () ~version:_ hash =
      get_ledger_builder_aux_at_hash hash
    in
    let answer_sync_ledger_query_rpc () ~version:_ query =
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
      Gossip_net.create config.gossip_net_params implementations
    in
    (* TODO: Think about buffering:
       I.e., what do we do when too many messages are coming in, or going out.
       For example, some things you really want to not drop (like your outgoing
       block announcment).
    *)
    let states, snark_pool_diffs, transaction_pool_diffs =
      Linear_pipe.partition_map3 (Gossip_net.received gossip_net) ~f:(fun x ->
          match x with
          | New_state s ->
              Perf_histograms.add_span ~name:"external_transition_latency"
                (Time.abs_diff (Time.now ())
                   (External_transition.timestamp s |> Block_time.to_time)) ;
              `Fst
                ( s
                , Time.now () |> Time.to_span_since_epoch |> Time.Span.to_ms
                  |> Unix_timestamp.of_float )
          | Snark_pool_diff d -> `Snd d
          | Transaction_pool_diff d -> `Trd d )
    in
    {gossip_net; log; states; snark_pool_diffs; transaction_pool_diffs}

  (* TODO: Have better pushback behavior *)
  let broadcast t x =
    Logger.trace t.log !"Broadcasting %{sexp: Message.msg} over gossip net" x ;
    Linear_pipe.write_without_pushback (Gossip_net.broadcast t.gossip_net) x

  let broadcast_state t x = broadcast t (New_state x)

  let broadcast_transaction_pool_diff t x =
    broadcast t (Transaction_pool_diff x)

  let broadcast_snark_pool_diff t x = broadcast t (Snark_pool_diff x)

  let peers t = Gossip_net.peers t.gossip_net

  module Ledger_builder_io = struct
    type nonrec t = t

    let create = Fn.id

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

    let get_ledger_builder_aux_at_hash t ledger_builder_hash =
      let peers = Gossip_net.random_peers t.gossip_net 8 in
      Logger.trace t.log
        !"Get_aux querying the following peers %{sexp: Peer.t list}"
        peers ;
      find_map' peers ~f:(fun peer ->
          Logger.trace t.log
            !"Asking %{sexp: Peer.t} query regarding ledger_builder_hash \
              %{sexp: Ledger_builder_hash.t}"
            peer ledger_builder_hash ;
          match%map
            Gossip_net.query_peer t.gossip_net peer
              Rpcs.Get_ledger_builder_aux_at_hash.dispatch_multi
              ledger_builder_hash
          with
          | Ok (Some (ledger_builder_aux, ledger_builder_aux_merkle_sibling))
            ->
              let implied_ledger_builder_hash =
                Ledger_builder_hash.of_aux_and_ledger_hash
                  (Ledger_builder_aux.hash ledger_builder_aux)
                  ledger_builder_aux_merkle_sibling
              in
              if
                Ledger_builder_hash.equal implied_ledger_builder_hash
                  ledger_builder_hash
              then (
                Logger.trace t.log
                  !"%{sexp: Peer.t} sent contents resulting in a good \
                    Ledger_builder_hash %{sexp: Ledger_builder_hash.t}"
                  peer ledger_builder_hash ;
                Ok ledger_builder_aux )
              else (
                Logger.faulty_peer t.log
                  !"%{sexp: Peer.t} sent contents resulting in a bad \
                    Ledger_builder_hash %{sexp: Ledger_builder_hash.t}, we \
                    wanted %{sexp: Ledger_builder_hash.t}"
                  peer implied_ledger_builder_hash ledger_builder_hash ;
                Or_error.error_string "Evil! TODO: Punish" )
          | Ok None ->
              Logger.trace t.log
                !"%{sexp: Peer.t} didn't find a ledger_builder_aux at \
                  ledger_builder_hash %{sexp: Ledger_builder_hash.t}"
                peer ledger_builder_hash ;
              Or_error.error_string "no ledger builder aux found"
          | Error err ->
              Logger.warn t.log
                !"Ledger_builder_aux acquisition hit network error %s"
                (Error.to_string_mach err) ;
              Error err )

    (* TODO: Check whether responses are good or not. *)
    let glue_sync_ledger t query_reader response_writer =
      (* We attempt to query 3 random peers, retry_max times. We keep track
      of the peers that couldn't answer a particular query and won't try them
      again. *)
      let retry_max = 6 in
      let retry_interval = Time.Span.of_ms 200. in
      let rec answer_query ctr peers_tried query =
        let peers =
          Gossip_net.random_peers_except t.gossip_net 3 ~except:peers_tried
        in
        Logger.trace t.log
          !"SL: Querying the following peers %{sexp: Peer.t list}"
          peers ;
        match%bind
          find_map peers ~f:(fun peer ->
              Logger.trace t.log
                !"Asking %{sexp: Peer.t} query regarding ledger_hash %{sexp: \
                  Ledger_hash.t}"
                peer (fst query) ;
              match%map
                Gossip_net.query_peer t.gossip_net peer
                  Rpcs.Answer_sync_ledger_query.dispatch_multi query
              with
              | Ok (Ok answer) ->
                  Logger.trace t.log
                    !"Received answer from peer %{sexp: Peer.t} on \
                      ledger_hash %{sexp: Ledger_hash.t}"
                    peer (fst answer) ;
                  Some answer
              | Ok (Error e) ->
                  Logger.info t.log "Rpc error: %s" (Error.to_string_mach e) ;
                  Hash_set.add peers_tried peer ;
                  None
              | Error err ->
                  Logger.warn t.log "Network error: %s"
                    (Error.to_string_mach err) ;
                  None )
        with
        | Some answer ->
            Logger.trace t.log
              !"Succeeding with answer on ledger_hash %{sexp: Ledger_hash.t}"
              (fst answer) ;
            (* TODO *)
            Linear_pipe.write_if_open response_writer answer
        | None ->
            Logger.info t.log !"None of the peers I asked knew; trying more" ;
            if ctr > retry_max then Deferred.unit
            else
              let%bind () = Clock.after retry_interval in
              answer_query (ctr + 1) peers_tried query
      in
      Linear_pipe.iter_unordered ~max_concurrency:8 query_reader
        ~f:(answer_query 0 (Peer.Hash_set.of_list []))
      |> don't_wait_for
  end
end
