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
     and type external_transition_verified := External_transition.Verified.t
     and type ledger_database := Ledger.Db.t
     and type masked_ledger := Ledger.Mask.Attached.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type ledger_diff_verified := Staged_ledger_diff.Verified.t
     and type staged_ledger := Staged_ledger.t

  module Merkle_address : Merkle_address.S

  module Syncable_ledger :
    Syncable_ledger.S
    with type addr := Merkle_address.t
     and type hash := Ledger_hash.t
     and type root_hash := Ledger_hash.t
     and type merkle_tree := Ledger.Db.t
     and type account := Account.t
     and type merkle_path := Ledger.path

  module Network :
    Network_intf
    with type peer := Kademlia.Peer.t
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type ancestor_proof_input := State_hash.t * int
     and type ancestor_proof := Ancestor.Proof.t
     and type protocol_state := Consensus.Mechanism.Protocol_state.value
end

module Make (Inputs : Inputs_intf) :
  Bootstrap_controller_intf
  with type network := Inputs.Network.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type external_transition := Inputs.External_transition.t
   and type ancestor_prover := Ancestor.Prover.t
   and type ledger_db := Ledger.Db.t = struct
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

  (* Cache represents a graph. The key is a State_hash, which is the node in 
  the graph, and the value is the children transitions of the node *)
  module Transition_cache = struct
    type t = External_transition.t list State_hash.Table.t

    let create () = State_hash.Table.create ()

    let add (t : t) ~parent new_child =
      State_hash.Table.update t parent ~f:(function
        | None -> [new_child]
        | Some children ->
            if List.mem children new_child ~equal:External_transition.equal
            then children
            else new_child :: children )
  end

  let worth_getting_root t candidate time_received =
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

  let on_transition t ~sender (transition, time_received) =
    let module Protocol_state = Consensus.Mechanism.Protocol_state in
    let candidate = External_transition.protocol_state transition in
    let previous_state_hash = Protocol_state.previous_state_hash candidate in
    let input : Ancestor.Input.t =
      { descendant= previous_state_hash
      ; generations= length candidate - length t.best_with_root.root }
    in
    if
      done_syncing_root t
      || (not @@ worth_getting_root t candidate time_received)
    then Deferred.unit
    else
      match%map
        Network.get_ancestry t.network sender
          (input.descendant, input.generations)
      with
      | Error e ->
          Logger.error t.logger
            !"Could not get the proof of ancestors from the \
              network:%{sexp:Error.t}"
            e
      | Ok (ancestor, proof) -> (
          let ancestor_length =
            Protocol_state.(Consensus_state.length (consensus_state ancestor))
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
              Syncable_ledger.new_goal t.syncable_ledger ledger_hash |> ignore
          | Error e -> received_bad_proof t e )

  (* TODO: We need to do catchup jobs for all remaining transitions in the cache. 
           This will be hooked into `run` when we do this. #1326 *)
  let _expand_root ~frontier root_hash cache =
    let rec dfs state_hash =
      Option.iter (Hashtbl.find_and_remove cache state_hash)
        ~f:(fun children ->
          List.iter children ~f:(fun transition ->
              Transition_frontier.add_transition_exn frontier transition
              |> ignore ;
              dfs (With_hash.hash transition) ) )
    in
    dfs root_hash

  let sync_ledger t ~transition_graph ~transition_reader =
    Reader.iter transition_reader
      ~f:(fun (`Transition incoming_transition, `Time_received time_received)
         ->
        let transition = Envelope.Incoming.data incoming_transition in
        let sender = (Envelope.Incoming.sender incoming_transition, 0) in
        let protocol_state = External_transition.protocol_state transition in
        let previous_state_hash =
          External_transition.Protocol_state.previous_state_hash protocol_state
        in
        Transition_cache.add transition_graph ~parent:previous_state_hash
          transition ;
        (* TODO: Efficiently limiting the number of green threads in #1337 *)
        if worth_getting_root t protocol_state time_received then
          on_transition t ~sender (transition, time_received) |> don't_wait_for ;
        Deferred.unit )
    |> don't_wait_for ;
    Syncable_ledger.valid_tree t.syncable_ledger

  (* TODO: Assume that the transitions we are getting are verified from the network #1334 *)
  let run ~parent_log ~network ~ancestor_prover ~frontier ~ledger_db
      ~transition_reader =
    let logger = Logger.child parent_log __MODULE__ in
    let initial_breadcrumb = Transition_frontier.root frontier in
    let initial_root_state =
      initial_breadcrumb |> Transition_frontier.Breadcrumb.transition_with_hash
      |> With_hash.data |> External_transition.forget
      |> External_transition.protocol_state
    in
    let t =
      { network
      ; logger
      ; ancestor_prover
      ; best_with_root= {state= initial_root_state; root= initial_root_state}
      ; syncable_ledger= Syncable_ledger.create ledger_db ~parent_log:logger }
    in
    let transition_graph = Transition_cache.create () in
    Transition_frontier.clear_paths frontier ;
    (* TODO: We will use this variable for building a new reference for transition_frontier #1323 *)
    let%map _ledger_db = sync_ledger t ~transition_graph ~transition_reader in
    let protocol_state = t.best_with_root.root in
    let root_hash = External_transition.Protocol_state.hash protocol_state in
    Transition_frontier.rebuild frontier root_hash
end
