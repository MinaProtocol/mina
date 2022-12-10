open Core_kernel
open Mina_base
open Bit_catchup_state
open Context

(** Extract header from a transition in [Transition_state.Verifying_blockchain_proof] state *)
let to_header_exn = function
  | Transition_state.Verifying_blockchain_proof { header; _ } ->
      header
  | _ ->
      failwith "to_header_exn: unexpected state"

module F = struct
  type processing_result = Mina_block.Validation.initial_valid_with_header

  let ignore_gossip = function
    | Transition_state.Verifying_blockchain_proof ({ gossip_data = gd; _ } as r)
      ->
        Gossip.drop_gossip_data `Ignore gd ;
        let gossip_data = Gossip.No_validation_callback in
        Transition_state.Verifying_blockchain_proof { r with gossip_data }
    | st ->
        st

  let to_data = function
    | Transition_state.Verifying_blockchain_proof { substate; baton; _ } ->
        Some Verifying_generic.{ substate; baton }
    | _ ->
        None

  let update Verifying_generic.{ substate; baton } = function
    | Transition_state.Verifying_blockchain_proof r ->
        Transition_state.Verifying_blockchain_proof { r with substate; baton }
    | st ->
        st

  let verify ~context:(module Context : CONTEXT) (module I : Interruptible.F)
      states =
    let headers = Mina_stdlib.Nonempty_list.map ~f:to_header_exn states in
    let header_list = Mina_stdlib.Nonempty_list.to_list headers in
    [%log' debug Context.logger] "verify_blockchain_proofs of $state_hashes"
      ~metadata:
        [ ( "state_hashes"
          , `List
              (List.map header_list
                 ~f:
                   (Fn.compose State_hash.to_yojson
                      state_hash_of_header_with_validation ) ) )
        ] ;
    ( Context.verify_blockchain_proofs (module I) header_list
    , Context.ancestry_verification_timeout )

  let data_name = "blockchain proof"

  (* TODO consider limiting amount of proofs per batch *)
  let split_to_batches = Mina_stdlib.Nonempty_list.singleton
end

include Verifying_generic.Make (F)

(** Promote a transition that is in [Received] state with
    [Processed] status to [Verifying_blockchain_proof] state.
*)
let promote_to ~context ~actions ~header ~transition_states ~substate:s
    ~gossip_data ~body_opt ~aux =
  let (module Context : CONTEXT) = context in
  let ctx =
    match header with
    | Gossip.Initial_valid h ->
        Substate.Done h
    | _ ->
        Substate.Dependent
  in
  let parent_hash =
    Gossip.header_with_hash_of_received_header header
    |> With_hash.data |> Mina_block.Header.protocol_state
    |> Mina_state.Protocol_state.previous_state_hash
  in
  ( if aux.Transition_state.received_via_gossip then
    let for_start =
      collect_dependent_and_pass_the_baton_by_hash ~logger:Context.logger
        ~transition_states ~dsu:Context.processed_dsu parent_hash
    in
    start ~context ~actions ~transition_states for_start ) ;
  Transition_state.Verifying_blockchain_proof
    { header = Gossip.pre_initial_valid_of_received_header header
    ; gossip_data
    ; body_opt
    ; substate = { s with Substate.status = Processing ctx }
    ; aux
    ; baton = false
    }

(** Mark the transition in [Verifying_blockchain_proof] processed.

   This function is called when a gossip for the transition is received.
   When gossip is received, blockchain proof is verified before any
   further processing. Hence blockchain verification for the transition
   may be skipped upon receival of a gossip.

   Blockhain proof verification is performed in batches, hence in progress
   context is not discarded but passed to the next ancestor that is in 
   [Verifying_blockchain_proof] and isn't [Processed].
*)
let make_processed ~context ~actions ~transition_states header =
  let (module Context : CONTEXT) = context in
  let state_hash = state_hash_of_header_with_validation header in
  Option.value ~default:()
  @@ let%map.Option for_restart =
       update_to_processing_done ~logger:Context.logger ~transition_states
         ~state_hash ~dsu:Context.processed_dsu ~reuse_ctx:true header
     in
     start ~context
       ~actions:(Async_kernel.Deferred.return actions)
       ~transition_states for_restart ;
     actions.Misc.mark_processed_and_promote [ state_hash ]
       ~reason:"gossip received"
