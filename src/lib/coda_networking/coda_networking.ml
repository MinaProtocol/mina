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
    module Stable : sig
      module V1 : Binable.S
    end
  end

  module Ledger_hash : Protocols.Coda_pow.Ledger_hash_intf

  module Blockchain_state : Blockchain_state.S

  module External_transition : External_transition.S
end) =
struct
  open Inputs

  (* see

     RFC 0012, and

     https://ocaml.janestreet.com/ocaml-core/latest/doc/async_rpc_kernel/Async_rpc_kernel/Versioned_rpc/

  *)

  module Get_staged_ledger_aux_at_hash = struct
    module T = struct
      let name = "get_staged_ledger_aux_at_hash"

      module T = struct
        (* "master" types, do not change *)
        type query =
          Staged_ledger_hash.Stable.V1.t Envelope.Incoming.Stable.V1.t

        type response = (Staged_ledger_aux.Stable.V1.t * Ledger_hash.t) option
      end

      module Caller = T
      module Callee = T
    end

    include T.T
    module M = Versioned_rpc.Both_convert.Plain.Make (T)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include T
    end)

    module V1 = struct
      module T = struct
        type query =
          Staged_ledger_hash.Stable.V1.t Envelope.Incoming.Stable.V1.t
        [@@deriving bin_io]

        type response =
          (Staged_ledger_aux.Stable.V1.t * Ledger_hash.Stable.V1.t) option
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
        (* "master" types, do not change *)
        type query =
          (Ledger_hash.Stable.V1.t * Sync_ledger.Query.Stable.V1.t)
          Envelope.Incoming.Stable.V1.t

        type response =
          (Ledger_hash.Stable.V1.t * Sync_ledger.Answer.Stable.V1.t) Or_error.t
      end

      module Caller = T
      module Callee = T
    end

    include T.T
    module M = Versioned_rpc.Both_convert.Plain.Make (T)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include T
    end)

    module V1 = struct
      module T = struct
        type query =
          (Ledger_hash.Stable.V1.t * Sync_ledger.Query.Stable.V1.t)
          Envelope.Incoming.Stable.V1.t
        [@@deriving bin_io, sexp]

        type response =
          (Ledger_hash.Stable.V1.t * Sync_ledger.Answer.Stable.V1.t) Or_error.t
        [@@deriving bin_io, sexp]

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

  module Transition_catchup = struct
    module T = struct
      let name = "transition_catchup"

      module T = struct
        (* "master" types, do not change *)
        type query = State_hash.Stable.V1.t Envelope.Incoming.Stable.V1.t

        type response =
          External_transition.Stable.V1.t Non_empty_list.Stable.V1.t option
      end

      module Caller = T
      module Callee = T
    end

    include T.T
    module M = Versioned_rpc.Both_convert.Plain.Make (T)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include T
    end)

    module V1 = struct
      module T = struct
        type query = State_hash.Stable.V1.t Envelope.Incoming.Stable.V1.t
        [@@deriving bin_io, sexp]

        type response =
          External_transition.Stable.V1.t Non_empty_list.Stable.V1.t option
        [@@deriving bin_io, sexp]

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

  module Get_ancestry = struct
    module T = struct
      let name = "get_ancestry"

      module T = struct
        (* "master" types, do not change *)
        type query =
          Consensus.Consensus_state.Value.t Envelope.Incoming.Stable.V1.t
        [@@deriving sexp]

        type response =
          ( ( External_transition.Stable.V1.t
            , State_body_hash.t list * External_transition.t )
            Proof_carrying_data.t
          * Staged_ledger_aux.Stable.V1.t
          * Ledger_hash.Stable.V1.t )
          option
      end

      module Caller = T
      module Callee = T
    end

    include T.T
    module M = Versioned_rpc.Both_convert.Plain.Make (T)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include T
    end)

    module V1 = struct
      module T = struct
        type query =
          Consensus.Consensus_state.Value.Stable.V1.t
          Envelope.Incoming.Stable.V1.t
        [@@deriving bin_io, sexp]

        type response =
          ( ( External_transition.Stable.V1.t
            , State_body_hash.t list * External_transition.Stable.V1.t )
            Proof_carrying_data.t
          * Staged_ledger_aux.Stable.V1.t
          * Ledger_hash.Stable.V1.t )
          option
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
end

