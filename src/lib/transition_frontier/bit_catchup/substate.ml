open Mina_base
open Core_kernel
include Substate_types

(** View the common substate.
    
    Viewer [~f] is applied to the common substate
    and its result is returned by the function.
  *)
let view (type state_t)
    ~state_functions:(module F : State_functions with type state_t = state_t) ~f
    =
  Fn.compose (Option.map ~f:snd)
    (F.modify_substate ~f:{ modifier = (fun st -> (st, f.viewer st)) })

(** [collect_states top_state] collects transitions from the top state (inclusive) down the ancestry chain 
  while:
  
    1. Condition [predicate] is held
    and
    2. Have same state level as [top_state]

    Returned list of states is in the parent-first order.
*)
let collect_states (type state_t) ~predicate ~state_functions
    ~(transition_states : state_t transition_states) top_state =
  let (Transition_states ((module Transition_states), transition_states)) =
    transition_states
  in
  let (module F : State_functions with type state_t = state_t) =
    state_functions
  in
  let open F in
  let full_predicate state =
    Option.value ~default:(`Take false, `Continue false)
    @@
    if equal_state_levels top_state state then None
    else view ~state_functions ~f:predicate state
  in
  let rec loop state res =
    let parent_hash = (transition_meta state).parent_state_hash in
    Option.value_map ~default:[]
      ~f:(fun parent_state ->
        if equal_state_levels parent_state state then
          let `Take to_take, `Continue to_continue = full_predicate state in
          let res' = if to_take then state :: res else res in
          if to_continue then loop parent_state res' else []
        else
          (* Parent is of different state => it's of higher state => we don't need to go deeper *)
          [] )
      (Transition_states.find transition_states parent_hash)
  in
  loop top_state []

(** Modify status of common substate to [Processed].
    
    Function returns [Result.Ok] with new modified common substate
    and [children] of the substate when substate has [Processing (Done x)] status
    and [Result.Error] otherwise.
*)
let mark_processed_modifier ~is_recursive_call old_st subst =
  let reshape res =
    match res with
    | Result.Error _ as e ->
        (subst, e)
    | Result.Ok (subst', children) ->
        (subst', Result.Ok (old_st, children))
  in
  let children =
    { subst.children with
      waiting_for_parent = State_hash.Set.empty
    ; processing_or_failed =
        State_hash.Set.union subst.children.processing_or_failed
          subst.children.waiting_for_parent
    }
  in
  reshape
  @@
  match subst.status with
  | Waiting_for_parent _ ->
      Result.Error (sprintf "waiting for parent")
  | Failed e ->
      Result.Error (sprintf "failed due to %s" (Error.to_string_mach e))
  | Processing (Done a_res) ->
      Result.Ok ({ status = Processed a_res; children }, subst.children)
  | Processing Dependent ->
      Result.Error "not started"
  | Processing (In_progress _) ->
      Result.Error "still processing"
  | Processed _ when is_recursive_call ->
      Result.Ok ({ subst with children }, subst.children)
  | Processed _ ->
      Result.Error "already processed"

(** Function takes transition and returns true when one of conditions hold:

      * Transition's parent is not in the catchup state (which means it's in frontier)
      * Transition's parent has a higher state level
    *)
let is_parent_of_higher_state (type state_t)
    ~state_functions:(module F : State_functions with type state_t = state_t)
    ~(transition_states : state_t transition_states) old_state =
  let (Transition_states ((module Transition_states), states)) =
    transition_states
  in
  let parent_hash = (F.transition_meta old_state).parent_state_hash in
  Option.value_map
    (Transition_states.find states parent_hash)
    ~f:
      (* Parent is found and differs in state level, hence it's of higher state *)
      (Fn.compose not (F.equal_state_levels old_state))
    ~default:
      (* Parent is not found which means the parent is in frontier.
         There is an invariant is that only non-processed states may have parent neither
         in frontier nor in transition_state. *)
      true

(** Start processing a transition in [Waiting_for_parent] status.
    
   Function modifies the status of the transition and then updates parent's children.
*)
let kickstart_waiting_for_parent (type state_t)
    ~state_functions:(module F : State_functions with type state_t = state_t)
    ~logger ~(transition_states : state_t transition_states) state_hash =
  let (Transition_states ((module Transition_states), states)) =
    transition_states
  in
  let ext_modifier old_st subst =
    match subst.status with
    | Waiting_for_parent mk_status ->
        ({ subst with status = mk_status () }, Some (F.transition_meta old_st))
    | _ ->
        (subst, None)
  in
  let update_children_modifier subst =
    ( { subst with
        children =
          { subst.children with
            waiting_for_parent =
              State_hash.Set.remove subst.children.waiting_for_parent state_hash
          ; processing_or_failed =
              State_hash.Set.add subst.children.processing_or_failed state_hash
          }
      }
    , () )
  in
  let modified_opt =
    Transition_states.modify_substate states ~f:{ ext_modifier } state_hash
  in
  match modified_opt with
  | None ->
      [%log warn] "child $state_hash not found"
        ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ]
  | Some None ->
      [%log warn] "child $state_hash is not in waiting_for_parent state"
        ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ]
  | Some (Some meta) ->
      Transition_states.modify_substate_ states meta.parent_state_hash
        ~f:{ modifier = update_children_modifier }

(** Update children of the parent upon transition aquiring the [Processed] status *)
let update_children_on_processed (type state_t)
    ~(transition_states : state_t transition_states) ~parent_hash
    ~state_functions:(module F : State_functions with type state_t = state_t)
    state_hash =
  let modifier subst =
    ( { subst with
        children =
          { subst.children with
            processed = State_hash.Set.add subst.children.processed state_hash
          ; processing_or_failed =
              State_hash.Set.remove subst.children.processing_or_failed
                state_hash
          }
      }
    , () )
  in
  let (Transition_states ((module Transition_states), states)) =
    transition_states
  in
  Transition_states.modify_substate_ states ~f:{ modifier } parent_hash

