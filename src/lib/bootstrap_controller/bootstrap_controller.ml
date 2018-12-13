open Core
open Async
open Protocols.Coda_pow
open Coda_base
open Pipe_lib.Strict_pipe

module type Inputs_intf = sig
  module Consensus_mechanism : Consensus.Mechanism.S

  module External_transition :
    External_transition_intf
    with type protocol_state := Consensus_mechanism.Protocol_state.value

  module Merkle_address : Merkle_address.S

  module Syncable_ledger :
    Syncable_ledger.S
    with type addr := Merkle_address.t
     and type hash := Ledger_hash.t
     and type root_hash := Frozen_ledger_hash.t
     and type merkle_tree := Ledger.t

  module Staged_ledger : Staged_ledger_intf with type ledger := Ledger.t

  module Transition_frontier :
    Transition_frontier_intf
    with type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type ledger_database := Ledger.Db.t
     and type ledger := Ledger.t
     and type staged_ledger := Staged_ledger.t
end

module type S = sig
  module Inputs : Inputs_intf

  open Inputs

  type t

  val create : unit -> t

  val result : t -> (Ledger.t * External_transition.t) Deferred.t
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs

  type get_ancestor =
       Ancestor.Input.t
    -> (Consensus_mechanism.Protocol_state.value * Ancestor.Proof.t) option
       Deferred.Or_error.t

  type state_with_root =
    { state: Consensus_mechanism.Protocol_state.value
    ; root: Consensus_mechanism.Protocol_state.value }

  type t =
    { syncable_ledger: Syncable_ledger.t
    ; logger: Logger.t
    ; ancestor_prover: Ancestor.Prover.t
    ; mutable best_with_root: state_with_root
    ; get_ancestor: get_ancestor }

  let isn't_worth_getting_root t candidate time_received =
    match
      Consensus_mechanism.select ~logger:t.logger
        ~existing:
          (Consensus_mechanism.Protocol_state.consensus_state
             t.best_with_root.state)
        ~candidate:
          (Consensus_mechanism.Protocol_state.consensus_state candidate)
        ~time_received
    with
    | `Keep -> true
    | `Take -> false

  let received_bad_proof t e =
    (* TODO: Punish *)
    Logger.faulty_peer t.logger !"Bad ancestor proof: %{sexp:Error.t}" e

  let done_syncing_root t =
    Option.is_some (Syncable_ledger.peek_valid_tree t.syncable_ledger)

  let length protocol_state =
    Consensus_mechanism.Protocol_state.consensus_state protocol_state
    |> Consensus_mechanism.Consensus_state.length |> Coda_numbers.Length.to_int

  let on_transition t ~ledger_hash_table (transition, time_received) =
    let module Ps = Consensus_mechanism.Protocol_state in
    let candidate = External_transition.protocol_state transition in
    if isn't_worth_getting_root t candidate time_received then Deferred.unit
    else
      let previous_state_hash = Ps.previous_state_hash candidate in
      (* TODO: This may be an off by one *)
      let input : Ancestor.Input.t =
        { descendant= previous_state_hash
        ; generations= length t.best_with_root.root }
      in
      let rec get_root () =
        let%bind res = t.get_ancestor input in
        if
          done_syncing_root t
          || isn't_worth_getting_root t candidate time_received
        then Deferred.unit
        else
          match res with
          | Error e ->
              Logger.error t.logger !"%{sexp:Error.t}" e ;
              get_root ()
          | Ok None ->
              Logger.info t.logger "Peer did not have root. Re-requesting." ;
              get_root ()
          | Ok (Some (ancestor, proof)) -> (
              let ancestor_length =
                Ps.(Consensus_state.length (consensus_state ancestor))
              in
              match
                Ancestor.Prover.verify_and_add t.ancestor_prover input
                  (Ps.hash ancestor) proof ~ancestor_length
              with
              | Ok () ->
                  t.best_with_root <- {state= candidate; root= ancestor} ;
                  let candidate_body_hash = Ps.Body.hash (Ps.body candidate) in
                  let candidate_hash =
                    Protocol_state.hash ~hash_body:Fn.id
                      {body= candidate_body_hash; previous_state_hash}
                  in
                  Ancestor.Prover.add t.ancestor_prover ~hash:candidate_hash
                    ~prev_hash:previous_state_hash
                    ~length:
                      Ps.(Consensus_state.length (consensus_state candidate))
                    ~body_hash:candidate_body_hash ;
                  let frozen_ledger_hash =
                    Consensus_mechanism.(
                      Protocol_state.blockchain_state ancestor
                      |> Blockchain_state.ledger_hash)
                  in
                  ( match
                      Syncable_ledger.new_goal t.syncable_ledger
                        frozen_ledger_hash
                    with
                  | `Ignore -> ()
                  | `Continue ->
                      Ledger_hash.Table.set ledger_hash_table
                        ~key:
                          (Frozen_ledger_hash.to_ledger_hash frozen_ledger_hash)
                        ~data:candidate_hash ) ;
                  Deferred.unit
              | Error e -> received_bad_proof t e ; get_root () )
      in
      get_root ()

  let should_bootstrap root_state new_state =
    let new_length = length new_state in
    let root_length = length root_state in
    new_length - root_length
    > (2 * Transition_frontier.max_length) + Consensus.Mechanism.network_delay

  let is_bootstrapping pipes =
    Debug_assert.debug_assert (fun () ->
        if List.exists pipes ~f:Closed_writer.is_closed then
          assert (List.for_all pipes ~f:Closed_writer.is_closed) ) ;
    Closed_writer.is_closed (List.hd_exn pipes)

  let setup_bootstrap ~ledger_hash_table ~pipes ~frontier t (transition, tm) =
    List.iter pipes ~f:Closed_writer.toggle ;
    Transition_frontier.clear_paths frontier ;
    don't_wait_for (on_transition t ~ledger_hash_table (transition, tm)) ;
    let%map tree = Syncable_ledger.valid_tree t.syncable_ledger in
    let root_hash = Ledger.merkle_root tree in
    let state_hash = Hashtbl.find_exn ledger_hash_table root_hash in
    Transition_frontier.rebuild frontier tree state_hash ;
    Hashtbl.clear ledger_hash_table

  let create ~parent_log ~frontier ~get_ancestor ~ancestor_prover =
    let logger = Logger.child parent_log __MODULE__ in
    let initial_breadcrumb = Transition_frontier.root frontier in
    let initial_root_state =
      initial_breadcrumb |> Transition_frontier.Breadcrumb.transition_with_hash
      |> With_hash.data |> External_transition.protocol_state
    in
    let ledger =
      Transition_frontier.Breadcrumb.staged_ledger initial_breadcrumb
      |> Staged_ledger.ledger
    in
    { get_ancestor
    ; logger
    ; ancestor_prover
    ; best_with_root= {state= initial_root_state; root= initial_root_state}
    ; syncable_ledger= Syncable_ledger.create ledger ~parent_log:logger }

  let run pipes ~parent_log ~get_ancestor ~ancestor_prover ~frontier
      ~transition_reader =
    let t = create ~parent_log ~frontier ~get_ancestor ~ancestor_prover in
    let ledger_hash_table = Ledger_hash.Table.create () in
    Reader.iter transition_reader
      ~f:(fun (`Transition incoming_transition, `Time_received tm) ->
        let new_transition = Envelope.Incoming.data incoming_transition in
        let root_transition =
          Transition_frontier.root frontier
          |> Transition_frontier.Breadcrumb.transition_with_hash
          |> With_hash.data
        in
        let root_state = External_transition.protocol_state root_transition in
        let new_state = External_transition.protocol_state new_transition in
        if should_bootstrap root_state new_state then
          don't_wait_for
            ( if is_bootstrapping pipes then
              on_transition t ~ledger_hash_table (new_transition, tm)
            else
              setup_bootstrap t ~ledger_hash_table ~pipes ~frontier
                (new_transition, tm) ) ;
        Deferred.unit )
    |> don't_wait_for
end
