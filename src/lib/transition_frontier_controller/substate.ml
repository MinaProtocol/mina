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

    Returned list of states is in the child-first order.
*)
let collect_states (type state_t) ~predicate ~state_functions ~transition_states
    top_state =
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
  let rec loop state =
    let parent_hash = (transition_meta state).parent_state_hash in
    Option.value_map ~default:[]
      ~f:(fun parent_state ->
        if equal_state_levels parent_state state then
          let `Take to_take, `Continue to_continue = full_predicate state in
          let take_f = if to_take then List.cons state else Fn.id in
          take_f @@ if to_continue then loop parent_state else []
        else
          (* Parent is of different state => it's of higher state => we don't need to go deeper *)
          [] )
      (State_hash.Table.find transition_states parent_hash)
  in
  loop top_state

(** [collect_dependent_ancestry top_state] collects transitions from the top state (inclusive) down the ancestry chain 
  while collected states are:
  
    1. In [Waiting_for_parent], [Failed] or [Processing Dependent] substate
    and
    2. Have same state level as [top_state]

    States with [Processed] status are skipped through.
    Returned list of states is in the child-first order.
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

(** Modify status of common substate to [Processed].
    
    Function returns [Result.Ok] with new modified common substate
    and [children] of the substate when substate has [Processing (Done x)] status
    and [Result.Error] otherwise.
*)
let mark_processed_modifier ~is_recursive_call subst =
  let reshape res =
    match res with
    | Result.Error _ as e ->
        (subst, e)
    | Result.Ok (subst', children) ->
        (subst', Result.Ok children)
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

(** Function determines whether to continue mark processed recursive
    call.
    
    It takes transition and returns true iff:

      * Transition's parent is not in the catchup state (which means it's in frontier)
      * Transition's parent has a higher state level
    *)
let is_to_continue_mark_processed_recursion (type state_t)
    ~state_functions:(module F : State_functions with type state_t = state_t)
    ~transition_states state =
  let parent_hash = (F.transition_meta state).parent_state_hash in
  Option.value_map
    (State_hash.Table.find transition_states parent_hash)
    ~f:
      (* Parent is found and differs in state level, hence it's of higher state *)
      (Fn.compose not (F.equal_state_levels state))
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
    ~logger ~transition_states state_hash =
  let modifier subst =
    match subst.status with
    | Waiting_for_parent mk_status ->
        ({ subst with status = mk_status () }, true)
    | _ ->
        (subst, false)
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
  let update_children =
    Fn.compose (Option.map ~f:fst)
      (F.modify_substate ~f:{ modifier = update_children_modifier })
  in
  match State_hash.Table.find transition_states state_hash with
  | None ->
      [%log warn] "child $state_hash not found"
        ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ]
  | Some state -> (
      match F.modify_substate ~f:{ modifier } state with
      | Some (data, true) ->
          State_hash.Table.set transition_states ~key:state_hash ~data ;
          let parent_hash = (F.transition_meta state).parent_state_hash in
          State_hash.Table.change transition_states parent_hash
            ~f:(Option.bind ~f:update_children)
      | _ ->
          [%log warn] "child $state_hash is not in waiting_for_parent state"
            ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ] )

(** Update children of the parent upon transition aquiring the [Processed] status *)
let update_children_on_processed (type state_t) ~transition_states ~parent_hash
    ~state_functions:(module F : State_functions with type state_t = state_t)
    state_hash =
  let update_children_modifier subst =
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
  let update_children =
    Fn.compose (Option.map ~f:fst)
      (F.modify_substate ~f:{ modifier = update_children_modifier })
  in
  State_hash.Table.change transition_states parent_hash
    ~f:(Option.bind ~f:update_children)

(** [mark_processed processed] marks a list of state hashes as Processed.

  It returns a list of state hashes to be promoted to higher state.
   
  Pre-conditions:
   1. Order of [processed] respects parent-child relationship and parent always comes first
   2. Respective substates for states from [processed] are in [Processing (Done _)] status

  Post-condition: list returned respects parent-child relationship and parent always comes first *)
let mark_processed (type state_t) ~logger ~state_functions ~transition_states
    processed =
  let (module F : State_functions with type state_t = state_t) =
    state_functions
  in
  let processed_set = ref (State_hash.Set.of_list processed) in
  let rec handle is_recursive_call hash =
    Option.value ~default:[]
      (let open Option.Let_syntax in
      let%bind () =
        Option.some_if (State_hash.Set.mem !processed_set hash) ()
      in
      let%bind state = State_hash.Table.find transition_states hash in
      processed_set := State_hash.Set.remove !processed_set hash ;
      let%bind state', res =
        F.modify_substate
          ~f:
            { modifier =
                (fun st -> mark_processed_modifier ~is_recursive_call st)
            }
          state
      in
      Option.iter ~f:(fun err -> [%log warn] "error %s" err) (Result.error res) ;
      let%map children = Result.ok res in
      State_hash.Table.set transition_states ~key:hash ~data:state' ;
      let parent_hash = (F.transition_meta state).parent_state_hash in
      update_children_on_processed ~transition_states ~state_functions
        ~parent_hash (F.transition_meta state).state_hash ;
      State_hash.Set.iter children.waiting_for_parent
        ~f:
          (kickstart_waiting_for_parent ~state_functions ~logger
             ~transition_states ) ;
      if
        is_recursive_call
        || is_to_continue_mark_processed_recursion ~state_functions
             ~transition_states state
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

    TODO more details
*)
let update_children_on_promotion (type state_t) ~state_functions
    ~transition_states ~parent_hash ~state_hash state_opt =
  let (module F : State_functions with type state_t = state_t) =
    state_functions
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
  let update_children_modifier subst =
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
  let update_children =
    Fn.compose (Option.map ~f:fst)
      (F.modify_substate ~f:{ modifier = update_children_modifier })
  in
  State_hash.Table.change transition_states parent_hash
    ~f:(Option.bind ~f:update_children)

(** [view_processing] functions takes state and returns [`Done] if the processing is finished,
    [`In_progress timeout] is the processing continues and [None] if the processing is dependent
      or status is different from [Processing].  *)
let view_processing ~state_functions =
  Fn.compose Option.join
  @@ view ~state_functions
       ~f:
         { viewer =
             (fun subst ->
               match subst.status with
               | Processing (Done _) ->
                   Some `Done
               | Processing (In_progress { timeout; _ }) ->
                   Some (`In_progress timeout)
               | _ ->
                   None )
         }

module For_tests = struct
  (** [collect_failed_ancestry top_state] collects transitions from the top state (inclusive)
  down the ancestry chain that are:
  
    1. In [Failed] substate
    and
    2. Have same state level as [top_state]

    Returned list of states is in the child-first order.
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
end