(** [mark_processed processed] marks a list of state hashes as Processed.

  It returns a list of state hashes to be promoted to higher state.
   
  Pre-conditions:
   1. Order of [processed] respects parent-child relationship and parent always comes first
   2. Respective substates for states from [processed] are in [Processing (Done _)] status

  Post-condition: list returned respects parent-child relationship and parent always comes first *)
let mark_processed (type state_t) ~logger ~state_functions
    ~(transition_states : state_t transition_states) processed =
  let (module F : State_functions with type state_t = state_t) =
    state_functions
  in
  let (Transition_states ((module Transition_states), states)) =
    transition_states
  in
  let processed_set = ref (State_hash.Set.of_list processed) in
  let rec handle is_recursive_call hash =
    Option.value ~default:[]
      (let open Option.Let_syntax in
      let%bind () =
        Option.some_if (State_hash.Set.mem !processed_set hash) ()
      in
      let ext_modifier old_st subst =
        mark_processed_modifier ~is_recursive_call old_st subst
      in
      let%bind res =
        Transition_states.modify_substate states ~f:{ ext_modifier } hash
      in
      processed_set := State_hash.Set.remove !processed_set hash ;
      Option.iter ~f:(fun err -> [%log warn] "error %s" err) (Result.error res) ;
      let%map old_state, children = Result.ok res in
      let meta = F.transition_meta old_state in
      let parent_hash = meta.parent_state_hash in
      update_children_on_processed ~transition_states ~state_functions
        ~parent_hash meta.state_hash ;
      State_hash.Set.iter children.waiting_for_parent
        ~f:
          (kickstart_waiting_for_parent ~state_functions ~logger
             ~transition_states ) ;
      if
        is_recursive_call
        || is_parent_of_higher_state ~state_functions ~transition_states
             old_state
      then
        let children =
          List.append (State_hash.Set.to_list children.processed)
          @@ State_hash.Set.to_list
          @@ State_hash.Set.inter children.processing_or_failed !processed_set
        in
        hash :: List.concat (List.map children ~f:(handle true))
      else [ hash ])
  in
  List.concat @@ List.map processed ~f:(handle false)

(** Update children of transition's parent when the transition is promoted
    to the higher state.

    This function removes the transition from parent's [Substate.processed] children
    set and adds it either to [Substate.waiting_for_parent] or
    [Substate.processing_or_failed] children set depending on the new status.

    When a transition's previous state was [Transition_state.Waiting_to_be_added_to_frontier],
    transition is not added to any of the parent's children sets.
*)
let update_children_on_promotion (type state_t) ~state_functions
    ~(transition_states : state_t transition_states) ~parent_hash ~state_hash
    state_opt =
  let (module F : State_functions with type state_t = state_t) =
    state_functions
  in
  let (Transition_states ((module Transition_states), states)) =
    transition_states
  in
  let add_if condition set =
    if condition then State_hash.Set.add set state_hash else set
  in
  let is_waiting_for_parent, is_processing_or_failed =
    let viewer subst =
      match subst.status with
      | Waiting_for_parent _ ->
          (true, false)
      | Processing _ | Failed _ ->
          (false, true)
      | _ ->
          (false, false)
    in
    Option.value ~default:(false, false)
    @@ Option.bind state_opt ~f:(view ~state_functions ~f:{ viewer })
  in
  let modifier subst =
    ( { subst with
        children =
          { processed =
              State_hash.Set.remove subst.children.processed state_hash
          ; waiting_for_parent =
              add_if is_waiting_for_parent subst.children.waiting_for_parent
          ; processing_or_failed =
              add_if is_processing_or_failed subst.children.processing_or_failed
          }
      }
    , () )
  in
  Transition_states.modify_substate_ states ~f:{ modifier } parent_hash

(** [is_processing_done] functions takes state and returns true iff
    the status of the state is [Substate.Processing (Substate.Done _)]. *)
let is_processing_done ~state_functions =
  Fn.compose (Option.value ~default:false)
  @@ view ~state_functions
       ~f:
         { viewer =
             (fun subst ->
               match subst.status with
               | Processing (Done _) ->
                   true
               | _ ->
                   false )
         }

module For_tests = struct
  (** [collect_failed_ancestry top_state] collects transitions from the top state (inclusive)
  down the ancestry chain that are:
  
    1. In [Failed] substate
    and
    2. Have same state level as [top_state]

    Returned list of states is in the parent-first order.
*)
  let collect_failed_ancestry ~state_functions ~transition_states top_state =
    let viewer s =
      match s.status with
      | Failed _ ->
          (`Take true, `Continue true)
      | _ ->
          (`Take false, `Continue true)
    in
    collect_states ~predicate:{ viewer } ~state_functions ~transition_states
      top_state

  (** [collect_dependent_ancestry top_state] collects transitions from the top state (inclusive) down the ancestry chain 
  while collected states are:
  
    1. In [Waiting_for_parent], [Failed] or [Processing Dependent] substate
    and
    2. Have same state level as [top_state]

    States with [Processed] status are skipped through.
    Returned list of states is in the parent-first order.
*)
  let collect_dependent_ancestry ~state_functions ~transition_states top_state =
    let viewer s =
      match s.status with
      | Processing (In_progress _) ->
          (`Take false, `Continue false)
      | Waiting_for_parent _ | Failed _ | Processing _ ->
          (`Take true, `Continue true)
      | Processed _ ->
          (`Take false, `Continue true)
    in
    collect_states ~predicate:{ viewer } ~state_functions ~transition_states
      top_state
end
