open Core
open Async
open Protocols.Coda_pow
open Coda_base
open Pipe_lib.Strict_pipe

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier :
    Transition_frontier_intf
    with type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type ledger_database := Ledger.Db.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type ledger := Ledger.t

  module Merkle_address : Merkle_address.S

  module Syncable_ledger :
    Syncable_ledger.S
    with type addr := Merkle_address.t
     and type hash := Ledger_hash.t
     and type root_hash := Ledger_hash.t
     and type merkle_tree := Ledger.t
     and type account := Account.t
     and type merkle_path := Ledger.path

  module Network :
    Network_intf
    with type peer := Kademlia.Peer.t
     and type state_hash := State_hash.t
     and type transition := External_transition.t
     and type ancestor_proof_input := State_hash.t * int
     and type ancestor_proof := Ancestor.Proof.t
     and type protocol_state := Consensus.Mechanism.Protocol_state.value
end

module Make (Inputs : Inputs_intf) :
  Bootstrap_controller_intf
  with type network := Inputs.Network.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type external_transition := Inputs.External_transition.t
   and type ancestor_prover := Ancestor.Prover.t = struct
  open Inputs

  type state_with_root =
    { state: Consensus.Mechanism.Protocol_state.value
    ; root: Consensus.Mechanism.Protocol_state.value }

  type t =
    { syncable_ledger: Syncable_ledger.t
    ; logger: Logger.t
    ; ancestor_prover: Ancestor.Prover.t
    ; mutable best_with_root: state_with_root
    ; network: Network.t }

  let isn't_worth_getting_root t candidate time_received =
    `Keep
    = Consensus.Mechanism.select ~logger:t.logger
        ~existing:
          (Consensus.Mechanism.Protocol_state.consensus_state
             t.best_with_root.state)
        ~candidate:
          (Consensus.Mechanism.Protocol_state.consensus_state candidate)
        ~time_received

  let received_bad_proof t e =
    (* TODO: Punish *)
    Logger.faulty_peer t.logger !"Bad ancestor proof: %{sexp:Error.t}" e

  let done_syncing_root t =
    Option.is_some (Syncable_ledger.peek_valid_tree t.syncable_ledger)

  let length protocol_state =
    Consensus.Mechanism.Protocol_state.consensus_state protocol_state
    |> Consensus.Mechanism.Consensus_state.length |> Coda_numbers.Length.to_int

  let on_transition t ~ledger_hash_table (transition, time_received) =
    let module Protocol_state = Consensus.Mechanism.Protocol_state in
    let candidate = External_transition.protocol_state transition in
    if isn't_worth_getting_root t candidate time_received then Deferred.unit
    else
      let previous_state_hash = Protocol_state.previous_state_hash candidate in
      (* TODO: This may be an off by one *)
      let input : Ancestor.Input.t =
        { descendant= previous_state_hash
        ; generations= length t.best_with_root.root }
      in
      let rec get_root () =
        let%bind res =
          Network.get_ancestry t.network (input.descendant, input.generations)
        in
        if
          done_syncing_root t
          || isn't_worth_getting_root t candidate time_received
        then Deferred.unit
        else
          match res with
          | Error e ->
              Logger.error t.logger
                !"Could not get the proof of ancestors from the \
                  network:%{sexp:Error.t}"
                e ;
              get_root ()
          | Ok (ancestor, proof) -> (
              let ancestor_length =
                Protocol_state.(
                  Consensus_state.length (consensus_state ancestor))
              in
              match
                Ancestor.Prover.verify_and_add t.ancestor_prover input
                  (Protocol_state.hash ancestor)
                  proof ~ancestor_length
              with
              | Ok () ->
                  t.best_with_root <- {state= candidate; root= ancestor} ;
                  let candidate_body_hash =
                    Protocol_state.Body.hash (Protocol_state.body candidate)
                  in
                  let candidate_hash = Protocol_state.hash candidate in
                  Ancestor.Prover.add t.ancestor_prover ~hash:candidate_hash
                    ~prev_hash:previous_state_hash
                    ~length:
                      Protocol_state.(
                        Consensus_state.length (consensus_state candidate))
                    ~body_hash:candidate_body_hash ;
                  let ledger_hash =
                    Consensus.Mechanism.(
                      Protocol_state.blockchain_state ancestor
                      |> Blockchain_state.ledger_hash
                      |> Frozen_ledger_hash.to_ledger_hash)
                  in
                  ( match
                      Syncable_ledger.new_goal t.syncable_ledger ledger_hash
                    with
                  | `Ignore -> ()
                  | `Continue ->
                      Ledger_hash.Table.set ledger_hash_table ~key:ledger_hash
                        ~data:candidate_hash ) ;
                  Deferred.unit
              | Error e -> received_bad_proof t e ; get_root () )
      in
      get_root ()

  let setup_bootstrap ~ledger_hash_table ~toggle_pipes ~frontier t
      (transition, tm) =
    toggle_pipes () ;
    Transition_frontier.clear_paths frontier ;
    don't_wait_for (on_transition t ~ledger_hash_table (transition, tm)) ;
    let%map tree = Syncable_ledger.valid_tree t.syncable_ledger in
    let root_hash = Ledger.merkle_root tree in
    let state_hash = Hashtbl.find_exn ledger_hash_table root_hash in
    Transition_frontier.rebuild frontier tree state_hash ;
    Hashtbl.clear ledger_hash_table ;
    toggle_pipes ()

  let create ~parent_log ~frontier ~network ~ancestor_prover =
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
    { network
    ; logger
    ; ancestor_prover
    ; best_with_root= {state= initial_root_state; root= initial_root_state}
    ; syncable_ledger= Syncable_ledger.create ledger ~parent_log:logger }

  let run ~valid_transition_writer ~processed_transition_writer
      ~catchup_job_writer ~catchup_breadcrumbs_writer ~parent_log ~network
      ~ancestor_prover ~frontier ~transition_reader =
    let toggle_pipes () =
      Closed_writer.(
        toggle valid_transition_writer ;
        toggle processed_transition_writer ;
        toggle catchup_job_writer ;
        toggle catchup_breadcrumbs_writer)
    in
    let is_bootstrapping () =
      let are_pipes_closed =
        Closed_writer.(
          is_closed valid_transition_writer
          && is_closed processed_transition_writer
          && is_closed catchup_job_writer
          && is_closed catchup_breadcrumbs_writer)
      in
      Debug_assert.debug_assert (fun () ->
          assert (
            Closed_writer.(
              are_pipes_closed
              || not
                   ( is_closed valid_transition_writer
                   || is_closed processed_transition_writer
                   || is_closed catchup_job_writer
                   || is_closed catchup_breadcrumbs_writer )) ) ) ;
      are_pipes_closed
    in
    let t = create ~parent_log ~frontier ~network ~ancestor_prover in
    let ledger_hash_table = Ledger_hash.Table.create () in
    Reader.iter transition_reader
      ~f:(fun (`Transition incoming_transition, `Time_received tm) ->
        let new_transition = Envelope.Incoming.data incoming_transition in
        let root_transition =
          Transition_frontier.root frontier
          |> Transition_frontier.Breadcrumb.transition_with_hash
          |> With_hash.data
        in
        let open External_transition in
        let root_state = protocol_state root_transition in
        let new_state = protocol_state new_transition in
        if
          Consensus.Mechanism.should_bootstrap
            ~max_length:Transition_frontier.max_length
            ~existing:(Protocol_state.consensus_state root_state)
            ~candidate:(Protocol_state.consensus_state new_state)
        then
          don't_wait_for
            ( if is_bootstrapping () then
              on_transition t ~ledger_hash_table (new_transition, tm)
            else
              setup_bootstrap t ~ledger_hash_table ~toggle_pipes ~frontier
                (new_transition, tm) ) ;
        Deferred.unit )
    |> don't_wait_for
end
