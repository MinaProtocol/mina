open Core_kernel
open Async_kernel
open O1trace

module Make (Inputs : sig
  include Inputs.Synchronizing.S

  module Transition_logic_state :
    Transition_logic_state_intf.S
    with type tip := Tip.t
     and type consensus_local_state := Consensus_mechanism.Local_state.t
     and type external_transition := Consensus_mechanism.External_transition.t
     and type state_hash := State_hash.t
     and type public_key_compressed := Public_key.Compressed.t
end) =
struct
  open Inputs
  open Consensus_mechanism
  module Ops = Tip_ops.Make (Inputs)
  open Ops

  let ledger_hash_of_transition t =
    External_transition.protocol_state t
    |> Protocol_state.blockchain_state |> Blockchain_state.ledger_hash

  let ledger_builder_hash_of_transition t =
    External_transition.protocol_state t
    |> Protocol_state.blockchain_state |> Blockchain_state.ledger_builder_hash

  type t = {net: Net.t; log: Logger.t; sl_ref: Sync_ledger.t option ref}

  let create ~net ~parent_log =
    {net; log= Logger.child parent_log __MODULE__; sl_ref= ref None}

  (* Perform the `Sync interruptible work *)
  let do_sync {net; log; sl_ref} ~(old_state : Transition_logic_state.t)
      ~(state_mutator :
            Transition_logic_state.t
         -> Transition_logic_state.Change.t list
         -> External_transition.t
         -> unit Deferred.t) transition_with_hash =
    let {With_hash.data= locked_tip; hash= _} =
      Transition_logic_state.locked_tip old_state
    in
    let {With_hash.data= transition; hash= transition_state_hash} =
      transition_with_hash
    in
    let snarked_ledger_hash = ledger_hash_of_transition transition in
    let build_lb ~aux ~ledger =
      let open Interruptible.Let_syntax in
      match%bind
        Interruptible.uninterruptible
          (Ledger_builder.of_aux_and_ledger ~snarked_ledger_hash ~ledger ~aux)
      with
      (* TODO: We'll need the full history in order to trust that
               the ledger builder we get is actually valid. See #285 *)
      | Ok lb ->
          Option.iter !sl_ref ~f:Sync_ledger.destroy ;
          sl_ref := None ;
          let new_tree =
            Transition_logic_state.Transition_tree.singleton
              transition_with_hash
          in
          let new_tip =
            { With_hash.data= Tip.of_transition_and_lb transition lb
            ; hash= transition_state_hash }
          in
          assert_materialization_of new_tip transition_with_hash ;
          Logger.debug log
            !"Successfully caught up to full ledger-builder %{sexp: \
              Ledger_builder_hash.t}"
            (Ledger_builder.hash lb) ;
          let open Transition_logic_state.Change in
          Interruptible.uninterruptible
            (state_mutator old_state
               [Ktree new_tree; Locked_tip new_tip; Longest_branch_tip new_tip]
               (With_hash.data transition_with_hash))
      | Error e ->
          Logger.faulty_peer log "Malicious aux data received from net %s"
            (Error.to_string_hum e) ;
          Interruptible.return ()
    in
    let h =
      Ledger_builder_hash.ledger_hash
        (ledger_builder_hash_of_transition transition)
    in
    (* Lazily recreate the sync_ledger if necessary *)
    let sl : Sync_ledger.t =
      match !sl_ref with
      | None ->
          trace_task "sync ledger" (fun () ->
              let ledger =
                Ledger_builder.ledger locked_tip.ledger_builder |> Ledger.copy
              in
              let sl = Sync_ledger.create ledger ~parent_log:log in
              Net.glue_sync_ledger net
                (Sync_ledger.query_reader sl)
                (Sync_ledger.answer_writer sl) ;
              sl_ref := Some sl ;
              sl )
      | Some sl -> sl
    in
    let ivar : (External_transition.t, State_hash.t) With_hash.t Ivar.t =
      Ivar.create ()
    in
    Logger.debug log
      !"Attempting to catchup to ledger-hash %{sexp: Ledger_hash.t}"
      h ;
    let work =
      let open Interruptible.Let_syntax in
      match%bind
        Interruptible.lift (Sync_ledger.fetch sl h)
          (Deferred.map (Ivar.read ivar) ~f:ignore)
      with
      | `Ok ledger ->
          Logger.debug log
            !"Successfully caught up to ledger %{sexp: Ledger_hash.t}"
            h ;
          (* TODO: This should be parallelized with the syncing *)
          trace_task "net aux" (fun () ->
              match%bind
                Interruptible.uninterruptible
                  (Net.get_ledger_builder_aux_at_hash net
                     (ledger_builder_hash_of_transition transition))
              with
              | Ok aux -> build_lb ~aux ~ledger
              | Error e ->
                  Logger.faulty_peer log "Network failed to send aux %s"
                    (Error.to_string_hum e) ;
                  return () )
      | `Target_changed (old_target, new_target) ->
          Logger.debug log
            !"Existing sync-ledger target_changed from %{sexp: Ledger_hash.t \
              option} to %{sexp: Ledger_hash.t}"
            old_target new_target ;
          return ()
    in
    (work, ivar)

  let sync (t : t) ~(old_state : Transition_logic_state.t) ~state_mutator
      transition_with_hash =
    Job.create transition_with_hash ~f:(do_sync ~old_state ~state_mutator t)
end
