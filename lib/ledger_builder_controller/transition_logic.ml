open Core_kernel
open Async_kernel

module type Inputs_intf = sig
  module State : sig
    type hash

    type t [@@deriving eq, sexp]

    val hash : t -> hash
  end

  module Transition : sig
    type t [@@deriving eq, sexp, compare, bin_io]

    val target_state : t -> State.t

    val is_parent_of : child:t -> parent:t -> bool
  end

  module Heavy : sig
    type t [@@deriving sexp, bin_io]

    val state : t -> State.t

    val copy : t -> t

    val transition_unchecked : t -> Transition.t -> t Deferred.t

    (*let lb = state.locked_tip.ledger_builder in*)
    (*let%map () = force_apply_transitions lb [new_head] in*)
    (*assert_valid_state new_head lb*)

    val is_parent_of : child:Transition.t -> parent:t -> bool

    val is_materialization_of : t -> Transition.t -> bool
  end

  module Handler_state :
    Handler0.S with type heavy := Heavy.t and type transition := Transition.t

  module Step : sig
    (* This checks the SNARKs in State/LB and does the transition *)

    val step : Heavy.t -> Transition.t -> Heavy.t Deferred.Or_error.t
  end

  module Select : sig
    val select : State.t -> State.t -> State.t
  end

  module Catchup : sig
    type t

    val sync :
         t
      -> Handler_state.t
      -> Transition.t
      -> (Transition.t, Handler_state.Change.t list) Job.t
  end
end

module type S = sig
  type t

  type catchup

  type transition

  type heavy

  type handler_state

  type handler_state_change

  type state

  val create : handler_state -> Logger.t -> t

  val state : t -> handler_state

  val on_new_transition :
       catchup
    -> t
    -> transition
    -> ( handler_state_change list
       * (transition, handler_state_change list) Job.t option )
       Deferred.t

  val local_get_heavy :
       t
    -> p_heavy:(heavy -> bool)
    -> p_trans:(transition -> bool)
    -> (heavy * state) Deferred.Or_error.t
end

module Make (Inputs : Inputs_intf) :
  S
  with type catchup := Inputs.Catchup.t
   and type transition := Inputs.Transition.t
   and type handler_state := Inputs.Handler_state.t
   and type handler_state_change := Inputs.Handler_state.Change.t
   and type heavy := Inputs.Heavy.t
   and type state := Inputs.State.t =
