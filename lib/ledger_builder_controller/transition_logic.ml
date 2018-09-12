open Core_kernel
open Async_kernel

module type Inputs_intf = sig
  module State_hash : sig
    type t
  end

  module Consensus_mechanism : sig
    module Consensus_state : sig
      type value
    end

    val select :
         Consensus_state.value
      -> Consensus_state.value
      -> logger:Logger.t
      -> time_received:Unix_timestamp.t
      -> [`Keep | `Take]
  end

  module Protocol_state : sig
    type value [@@deriving sexp]

    val consensus_state : value -> Consensus_mechanism.Consensus_state.value

    val equal_value : value -> value -> bool

    val hash : value -> State_hash.t
  end

  module Ledger_hash : sig
    type t [@@deriving sexp, eq]
  end

  module External_transition : sig
    type t [@@deriving eq, sexp, compare, bin_io]

    val target_state : t -> Protocol_state.value

    val ledger_hash : t -> Ledger_hash.t

    val is_parent_of : child:t -> parent:t -> bool
  end

  module Tip : sig
    type t [@@deriving sexp]

    val state : t -> Protocol_state.value

    val copy : t -> t

    val transition_unchecked : t -> External_transition.t -> t Deferred.t

    val is_parent_of : child:External_transition.t -> parent:t -> bool

    val is_materialization_of : t -> External_transition.t -> bool

    val ledger_builder_ledger_hash : t -> Ledger_hash.t
  end

  module Transition_logic_state :
    Transition_logic_state.S
    with type tip := Tip.t
     and type external_transition := External_transition.t

  module Step : sig
    (* This checks the SNARKs in State/LB and does the transition *)

    val step : Tip.t -> External_transition.t -> Tip.t Deferred.Or_error.t
  end

  module Catchup : sig
    type t

    val sync :
         t
      -> Transition_logic_state.t
      -> External_transition.t
      -> (External_transition.t, Transition_logic_state.Change.t list) Job.t
  end
end

module type S = sig
  type t

  type catchup

  type transition

  type tip

  type transition_logic_state

  type handler_state_change

  type state

  val create : transition_logic_state -> Logger.t -> t

  val state : t -> transition_logic_state

  val on_new_transition :
       catchup
    -> t
    -> transition
    -> time_received:Unix_timestamp.t
    -> ( handler_state_change list
       * (transition, handler_state_change list) Job.t option )
       Deferred.t

  val local_get_tip :
       t
    -> p_tip:(tip -> bool)
    -> p_trans:(transition -> bool)
    -> (tip * state) Deferred.Or_error.t
end

module Make (Inputs : Inputs_intf) :
  S
  with type catchup := Inputs.Catchup.t
   and type transition := Inputs.External_transition.t
   and type transition_logic_state := Inputs.Transition_logic_state.t
   and type handler_state_change := Inputs.Transition_logic_state.Change.t
   and type tip := Inputs.Tip.t
   and type state := Inputs.Protocol_state.value =
