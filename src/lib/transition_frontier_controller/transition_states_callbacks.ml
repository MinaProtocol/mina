open Mina_base
open Core_kernel
open Async_kernel
open Bit_catchup_state

module Make (Context : sig
  val trust_system : Trust_system.t

  val logger : Logger.t

  val header_storage : Lmdb_storage.Header.t

  val block_storage : Lmdb_storage.Block.t

  val block_storage_actions : Bit_catchup_state.block_storage_actions

  val known_body_refs : Known_body_refs.t
end) =
struct
  open Context

  let on_invalid ?(reason = `Other) ~error ~aux ~body_ref meta =
    let f { Transition_state.sender; gossip_topic; _ } =
      let action =
        match reason with
        | `Other when Option.is_some gossip_topic ->
            Trust_system.Actions.Gossiped_invalid_transition
        | `Other ->
            Sent_invalid_transition
        | `Proof ->
            Sent_invalid_proof
        | `Signature_or_proof ->
            Sent_invalid_signature_or_proof
      in
      Trust_system.record_envelope_sender trust_system logger
        (Network_peer.Envelope.Sender.Remote sender)
        (action, Some (Error.to_string_hum error, []))
    in
    don't_wait_for (Deferred.List.iter ~f aux.Transition_state.received) ;
    let `Body_present has_body, `Removal_triggered removal_triggered =
      Known_body_refs.remove_reference ~logger ~block_storage known_body_refs
        body_ref meta.Substate.state_hash
    in
    if removal_triggered then block_storage_actions.remove_body [ body_ref ] ;
    Lmdb_storage.Header.(
      set header_storage meta.state_hash
      @@ Invalid
           { blockchain_length = meta.blockchain_length
           ; parent_state_hash = meta.parent_state_hash
           ; body_ref = Option.some_if has_body body_ref
           })

  let on_add_invalid meta =
    Lmdb_storage.Header.(
      set header_storage meta.Substate.state_hash
      @@ Invalid
           { blockchain_length = meta.blockchain_length
           ; parent_state_hash = meta.parent_state_hash
           ; body_ref = None
           })

  let on_add_new header_with_hash =
    let header = With_hash.data header_with_hash in
    let state_hash = State_hash.With_state_hashes.state_hash header_with_hash in
    let body_ref = Mina_block.Header.body_reference header in
    Known_body_refs.add_new ~logger known_body_refs body_ref state_hash ;
    Lmdb_storage.Header.(set header_storage state_hash @@ Header header) ;
    [%log info] "Adding transition $state_hash to bit-catchup state"
      ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ] ;
    Mina_metrics.Gauge.inc_one
      Mina_metrics.Transition_frontier_controller.transitions_being_processed

  let on_remove ~reason st =
    let meta = Transition_state.State_functions.transition_meta st in
    let name = Transition_state.State_functions.name st in
    [%log info] "Removing %s transition $state_hash from bit-catchup state" name
      ~metadata:[ ("state_hash", State_hash.to_yojson meta.state_hash) ] ;
    Mina_metrics.Gauge.dec_one
      Mina_metrics.Transition_frontier_controller.transitions_being_processed ;
    match reason with
    | `In_frontier ->
        ()
    | `Prunning ->
        let body_ref =
          Option.map
            ~f:(Fn.compose Mina_block.Header.body_reference With_hash.data)
            (Transition_state.header st)
        in
        let (`Removal_triggered removal_triggered) =
          Known_body_refs.prune ~logger ~block_storage ~header_storage
            known_body_refs ?body_ref meta.state_hash
        in
        Option.iter removal_triggered ~f:(fun body_ref ->
            block_storage_actions.remove_body [ body_ref ] )
end

let create_transition_states ~trust_system ~logger ~block_storage
    ~header_storage ~block_storage_actions ~known_body_refs =
  let module T = Make (struct
    let trust_system = trust_system

    let logger = logger

    let block_storage = block_storage

    let header_storage = header_storage

    let block_storage_actions = block_storage_actions

    let known_body_refs = known_body_refs
  end) in
  Transition_states.create_inmem (module T)