struct
  open Inputs
  open Handler_state

  type t = {state: Handler_state.t; log: Logger.t}

  let state {state; _} = state

  type t0 = t

  module Path = Path.Make (State) (Transition)

  (* For debugging *)
  let num x = Obj.magic (Transition.target_state x |> State.hash)

  let str_path path =
    String.concat
      (List.concat
         [ [ Printf.sprintf "Path[source=%d:"
               (path.Path.source |> State.hash |> Obj.magic) ]
         ; List.map path.Path.path ~f:(fun transition ->
               Printf.sprintf "%d," (num transition) )
         ; ["]"] ])

  (* End for debugging *)

  let create state parent_log : t =
    {state; log= Logger.child parent_log __MODULE__}

  let locked_and_best tree =
    let path = Transition_tree.longest_path tree in
    (List.hd_exn path, List.last_exn path)

  let select_transition x y =
    let f = Transition.target_state in
    let sx = f x in
    let sy = f y in
    if State.equal (Select.select sx sy) sx then x else y

  module Path_traversal = struct
    type t = (Transition.t, Handler_state.Change.t list) Job.t

    let transition_unchecked h t =
      Interruptible.uninterruptible (Heavy.transition_unchecked h t)

    let run (t: t0) new_tree new_best_path _transition =
      let {locked_tip; ktree= _; longest_branch_tip} = t.state in
      let new_head, _new_tip = locked_and_best new_tree in
      let open Interruptible.Let_syntax in
      let ivar : Transition.t Ivar.t = Ivar.create () in
      let step heavy transition =
        Interruptible.lift (Step.step heavy transition) (Ivar.read ivar)
      in
      let work =
        (* Adjust the locked_ledger if necessary *)
        let%bind locked_tip =
          if Heavy.is_parent_of ~child:new_head ~parent:locked_tip then
            let locked_tip = Heavy.copy locked_tip in
            transition_unchecked locked_tip new_head
          else return locked_tip
        in
        (* Now adjust the longest_branch_tip *)
        let heavy, path =
          match
            Path.findi new_best_path ~f:(fun _ x ->
                Heavy.is_materialization_of longest_branch_tip x )
          with
          | None -> (Heavy.copy locked_tip, new_best_path)
          | Some (i, _) ->
              (Heavy.copy longest_branch_tip, Path.drop new_best_path (i + 1))
        in
        let last_transition = List.last_exn path.Path.path in
        (* Now step over the path *)
        assert (State.equal (Heavy.state heavy) path.Path.source) ;
        let%map result =
          List.fold path.Path.path ~init:(Interruptible.return (Some heavy))
            ~f:(fun work curr ->
              match%bind work with
              | None -> return None
              | Some heavy ->
                  match%bind step heavy curr with
                  | Ok heavy -> return (Some heavy)
                  | Error e ->
                      (* TODO: Punish sender *)
                      Logger.info t.log "Recieved malicious transition %s"
                        (Error.to_string_hum e) ;
                      return None )
        in
        match result with
        | Some heavy ->
            assert (
              State.equal (Heavy.state heavy)
                (Transition.target_state last_transition) ) ;
            [Handler_state.Change.Longest_branch_tip heavy]
        | None -> []
      in
      (work, ivar)

    let create (t: t0) new_tree new_best_path (transition: Transition.t) : t =
      (transition, run t new_tree new_best_path)
  end

  let local_get_heavy ({state; log= _} as t) ~p_heavy ~p_trans =
    let {locked_tip; longest_branch_tip; ktree} = state in
    match ktree with
    | None ->
        return
          (Or_error.error_string "Not found locally, because I have no ktree")
    | Some ktree ->
        let attempt_easy heavy err_msg_name =
          let maybe_state =
            Transition_tree.find_map ktree ~f:(fun trans ->
                if p_trans trans then Some (Transition.target_state trans)
                else None )
          in
          match maybe_state with
          | None ->
              return
              @@ Or_error.errorf
                   "This was our %s, but we didn't witness the state"
                   err_msg_name
          | Some state -> return @@ Ok (heavy, state)
        in
        if p_heavy locked_tip then attempt_easy locked_tip "locked"
        else if p_heavy longest_branch_tip then
          attempt_easy longest_branch_tip "longest_branch"
        else
          match
            Option.map
              (Transition_tree.path ktree ~f:p_trans)
              ~f:Path.of_tree_path
          with
          | Some path -> (
              (* Note: We can't have zero transitions because then we would have
             * matched the locked_tip *)
              let last_transition = List.last_exn path.Path.path in
              let job = Path_traversal.create t ktree path last_transition in
              let w, _ = Job.run job in
              match%map w.d with
              | Error _ ->
                  failwith "We are never cancelling, so it can't be cancelled"
              | Ok [] -> Or_error.error_string "Path traversing failed"
              | Ok changes ->
                  let state' = apply_all t.state changes in
                  assert (p_heavy state'.longest_branch_tip) ;
                  Ok
                    ( state'.longest_branch_tip
                    , Transition.target_state last_transition ) )
          | None -> return (Or_error.error_string "Not found locally")

  let on_new_transition catchup ({state; log= _} as t)
      (transition: Transition.t) :
      ( Handler_state.Change.t list
      * (Transition.t, Handler_state.Change.t list) Job.t option )
      Deferred.t =
    let {locked_tip; longest_branch_tip= _; ktree} = state in
    match ktree with
    | None ->
        let source_state = Heavy.state locked_tip in
        let target_state = Transition.target_state transition in
        if Heavy.is_parent_of ~child:transition ~parent:locked_tip then
          let job =
            Path_traversal.create t
              (Transition_tree.single transition)
              {Path.source= Heavy.state locked_tip; path= [transition]}
              transition
          in
          let work, _ = Job.run job in
          match%map work.d with
          | Ok changes -> (changes, None)
          | Error _ ->
              failwith "Unexpected, we aren't cancelling this job ever"
        else if
          State.equal (Select.select source_state target_state) target_state
        then return ([], Some (Catchup.sync catchup state transition))
        else return ([], None)
    | Some old_tree ->
      match
        Transition_tree.add old_tree transition ~parent:(fun x ->
            Transition.is_parent_of ~child:transition ~parent:x )
      with
      | `No_parent ->
          let best_tip = locked_and_best old_tree |> snd in
          if
            Transition.equal (select_transition best_tip transition) transition
          then return ([], Some (Catchup.sync catchup state transition))
          else return ([], None)
      | `Repeat -> return ([], None)
      | `Added new_tree ->
          let old_locked_head, old_best_tip = locked_and_best old_tree in
          let new_head, new_tip = locked_and_best new_tree in
          if
            Transition.equal old_locked_head new_head
            && Transition.equal old_best_tip new_tip
          then return ([Handler_state.Change.Ktree new_tree], None)
          else
            let new_best_path =
              Transition_tree.longest_path new_tree |> Path.of_tree_path
            in
            return
              ( [Handler_state.Change.Ktree new_tree]
              , Some
                  (Path_traversal.create t new_tree new_best_path transition)
              )
end