module Message (Inputs : sig
  module Snark_pool_diff : sig
    type t [@@deriving bin_io, sexp]
  end

  module Transaction_pool_diff : sig
    type t [@@deriving bin_io, sexp]
  end

  module External_transition : External_transition.S
end) =
struct
  open Inputs

  module T = struct
    module T = struct
      (* "master" types, do not change *)
      type content =
        | New_state of External_transition.Stable.V1.t
        | Snark_pool_diff of Snark_pool_diff.t
        | Transaction_pool_diff of Transaction_pool_diff.t
      [@@deriving bin_io, sexp]

      type msg = content Envelope.Incoming.Stable.V1.t [@@deriving sexp]
    end

    let name = "message"

    module Caller = T
    module Callee = T
  end

  include T.T

  let content ({data; _} : msg) = data

  let sender ({sender; _} : msg) = sender

  include Versioned_rpc.Both_convert.One_way.Make (T)

  module V1 = struct
    module T = struct
      type content = T.T.content [@@deriving bin_io, sexp]

      type msg = content Envelope.Incoming.Stable.V1.t
      [@@deriving bin_io, sexp]

      let version = 1

      let callee_model_of_msg = Fn.id

      let msg_of_caller_model = Fn.id
    end

    include Register (T)
  end
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
          type t [@@deriving bin_io]
        end
      end
      with type V1.t = t

    val hash : t -> Staged_ledger_aux_hash.t
  end

  module Snark_pool_diff : sig
    type t [@@deriving sexp, bin_io]
  end

  module Transaction_pool_diff : sig
    type t [@@deriving sexp, bin_io]
  end

  module Time : Protocols.Coda_pow.Time_intf
end

