open Mina_base
open Core_kernel
open Async_kernel

type 'a processing_context =
  | In_progress of { interrupt_ivar : unit Ivar.t; timeout : Time.t }
  | Dependent
  | Done of 'a

type 'a ancestry_status =
  (* Waiting for parent to be processed before starting the processing.
     This state might be skipped when sequential processing is unnecessary. *)
  | Waiting_for_parent of (unit -> 'a ancestry_status)
  (* Processing of the state is in progress. *)
  | Processing of 'a processing_context
  (* Processing failed, but could be retried *)
  | Failed of Error.t
  (* State is processed and ready to be transitioned to higher state after
     ancestry is also processed *)
  | Processed of 'a

type children_sets =
  { processed : State_hash.Set.t
  ; waiting_for_parent : State_hash.Set.t
  ; processing_or_failed : State_hash.Set.t
  }

let empty_children_sets =
  { processing_or_failed = State_hash.Set.empty
  ; processed = State_hash.Set.empty
  ; waiting_for_parent = State_hash.Set.empty
  }

type 'a common_substate =
  { status : 'a ancestry_status
  ; received_via_gossip : bool
  ; children : children_sets
  ; received_at : Time.t
  ; sender : Network_peer.Envelope.Sender.t
  }

type 'v modifier =
  { modifier : 'a. 'a common_substate -> 'a common_substate * 'v }

type 'v viewer = { viewer : 'a. 'a common_substate -> 'v }

type ('a, 'b) modify_substate_t = f:'a modifier -> 'b -> ('b * 'a) option

let view ~(modify_substate : ('a, 'b) modify_substate_t) ~f =
  Fn.compose (Option.map ~f:snd)
    (modify_substate ~f:{ modifier = (fun st -> (st, f.viewer st)) })

module type State_functions = sig
  type state_t

  val modify_substate : ('a, state_t) modify_substate_t

  val header_with_hash :
    state_t -> Mina_block.Header.t State_hash.With_state_hashes.t

  val equal_state_levels : state_t -> state_t -> bool
end

(** [collect_states top_state] collects transitions from the top state (inclusive) down the ancestry chain 
  while:
  
    1. Condition [predicate] is held
    and
    2. Have same state level as [top_state]

    Returned list of states is in the parent-first order.
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
    else view ~modify_substate ~f:predicate state
  in
  let rec loop state =
    let hh = header_with_hash state in
    let parent_hash =
      With_hash.data hh |> Mina_block.Header.protocol_state
      |> Mina_state.Protocol_state.previous_state_hash
    in
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
  
    1. In [Waiting_for_parent], [Failed] or ([Processing] and received by gossip) substate
    and
    2. Have same state level as [top_state]

    Returned list of states is in the parent-first order.
*)
let collect_dependent_ancestry ~state_functions ~transition_states top_state =
  let viewer s =
    match (s.status, s.received_via_gossip) with
    | Waiting_for_parent _, _ | Failed _, _ | Processing _, false ->
        (`Take true, `Continue true)
    (* Iteration is stopped once we encounter a Processed or a Processing with gossip received state  *)
    | Processed _, _ | Processing _, true ->
        (`Take false, `Continue false)
  in
  collect_states ~predicate:{ viewer } ~state_functions ~transition_states
    top_state

(** [collect_failed_ancestry top_state] collects transitions from the top state (inclusive) down the ancestry chain 
  while collected states are:
  
    1. In [Failed] substate
    and
    2. Have same state level as [top_state]

    Returned list of states is in the parent-first order.
*)
let mark_processed_sm ~is_recursive_call subst =
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
      Result.Ok
        ({ subst with status = Processed a_res; children }, subst.children)
  | Processing Dependent ->
      Result.Error "not started"
  | Processing (In_progress _) ->
      Result.Error "still processing"
  | Processed _ when is_recursive_call ->
      Result.Ok ({ subst with children }, subst.children)
  | Processed _ ->
      Result.Error "already processed"

let parent_hash (type state_t)
    ~state_functions:(module F : State_functions with type state_t = state_t)
    state =
  let hh = F.header_with_hash state in
  With_hash.data hh |> Mina_block.Header.protocol_state
  |> Mina_state.Protocol_state.previous_state_hash

let is_to_continue_mark_processed_recursion (type state_t) ~state_functions
    ~transition_states state =
  let parent_hash = parent_hash ~state_functions state in
  let (module F : State_functions with type state_t = state_t) =
    state_functions
  in
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

let promote_waiting_for_parent (type state_t) ~state_functions ~logger
    ~transition_states state_hash =
  let (module F : State_functions with type state_t = state_t) =
    state_functions
  in
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
          let parent_hash = parent_hash ~state_functions state in
          State_hash.Table.change transition_states parent_hash
            ~f:(Option.bind ~f:update_children)
      | _ ->
          [%log warn] "child $state_hash is not in waiting_for_parent state"
            ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ] )

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
   2. Respective substates for states from [processed] are in [Processing] status, having the actions determined

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
          ~f:{ modifier = (fun st -> mark_processed_sm ~is_recursive_call st) }
          state
      in
      Option.iter ~f:(fun err -> [%log warn] "error %s" err) (Result.error res) ;
      let%map children = Result.ok res in
      State_hash.Table.set transition_states ~key:hash ~data:state' ;
      let parent_hash = parent_hash ~state_functions state in
      update_children_on_processed ~transition_states ~state_functions
        ~parent_hash
        (F.header_with_hash state |> State_hash.With_state_hashes.state_hash) ;
      State_hash.Set.iter children.waiting_for_parent
        ~f:
          (promote_waiting_for_parent ~state_functions ~logger
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

let update_children_on_promotion (type state_t)
    ~state_functions:(module F : State_functions with type state_t = state_t)
    ~transition_states ~parent_hash ~state_hash state_opt =
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
    @@ Option.bind state_opt
         ~f:(view ~modify_substate:F.modify_substate ~f:{ viewer })
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

module For_tests = struct
  let collect_failed_ancestry ~state_functions ~transition_states top_state =
    let viewer s =
      match (s.status, s.received_via_gossip) with
      | Failed _, _ ->
          (`Take true, `Continue true)
      | _ ->
          (`Take false, `Continue true)
    in
    collect_states ~predicate:{ viewer } ~state_functions ~transition_states
      top_state
end