struct
  open Inputs
  open Transition_logic_state

  type t = {state: Transition_logic_state.t; log: Logger.t}

  let state {state; _} = state

  type t0 = t

  module Path =
    Path.Make (struct
        type t = Protocol_state.value [@@deriving sexp]
      end)
      (struct
        include External_transition

        let target = target_state
      end)

  let create state parent_log : t =
    {state; log= Logger.child parent_log __MODULE__}

  let locked_and_best tree =
    let path = Transition_tree.longest_path tree in
    (List.hd_exn path, List.last_exn path)

  module Path_traversal = struct
    type t =
      (External_transition.t, Transition_logic_state.Change.t list) Job.t

    let transition_unchecked h t =
      Interruptible.uninterruptible (Tip.transition_unchecked h t)

    let run (t: t0) new_tree old_tree new_best_path _logger _transition =
      let locked_tip = Transition_logic_state.locked_tip t.state
      and longest_branch_tip =
        Transition_logic_state.longest_branch_tip t.state
      in
      let new_head, _new_tip = locked_and_best new_tree in
      let old_head, _old_tip = locked_and_best old_tree in
      let open Interruptible.Let_syntax in
      let ivar : External_transition.t Ivar.t = Ivar.create () in
      let step tip transition =
        Interruptible.lift (Step.step tip transition)
          (Deferred.map (Ivar.read ivar) ~f:ignore)
      in
      let work =
        (* Adjust the locked_ledger if necessary *)
        let%bind locked_tip =
          if External_transition.is_parent_of ~child:new_head ~parent:old_head
          then
            let locked_tip = Tip.copy locked_tip in
            transition_unchecked locked_tip new_head
          else return locked_tip
        in
        (* Now adjust the longest_branch_tip *)
        let tip, path =
          match
            Path.findi new_best_path ~f:(fun _ x ->
                Tip.is_materialization_of longest_branch_tip x )
          with
          | None -> (Tip.copy locked_tip, new_best_path)
          | Some (i, _) ->
              (Tip.copy longest_branch_tip, Path.drop new_best_path (i + 1))
        in
        let last_transition = List.last_exn path.Path.path in
        (* Now step over the path *)
        assert (Protocol_state.equal_value (Tip.state tip) path.Path.source) ;
        let%map result =
          List.fold path.Path.path ~init:(Interruptible.return (Some tip)) ~f:
            (fun work curr ->
              match%bind work with
              | None -> return None
              | Some tip ->
                  match%bind step tip curr with
                  | Ok tip -> return (Some tip)
                  | Error e ->
                      (* TODO: Punish sender *)
                      Logger.warn t.log "Recieved malicious transition %s"
                        (Error.to_string_hum e) ;
                      return None )
        in
        match result with
        | Some tip ->
            assert (
              Protocol_state.equal_value (Tip.state tip)
                (External_transition.target_state last_transition) ) ;
            [ Transition_logic_state.Change.Longest_branch_tip tip
            ; Transition_logic_state.Change.Ktree new_tree ]
        | None -> []
      in
      (work, ivar)

    let create (t: t0) new_tree old_tree new_best_path (logger: Logger.t)
        (transition: External_transition.t) : t =
      (transition, run t new_tree old_tree new_best_path logger)
  end

  let local_get_tip t ~p_tip ~p_trans =
    let locked_tip = Transition_logic_state.locked_tip t.state
    and ktree = Transition_logic_state.ktree t.state
    and longest_branch_tip =
      Transition_logic_state.longest_branch_tip t.state
    in
    match ktree with
    | None ->
        return
          (Or_error.error_string "Not found locally, because I have no ktree")
    | Some ktree ->
        let attempt_easy tip err_msg_name =
          let maybe_state =
            Transition_tree.find_map ktree ~f:(fun trans ->
                if p_trans trans then
                  Some (External_transition.target_state trans)
                else None )
          in
          match maybe_state with
          | None ->
              return
              @@ Or_error.errorf
                   "This was our %s, but we didn't witness the state"
                   err_msg_name
          | Some state -> return @@ Ok (tip, state)
        in
        if p_tip locked_tip then attempt_easy locked_tip "locked"
        else if p_tip longest_branch_tip then
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
              let job =
                Path_traversal.create t ktree ktree path t.log last_transition
              in
              let w, _ = Job.run job in
              match%map w.d with
              | Error _ ->
                  failwith "We are never cancelling, so it can't be cancelled"
              | Ok [] -> Or_error.error_string "Path traversing failed"
              | Ok changes ->
                  let longest_branch_tip_maybe =
                    List.find_map changes ~f:(function
                      | Longest_branch_tip tip -> Some tip
                      | _ -> None )
                  in
                  match longest_branch_tip_maybe with
                  | None -> Or_error.error_string "Path traversing failed"
                  | Some longest_branch_tip ->
                      assert (p_tip longest_branch_tip) ;
                      Ok
                        ( longest_branch_tip
                        , External_transition.target_state last_transition ) )
          | None -> return (Or_error.error_string "Not found locally")

  let on_new_transition catchup ({state; log} as t)
      (transition: External_transition.t) ~(time_received: Unix_timestamp.t) :
      ( Transition_logic_state.Change.t list
      * (External_transition.t, Transition_logic_state.Change.t list) Job.t
        option )
      Deferred.t =
    let longest_branch_tip = Transition_logic_state.longest_branch_tip t.state
    and ktree = Transition_logic_state.ktree t.state in
    match ktree with
    | None -> (
        let source_state = Tip.state longest_branch_tip in
        let target_state = External_transition.target_state transition in
        if Tip.is_parent_of ~child:transition ~parent:longest_branch_tip then (
          (* Bootstrap from genesis *)
          let tree = Transition_tree.singleton transition in
          match%map Step.step longest_branch_tip transition with
          | Ok tip ->
              ( [ Transition_logic_state.Change.Ktree tree
                ; Transition_logic_state.Change.Longest_branch_tip tip
                ; Transition_logic_state.Change.Locked_tip tip ]
              , None )
          | Error e ->
              (* TODO: Punish sender *)
              Logger.info log "Recieved malicious transition %s"
                (Error.to_string_hum e) ;
              ([], None) )
        else
          match
            Consensus_mechanism.select
              (Protocol_state.consensus_state source_state)
              (Protocol_state.consensus_state target_state)
              ~logger:log ~time_received
          with
          | `Keep -> return ([], None)
          | `Take ->
              let lh = External_transition.ledger_hash transition in
              Logger.debug t.log
                !"Branch catchup for transition: lh:%{sexp: Ledger_hash.t} \
                  state:%{sexp:Protocol_state.value}"
                lh target_state ;
              return ([], Some (Catchup.sync catchup state transition)) )
    | Some old_tree ->
      match
        Transition_tree.add old_tree transition ~parent:(fun x ->
            External_transition.is_parent_of ~child:transition ~parent:x )
      with
      | `No_parent -> (
          let best_tip = locked_and_best old_tree |> snd in
          match
            Consensus_mechanism.select
              ( transition |> External_transition.target_state
              |> Protocol_state.consensus_state )
              ( best_tip |> External_transition.target_state
              |> Protocol_state.consensus_state )
              ~logger:log ~time_received
          with
          | `Keep ->
              Logger.debug t.log "Branch noparent" ;
              return ([], Some (Catchup.sync catchup state transition))
          | `Take -> return ([], None) )
      | `Repeat -> return ([], None)
      | `Added new_tree ->
          let old_locked_head, old_best_tip = locked_and_best old_tree in
          let new_head, new_tip = locked_and_best new_tree in
          if
            External_transition.equal old_locked_head new_head
            && External_transition.equal old_best_tip new_tip
          then return ([Transition_logic_state.Change.Ktree new_tree], None)
          else
            let new_best_path =
              Transition_tree.longest_path new_tree |> Path.of_tree_path
            in
            return
              ( []
              , Some
                  (Path_traversal.create t new_tree old_tree new_best_path log
                     transition) )
end