module type Config_intf = sig
  type gossip_config

  type time_controller

  type t =
    { parent_log: Logger.t
    ; gossip_net_params: gossip_config
    ; time_controller: time_controller }
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
      { parent_log: Logger.t
      ; gossip_net_params: Gossip_net.Config.t
      ; time_controller: Time.Controller.t }
  end

  module Rpcs = Rpcs (Inputs)
  module Membership = Membership.Haskell

  type t =
    { gossip_net: Gossip_net.t
    ; log: Logger.t
    ; states:
        (External_transition.t Envelope.Incoming.t * Time.t)
        Strict_pipe.Reader.t
    ; transaction_pool_diffs:
        Transaction_pool_diff.t Envelope.Incoming.t Linear_pipe.Reader.t
    ; snark_pool_diffs:
        Snark_pool_diff.t Envelope.Incoming.t Linear_pipe.Reader.t }
  [@@deriving fields]

  let create (config : Config.t)
      ~(get_staged_ledger_aux_at_hash :
            Staged_ledger_hash.t Envelope.Incoming.t
         -> (Staged_ledger_aux.Stable.V1.t * Ledger_hash.t) option Deferred.t)
      ~(answer_sync_ledger_query :
            (Ledger_hash.t * Ledger.Location.Addr.t Syncable_ledger.Query.t)
            Envelope.Incoming.t
         -> (Ledger_hash.t * Sync_ledger.Answer.t) Deferred.Or_error.t)
      ~(transition_catchup :
            State_hash.t Envelope.Incoming.t
         -> External_transition.t Non_empty_list.t option Deferred.t)
      ~(get_ancestry :
            Consensus.Consensus_state.Value.t Envelope.Incoming.t
         -> ( ( External_transition.t
              , State_body_hash.t list * External_transition.t )
              Proof_carrying_data.t
            * Staged_ledger_aux.t
            * Ledger_hash.t )
            Deferred.Option.t) =
    let log = Logger.child config.parent_log "coda networking" in
    (* TODO: for following functions, could check that IP in _conn matches
       the sender IP in envelope, punish if mismatch due to IP forgery
    *)
    let get_staged_ledger_aux_at_hash_rpc _conn ~version:_ hash_in_envelope =
      get_staged_ledger_aux_at_hash hash_in_envelope
    in
    let answer_sync_ledger_query_rpc _conn ~version:_ query_in_envelope =
      answer_sync_ledger_query query_in_envelope
    in
    let transition_catchup_rpc _conn ~version:_ hash_in_envelope =
      Logger.info log
        !"Peer %{sexp:Envelope.Sender.t} sent transition_catchup"
        (Envelope.Incoming.sender hash_in_envelope) ;
      transition_catchup hash_in_envelope
    in
    let get_ancestry_rpc _conn ~version:_ query_in_envelope =
      Logger.info log
        !"Sending root proof to peer %{sexp:Envelope.Sender.t}"
        (Envelope.Incoming.sender query_in_envelope) ;
      get_ancestry query_in_envelope
    in
    let implementations =
      List.concat
        [ Rpcs.Get_staged_ledger_aux_at_hash.implement_multi
            get_staged_ledger_aux_at_hash_rpc
        ; Rpcs.Answer_sync_ledger_query.implement_multi
            answer_sync_ledger_query_rpc
        ; Rpcs.Transition_catchup.implement_multi transition_catchup_rpc
        ; Rpcs.Get_ancestry.implement_multi get_ancestry_rpc ]
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
      Strict_pipe.Reader.partition_map3 (Gossip_net.received gossip_net)
        ~f:(fun x ->
          match Envelope.Incoming.data x with
          | New_state s ->
              Perf_histograms.add_span ~name:"external_transition_latency"
                (Core.Time.abs_diff (Core.Time.now ())
                   (External_transition.timestamp s |> Block_time.to_time)) ;
              `Fst
                ( Envelope.Incoming.map x ~f:(fun _ -> s)
                , Time.now config.time_controller )
          | Snark_pool_diff d -> `Snd (Envelope.Incoming.map x ~f:(fun _ -> d))
          | Transaction_pool_diff d ->
              `Trd (Envelope.Incoming.map x ~f:(fun _ -> d)) )
    in
    { gossip_net
    ; log
    ; states
    ; snark_pool_diffs= Strict_pipe.Reader.to_linear_pipe snark_pool_diffs
    ; transaction_pool_diffs=
        Strict_pipe.Reader.to_linear_pipe transaction_pool_diffs }

  (* wrap data in envelope, with "me" in the gossip net as the sender *)
  let envelope_from_me t data =
    let me = (gossip_net t).me in
    (* this envelope is remote me, because we're sending it over the network *)
    Envelope.Incoming.wrap ~data ~sender:(Envelope.Sender.Remote me)

  (* TODO: Have better pushback behavior *)
  let broadcast t x =
    Logger.trace t.log !"Broadcasting %{sexp: Message.msg} over gossip net" x ;
    Linear_pipe.write_without_pushback (Gossip_net.broadcast t.gossip_net) x

  let broadcast_from_me t content = broadcast t (envelope_from_me t content)

  let broadcast_state t x = broadcast_from_me t (Message.New_state x)

  let broadcast_transaction_pool_diff t x =
    broadcast_from_me t (Message.Transaction_pool_diff x)

  let broadcast_snark_pool_diff t x =
    broadcast_from_me t (Message.Snark_pool_diff x)

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

  let random_peers {gossip_net; _} = Gossip_net.random_peers gossip_net

  let random_peers_except {gossip_net; _} n ~(except : Peer.Hash_set.t) =
    Gossip_net.random_peers_except gossip_net n ~except

  let catchup_transition t peer state_hash =
    Gossip_net.query_peer t.gossip_net peer
      Rpcs.Transition_catchup.dispatch_multi
      (envelope_from_me t state_hash)

  let get_ancestry_non_preferred_peers t input peers =
    let max_current_peers = 8 in
    let rec loop peers num_peers =
      if num_peers > max_current_peers then
        return
          (Or_error.errorf
             !"None of randomly-chosen peers has a more preferred consensus \
               state than %{sexp:Rpcs.Get_ancestry.query}"
             input)
      else
        let current_peers, remaining_peers = List.split_n peers num_peers in
        find_map' current_peers ~f:(fun peer ->
            let%bind ancestors_or_error =
              Gossip_net.query_peer t.gossip_net peer
                Rpcs.Get_ancestry.dispatch_multi input
            in
            match ancestors_or_error with
            | Ok (Some ancestors) -> return (Ok ancestors)
            | Ok None ->
                Logger.info t.log
                  !"get_ancestry returned no root for non-preferred peer \
                    %{sexp: Peer.t} on consensus_state %{sexp: \
                    Rpcs.Get_ancestry.query}"
                  peer input ;
                loop remaining_peers (2 * num_peers)
            | Error e ->
                Logger.warn t.log
                  !"get_ancestry generated error for non-preferred peer \
                    %{sexp: Peer.t}: %{sexp: Error.t}"
                  peer e ;
                loop remaining_peers (2 * num_peers) )
    in
    loop peers 1

  let get_ancestry t preferred_peer input =
    O1trace.trace_recurring_task "get_ancestry" (fun () ->
        let input_in_envelope = envelope_from_me t input in
        (* try preferred_peer first *)
        let%bind ancestors_or_error =
          Gossip_net.query_peer t.gossip_net preferred_peer
            Rpcs.Get_ancestry.dispatch_multi input_in_envelope
        in
        let get_random_peers () =
          let max_peers = 15 in
          (* 1 + 2 + 4 + 8 *)
          let except = Peer.Hash_set.of_list [preferred_peer] in
          random_peers_except t max_peers ~except
        in
        match ancestors_or_error with
        | Ok (Some ancestors) -> return (Ok ancestors)
        | Ok None ->
            (* #TODO: punish *)
            Logger.faulty_peer t.log
              !"get_ancestry returned no ancestors for the transition sender \
                %{sexp: Peer.t}, trying non-preferred peers"
              preferred_peer ;
            let peers = get_random_peers () in
            get_ancestry_non_preferred_peers t input_in_envelope peers
        | Error e ->
            Logger.warn t.log
              !"get_ancestry generated error for the transition sender \
                %{sexp: Peer.t}: %{sexp: Error.t}; trying non-preferred peers"
              preferred_peer e ;
            let peers = get_random_peers () in
            get_ancestry_non_preferred_peers t input_in_envelope peers )

  (* TODO: Check whether responses are good or not. *)
  let glue_sync_ledger t query_reader response_writer =
    (* We attempt to query 3 random peers, retry_max times. We keep track
       of the peers that couldn't answer a particular query and won't try them
       again. *)
    let retry_max = 6 in
    let retry_interval = Core.Time.Span.of_ms 200. in
    let rec answer_query ctr peers_tried query =
      O1trace.trace_event "ask sync ledger query" ;
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
                Rpcs.Answer_sync_ledger_query.dispatch_multi
                (envelope_from_me t query)
            with
            | Ok (Ok answer) ->
                Logger.trace t.log
                  !"Received answer from peer %{sexp: Peer.t} on ledger_hash \
                    %{sexp: Ledger_hash.t}"
                  peer (fst answer) ;
                Some
                  (Envelope.Incoming.wrap ~data:answer
                     ~sender:(Envelope.Sender.Remote peer))
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
            (fst answer.data) ;
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
