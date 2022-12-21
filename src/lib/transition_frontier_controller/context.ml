open Mina_base
open Core_kernel
open Bit_catchup_state

type source_t = [ `Catchup | `Gossip | `Internal ]

type event_t =
  [ `Verified_header_relevance of
    ( unit
    , [ `Disconnected
      | `In_frontier of State_hash.t
      | `In_process of Transition_state.t ] )
    Result.t
    * Mina_block.Header.with_hash
    * Network_peer.Peer.t
  | `Pre_validate_header_invalid of
    Network_peer.Peer.t
    * Mina_block.Header.t
    * [ `Invalid_delta_block_chain_proof
      | `Invalid_genesis_protocol_state
      | `Invalid_protocol_version
      | `Mismatched_protocol_version ]
  | `Preserved_body_for_retrieved_ancestor of Mina_block.Body.t ]

module type MINI_CONTEXT = sig
  include Transition_handler.Validator.CONTEXT

  val conf_dir : string
end

module type CONTEXT = sig
  include MINI_CONTEXT

  val genesis_state_hash : State_hash.t

  val frontier : Transition_frontier.t

  val time_controller : Block_time.Controller.t

  (** Check is the body of a transition is present in the block storage, *)
  val check_body_in_storage :
    Consensus.Body_reference.t -> Staged_ledger_diff.Body.t option

  val building_breadcrumb_timeout : Core_kernel.Time.Span.t

  val ancestry_verification_timeout : Core_kernel.Time.Span.t

  val transaction_snark_verification_timeout : Core_kernel.Time.Span.t

  val bitwap_download_timeout : Core_kernel.Time.Span.t

  val peer_download_timeout : Core_kernel.Time.Span.t

  val ancestry_download_timeout : Core_kernel.Time.Span.t

  (** Download body for the given header  *)
  val download_body :
       header:Mina_block.Header.with_hash
    -> preferred_peers:Network_peer.Peer.t list
    -> (module Interruptible.F)
    -> Mina_block.Body.t Or_error.t Interruptible.t

  val allocate_bandwidth :
       ?priority:[ `Low | `Medium | `High ]
    -> [ `Verifier | `Download ]
    -> [ `Start_immediately | `Wait of unit Async_kernel.Ivar.t ]

  val deallocate_bandwidth : [ `Verifier | `Download ] -> unit

  (** Build breadcrumb for the given transition and its parent *)
  val build_breadcrumb :
       received_at:Time.t
    -> parent:Frontier_base.Breadcrumb.t
    -> transition:Mina_block.Validation.almost_valid_with_block
    -> (module Interruptible.F)
    -> ( Frontier_base.Breadcrumb.t
       , [> `Invalid of Error.t * [ `Proof | `Signature_or_proof | `Other ]
         | `Verifier_error of Error.t ] )
       Result.t
       Interruptible.t

  (** Retrieve some ancestors of target hash. Function returns a list of elements,
      each either header or block. List is sorted in parent-first order.

      Parent of the first element of the returned list is either in frontier
      or in transition states.

      Resulting list forms a chain of consequent headers/blocks with the last element
      corresponding to the target hash.

      This function attempts to retrieve header for target and some of its ancestors.
      It returns error if it wasn't able to retrieve any new information.
      It returns as soon as header of target is know. It won't try to retrieve all ancestors,
      however it will use batching to get as much information as possible in a fixed amount
      of RPC invocations. *)
  val retrieve_chain :
       some_ancestors:
         (* List of ancestors in parent-first order along with senders that shared them first *)
         (State_hash.t * Network_peer.Peer.t) list
    -> canopy:State_hash.t list
    -> target_hash:State_hash.t
    -> target_length:Mina_numbers.Length.t
    -> preferred_peers:Network_peer.Peer.t list
    -> lookup_transition:(State_hash.t -> [ `Present | `Not_present | `Invalid ])
    -> (* A function returning [`Present] if transition is either in frontier or in transition
          states, [`Invalid] if transition state is [Invalid] and [`Not_present] otherwise *)
       (module Interruptible.F)
    -> ( [ `Header of Mina_block.Header.with_hash
         | `Block of Mina_block.with_hash
         | `Meta of Substate.transition_meta ]
       * Network_peer.Peer.t )
       Mina_stdlib.Nonempty_list.t
       Or_error.t
       Interruptible.t

  (** Batch-verify a list of blockchain proofs *)
  val verify_blockchain_proofs :
       (module Interruptible.F)
    -> Mina_block.Validation.pre_initial_valid_with_header list
    -> ( Mina_block.Validation.initial_valid_with_header list
       , [> `Invalid_proof of Error.t | `Verifier_error of Error.t ] )
       Result.t
       Interruptible.t

  (** Batch-verify transaction snarks (complete works).
      
      Returns [Result.Error] when there was a failure, [Result.Ok true] if
      verification succeeded and [Result.Ok false] if verification
      finished with a negative result (one of works is invalid).
  *)
  val verify_transaction_proofs :
       (module Interruptible.F)
    -> (Ledger_proof.t * Sok_message.t) list
    -> unit Or_error.t Or_error.t Interruptible.t

  val processed_dsu : Processed_skipping.Dsu.t

  val record_event : event_t -> unit
end

let state_functions =
  (module Transition_state.State_functions : Substate.State_functions
    with type state_t = Transition_state.t )

let state_hash_of_header_with_validation hv =
  State_hash.With_state_hashes.state_hash
    (Mina_block.Validation.header_with_hash hv)

let state_hash_of_block_with_validation block =
  State_hash.With_state_hashes.state_hash
    (Mina_block.Validation.block_with_hash block)

(** [accept_gossip] takes validation callback and consensus state of a transition
    and accepts validation callback if a transition would be deemed relevant when
    received via gossip by another node and rejects the validation callback otherwise.
    *)
let accept_gossip ~context:(module Context : CONTEXT) ~valid_cb consensus_state
    =
  let now =
    let open Block_time in
    now Context.time_controller |> to_span_since_epoch |> Span.to_ms
  in
  match
    Consensus.Hooks.received_at_valid_time
      ~constants:Context.consensus_constants ~time_received:now consensus_state
  with
  | Ok () ->
      Mina_net2.Validation_callback.fire_if_not_already_fired valid_cb `Accept
  | Error _ ->
      Mina_net2.Validation_callback.fire_if_not_already_fired valid_cb `Reject

let interrupt_after_timeout ~timeout interrupt_ivar =
  Async_kernel.upon (Async.at timeout)
    (Async_kernel.Ivar.fill_if_empty interrupt_ivar)

let controlling_bandwidth ?priority ~resource
    ~context:(module Context : CONTEXT) ~transition_states ~actions ~upon_f
    ~process_f ~state_hash ~same_state_level (module I : Interruptible.F) =
  let mk_timeout span =
    let timeout = Time.(add @@ now ()) span in
    interrupt_after_timeout ~timeout I.interrupt_ivar ;
    timeout
  in
  let start_action ~need_deallocate action =
    Async_kernel.Deferred.(upon @@ both actions (I.force action)) (fun res ->
        if need_deallocate then Context.deallocate_bandwidth resource ;
        upon_f res )
  in
  let late_start = I.return (Result.Error `Late_to_start) in
  let ext_modifier st = function
    | { Substate_types.status =
          Processing (In_progress ({ processing_status = Waiting; _ } as ctx))
      ; _
      } as s
      when same_state_level st ->
        let action, timeout_span = process_f () in
        let timeout = mk_timeout timeout_span in
        let status =
          Substate_types.Processing
            (In_progress { ctx with processing_status = Executing { timeout } })
        in
        ({ s with status }, action)
    | subst ->
        (subst, late_start)
  in
  let build_after_state_update () =
    Transition_states.modify_substate transition_states state_hash
      ~f:{ ext_modifier }
  in
  match Context.allocate_bandwidth ?priority resource with
  | `Start_immediately ->
      let action, timeout_span = process_f () in
      start_action ~need_deallocate:true action ;
      Substate.Executing { timeout = mk_timeout timeout_span }
  | `Wait wait_ivar ->
      let action =
        let%bind.I.Deferred_let_syntax () = Async_kernel.Ivar.read wait_ivar in
        Option.value ~default:late_start (build_after_state_update ())
      in
      let handle_wait_ivar () =
        if Async_kernel.Ivar.is_full wait_ivar then
          Context.deallocate_bandwidth resource
        else Async_kernel.Ivar.fill wait_ivar ()
      in
      let action' = I.finally action ~f:handle_wait_ivar in
      start_action ~need_deallocate:false action' ;
      Substate.Waiting

module Body_ref_table = Hashtbl.Make (Consensus.Body_reference)
