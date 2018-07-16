open Core_kernel
open Async_kernel

module type Inputs_intf = sig
  module Ledger_builder_hash : sig
    type t [@@deriving eq, bin_io]
  end

  module Ledger_hash : sig
    type t [@@deriving bin_io]
  end

  module Ledger_builder_transition : sig
    type t [@@deriving eq, sexp, compare, bin_io]
  end

  module Ledger : sig
    type t

    val copy : t -> t

    val merkle_root : t -> Ledger_hash.t
  end

  module Ledger_builder : sig
    type t [@@deriving bin_io]

    type proof

    type aux_data [@@deriving bin_io]

    val ledger : t -> Ledger.t

    val create : Ledger.t -> t

    val of_aux_and_ledger : Ledger.t -> aux_data -> t Or_error.t

    val copy : t -> t

    val hash : t -> Ledger_builder_hash.t

    val apply :
         t
      -> Ledger_builder_transition.t
      -> (Ledger_hash.t * proof) option Deferred.Or_error.t
  end

  module State_hash : sig
    type t [@@deriving eq]
  end

  module Strength : sig
    type t

    val ( < ) : t -> t -> bool

    val ( > ) : t -> t -> bool

    val ( = ) : t -> t -> bool
  end

  module State : sig
    type t [@@deriving eq, sexp, compare, bin_io]

    val ledger_builder_hash : t -> Ledger_builder_hash.t

    val hash : t -> State_hash.t

    val strength : t -> Strength.t

    val previous_state_hash : t -> State_hash.t

    val ledger_hash : t -> Ledger_hash.t
  end

  (* TODO: Figure out where to plumb this *)

  module State_with_proof_checked : sig
    type t [@@deriving eq, sexp, compare, bin_io]

    val state : t -> State.t
  end

  module Valid_transaction : sig
    type t [@@deriving eq, sexp, compare, bin_io]
  end

  module Sync_ledger : sig
    type t

    type answer [@@deriving bin_io]

    type query [@@deriving bin_io]

    val create : Ledger.t -> goal:Ledger_hash.t -> t

    val answer_writer : t -> (Ledger_hash.t * answer) Linear_pipe.Writer.t

    val query_reader : t -> (Ledger_hash.t * query) Linear_pipe.Reader.t

    val destroy : t -> unit

    val new_goal : t -> Ledger_hash.t -> unit

    val wait_until_valid :
      t -> Ledger_hash.t -> [`Ok of Ledger.t | `Target_changed] Deferred.t
  end

  module Step : sig
    (* This checks the SNARKs in State/LB and does the transition *)

    val step :
         Ledger_builder.t * State.t
      -> Ledger_builder_transition.t
      -> State.t Deferred.Or_error.t
  end

  module Net : sig
    include Coda.Ledger_builder_io_intf
            with type sync_ledger_query := Sync_ledger.query
             and type sync_ledger_answer := Sync_ledger.answer
             and type ledger_builder_hash := Ledger_builder_hash.t
             and type ledger_builder_aux := Ledger_builder.aux_data
             and type ledger_hash := Ledger_hash.t
             and type state := State.t
  end

  module Store : Storage.With_checksum_intf
end

(* TODO: Give clear semantics for and fix impl of this, see #300 *)
module Interruptible = struct
  module T = struct
    type ('a, 's) t =
      { stopped: bool ref
      ; interrupter: ('s -> unit) ref (* Invariant: this is idempotent *)
      ; d: 'a Deferred.Option.t }

    let local t ~f =
      { stopped= t.stopped
      ; interrupter= ref (fun s' -> !(t.interrupter) (f s'))
      ; d= t.d }

    let bind t ~f =
      if !(t.stopped) then {t with d= Deferred.return None}
      else
        let d' =
          Deferred.Option.bind t.d ~f:(fun a ->
              if !(t.stopped) then Deferred.return None
              else
                let t' = f a in
                t.stopped := !(t.stopped) || !(t'.stopped) ;
                let last_interrupter = !(t.interrupter) in
                (t.interrupter :=
                   fun s -> last_interrupter s ; !(t'.interrupter) s) ;
                t'.d )
        in
        {t with d= d'}

    let interrupt t s =
      t.stopped := true ;
      !(t.interrupter) s

    let return a =
      { stopped= ref false
      ; d= Deferred.Option.return a
      ; interrupter= ref (fun s -> ()) }

    let uninterruptible d =
      { stopped= ref false
      ; d= Deferred.map d ~f:(fun x -> Some x)
      ; interrupter= ref Fn.id }

    let lift d interrupter =
      (* Make it idempotent *)
      let once f =
        let called = ref false in
        fun s ->
          if !called then ()
          else (
            called := true ;
            f s )
      in
      { stopped= ref false
      ; d= Deferred.map d ~f:(fun x -> Some x)
      ; interrupter= ref (once interrupter) }

    let map = `Define_using_bind
  end

  module M = Monad.Make2 (T)
  include T
  include M
end

module Make (Inputs : Inputs_intf) : sig
  include Coda.Ledger_builder_controller_intf
          with type ledger_builder := Inputs.Ledger_builder.t
           and type ledger_builder_hash := Inputs.Ledger_builder_hash.t
           and type ledger_builder_transition :=
                      Inputs.Ledger_builder_transition.t
           and type ledger := Inputs.Ledger.t
           and type ledger_proof := Inputs.Ledger_builder.proof
           and type transaction_with_valid_signature :=
                      Inputs.Valid_transaction.t
           and type net := Inputs.Net.net
           and type state := Inputs.State.t
           and type ledger_hash := Inputs.Ledger_hash.t
           and type sync_query := Inputs.Sync_ledger.query
           and type sync_answer := Inputs.Sync_ledger.answer

  val ledger_builder_io : t -> Inputs.Net.t
end = struct
  open Inputs

  module Config = struct
    type t =
      { parent_log: Logger.t
      ; net_deferred: Net.net Deferred.t
      ; ledger_builder_transitions:
          (Valid_transaction.t list * State.t * Ledger_builder_transition.t)
          Linear_pipe.Reader.t
      ; genesis_ledger: Ledger.t
      ; disk_location: string }
    [@@deriving make]
  end

  module Transition_with_target = struct
    type t = {transition: Ledger_builder_transition.t; target_state: State.t}
    [@@deriving eq, compare, bin_io, sexp, fields]

    let ledger_builder_hash {target_state= s} = State.ledger_builder_hash s

    let ledger_hash {target_state= s} = State.ledger_hash s

    let state_hash {target_state= s} = State.hash s

    let strength {target_state= s} = State.strength s

    let previous_state_hash {target_state= s} = State.previous_state_hash s

    let gen transition_gen state_gen =
      let open Quickcheck.Generator.Let_syntax in
      let%map transition = transition_gen and target_state = state_gen in
      {transition; target_state}
  end

  module Transition_with_target_tree =
    Ktree.Make (Transition_with_target)
      (struct
        let k = 50
      end)

  module State = struct
    type t =
      { mutable locked_ledger_builder: Ledger_builder.t
      ; mutable longest_branch_tip: Ledger_builder.t
      ; mutable ktree: Transition_with_target_tree.t option
      (* TODO: This impl assumes we have the original Ouroboros assumption. In
         order to work with the Praos assumption we'll need to keep a linked
         list as well at the prefix of size (#blocks possible out of order)
       *)
      }
    [@@deriving bin_io]

    let create genesis_ledger : t =
      { locked_ledger_builder= Ledger_builder.create genesis_ledger
      ; longest_branch_tip= Ledger_builder.create genesis_ledger
      ; ktree= None }
  end

  module Aux = struct
    type t =
      { root_and_proof: (Ledger_hash.t * Ledger_builder.proof) option
      ; state: Inputs.State.t }
  end

  module Path = struct
    type t = {source: Inputs.State.t; path: Transition_with_target.t list}
    [@@deriving sexp, fields]

    let of_tree_path = function
      | [] -> failwith "Path can't be empty"
      | source :: path ->
          {source= Transition_with_target.target_state source; path}

    let findi t ~f = List.findi t.path ~f

    let drop t i =
      match List.drop t.path (i - 1) with
      | x :: xs -> {source= Transition_with_target.target_state x; path= xs}
      | [] -> failwith "Since we (i-1) this is impossible"
  end

  type t =
    { ledger_builder_io: Net.t
    ; log: Logger.t
    ; state: State.t
    ; strongest_ledgers:
        (Ledger_builder.t * Inputs.State.t) Linear_pipe.Reader.t }

  let ledger_builder_io {ledger_builder_io} = ledger_builder_io

  let locked_and_best tree =
    let path = Transition_with_target_tree.longest_path tree in
    (List.hd_exn path, List.last_exn path)

  (* The following assertion will always pass without extra checks because
     we'll have validated things when we get to this point *)
  let assert_valid_state (witness: Transition_with_target.t) builder =
    assert (
      Ledger_builder_hash.equal
        (Transition_with_target.ledger_builder_hash witness)
        (Ledger_builder.hash builder) ) ;
    ()

  let assert_valid_state' (state: Inputs.State.t) builder =
    assert (
      Ledger_builder_hash.equal
        (Inputs.State.ledger_builder_hash state)
        (Ledger_builder.hash builder) ) ;
    ()

  let force_apply_transitions lb transitions =
    Deferred.List.fold ~init:() transitions ~f:(fun () w ->
        let open Deferred.Let_syntax in
        match%map
          Ledger_builder.apply lb w.Transition_with_target.transition
        with
        | Ok None -> ()
        | Ok (Some _) -> ()
        (* We've already verified that all the patches can be
          applied successfully before we added to the ktree, so we
          can force-unwrap here *)
        | Error e ->
            failwithf
              "We should have already verified patches can be applied: %s"
              (Error.to_string_hum e) () )

  let create (config: Config.t) =
    let log = Logger.child config.parent_log "ledger_builder_controller" in
    let storage_controller =
      Store.Controller.create ~parent_log:log [%bin_type_class : State.t]
    in
    let%bind state =
      match%map Store.load storage_controller config.disk_location with
      | Ok state -> state
      | Error (`IO_error e) ->
          Logger.info log "Ledger failed to load from storage %s; recreating"
            (Error.to_string_hum e) ;
          State.create config.genesis_ledger
      | Error `No_exist ->
          Logger.info log "Ledger doesn't exist in storage; recreating" ;
          State.create config.genesis_ledger
      | Error `Checksum_no_match ->
          Logger.warn log "Checksum failed when loading ledger, recreating" ;
          State.create config.genesis_ledger
    in
    let%map net = config.net_deferred in
    let ledger_builder_io = Net.create net in
    (* Here we effectfully listen to transitions and emit what we belive are
       the strongest ledger_builders *)
    let possibly_works =
      Linear_pipe.filter_map_unordered ~max_concurrency:1
        config.ledger_builder_transitions ~f:(fun (_, s, transition) ->
          match state.ktree with
          (* TODO: Initialize this with state we queried from our neighbors,
             see #301 *)
          | None ->
              state.ktree
              <- Some
                   (Transition_with_target_tree.single
                      {transition; target_state= s}) ;
              return None
          | Some old_tree ->
              let witness_to_add : Transition_with_target.t =
                {transition; target_state= s}
              in
              let p_eq_previous_state_hash (w: Transition_with_target.t) =
                State_hash.equal
                  (Transition_with_target.state_hash w)
                  (Transition_with_target.previous_state_hash witness_to_add)
              in
              (* When we get a new transition adjust our ktree *)
              match
                Transition_with_target_tree.add old_tree witness_to_add
                  ~parent:p_eq_previous_state_hash
              with
              | `No_parent ->
                  let best_tip t = locked_and_best t |> snd in
                  if
                    Strength.( > ) (Inputs.State.strength s)
                      (Transition_with_target.strength (best_tip old_tree))
                  then
                    return
                      (Some (`Sync (transition, s), Inputs.State.ledger_hash s))
                  else return None
              | `Repeat -> return None
              | `Added new_tree ->
                  let old_locked_head, old_best_tip =
                    locked_and_best old_tree
                  in
                  let new_head, new_tip = locked_and_best new_tree in
                  (* Adjust the locked_ledger if necessary *)
                  state.ktree <- Some new_tree ;
                  let%map () =
                    if Transition_with_target.equal old_locked_head new_head
                    then return ()
                    else
                      let lb = state.locked_ledger_builder in
                      let%map () = force_apply_transitions lb [new_head] in
                      assert_valid_state new_head lb
                  in
                  (* Push the longest_branch_tip adjustment work if necessary *)
                  let new_best_path =
                    Transition_with_target_tree.longest_path new_tree
                    |> Path.of_tree_path
                  in
                  if Transition_with_target.equal old_best_tip new_tip then
                    None
                  else
                    Some
                      ( `Path_traversal new_best_path
                      , Transition_with_target.ledger_hash new_tip ) )
    in
    let fold_and_interrupt p ~init ~f =
      Linear_pipe.fold p ~init:(None, init) ~f:(fun (w, acc) (a, s) ->
          Option.iter w ~f:(fun w -> Interruptible.interrupt w s) ;
          let w', d, acc' = f (acc, a) in
          let%map () = d in
          (Some w', acc') )
      >>| ignore
    in
    let strongest_ledgers_reader, strongest_ledgers_writer =
      Linear_pipe.create ()
    in
    (* Perform the `Sync interruptible work *)
    let do_sync sl_ref sl transition s =
      let h = Inputs.State.ledger_hash s in
      let open Interruptible.Let_syntax in
      match%bind
        Interruptible.lift
          (Sync_ledger.wait_until_valid sl h)
          (Sync_ledger.new_goal sl)
      with
      | `Ok ledger -> (
          (* TODO: This should be parallelized with the syncing *)
          match%map
            Interruptible.uninterruptible
              (Net.get_ledger_builder_aux_at_hash ledger_builder_io
                 (Inputs.State.ledger_builder_hash s))
            |> Interruptible.local ~f:ignore
          with
          | Ok (aux, _) -> (
            match Ledger_builder.of_aux_and_ledger ledger aux with
            (* TODO: We'll need the full history in order to trust that
               the ledger builder we get is actually valid. See #285 *)
            | Ok lb ->
                let new_tree =
                  Transition_with_target_tree.single
                    {transition; target_state= s}
                in
                state.ktree <- Some new_tree ;
                state.locked_ledger_builder <- lb ;
                Linear_pipe.write_or_exn ~capacity:10 strongest_ledgers_writer
                  strongest_ledgers_reader (lb, s) ;
                Option.iter !sl_ref ~f:Sync_ledger.destroy ;
                sl_ref := None
            | Error e ->
                Logger.info log "Malicious aux data received from net %s"
                  (Error.to_string_hum e) ;
                (* TODO: Retry? *)
                () )
          | Error e ->
              Logger.info log "Network failed to send aux %s"
                (Error.to_string_hum e) ;
              () )
      | `Target_changed -> return ()
    in
    let do_path_traversal new_best_path is_lb_hash_curr_tip =
      let new_tip = new_best_path.Path.path |> List.last_exn in
      (* TODO: Don't mindlessly re-apply non-validated transitions,
          instead remember which sub-paths we've validated, and apply
          those without rechecking the SNARKs (see issue #297)
          validated *)
      let step lb_and_src transition =
        Interruptible.uninterruptible (Step.step lb_and_src transition)
      in
      let best_lb, path =
        match
          Path.findi new_best_path ~f:(fun i tip -> is_lb_hash_curr_tip tip)
        with
        | None ->
            (Ledger_builder.copy state.locked_ledger_builder, new_best_path)
        | Some (i, _) ->
            ( Ledger_builder.copy state.longest_branch_tip
            , Path.drop new_best_path i )
      in
      let open Interruptible.Let_syntax in
      let lb = best_lb in
      let%map result =
        List.fold path.Path.path
          ~init:(Interruptible.return (`Continue None), Path.source path)
          ~f:(fun (work, source_state) curr ->
            let w =
              match%bind work with
              | `Abort -> return `Abort
              | `Continue _ ->
                  match%map
                    step (lb, source_state)
                      curr.Transition_with_target.transition
                  with
                  | Ok next_state ->
                      (* TODO: Should this assertion be here, or should we handle failure with punishment *)
                      assert_valid_state' next_state lb ;
                      assert_valid_state curr lb ;
                      `Continue (Some next_state)
                  | Error e ->
                      (* TODO: Punish sender *)
                      Logger.info log "Recieved malicious transition %s"
                        (Error.to_string_hum e) ;
                      `Abort
            in
            (w, Transition_with_target.target_state curr) )
        |> fst
      in
      match result with
      | `Continue None -> failwith "Impossible"
      | `Continue (Some s) ->
          assert (
            Inputs.State.equal s (Transition_with_target.target_state new_tip)
          ) ;
          state.longest_branch_tip <- lb ;
          Linear_pipe.write_or_exn ~capacity:10 strongest_ledgers_writer
            strongest_ledgers_reader (lb, s)
      | `Abort -> ()
    in
    let d =
      (* TODO: Don't just interrupt blindly, if the work we've done so far is a
         prefix of the new_best_path, resume from that *)
      fold_and_interrupt possibly_works ~init:(ref None) ~f:(function
        | sl_ref, `Sync (transition, s) ->
            let h = Inputs.State.ledger_hash s in
            (* Lazily recreate the sync_ledger if necessary *)
            let sl : Sync_ledger.t =
              match !sl_ref with
              | None ->
                  let ledger =
                    Ledger_builder.ledger state.locked_ledger_builder
                    |> Ledger.copy
                  in
                  let sl = Sync_ledger.create ~goal:h ledger in
                  Net.glue_sync_ledger ledger_builder_io
                    (Sync_ledger.query_reader sl)
                    (Sync_ledger.answer_writer sl) ;
                  sl
              | Some sl -> sl
            in
            let w = do_sync sl_ref sl transition s in
            (w, Deferred.return (), sl_ref)
        | sl_ref, `Path_traversal new_best_path ->
            let curr_tip_hash = Ledger_builder.hash state.longest_branch_tip in
            let is_lb_hash_curr_tip w =
              Ledger_builder_hash.equal curr_tip_hash
                (Transition_with_target.ledger_builder_hash w)
            in
            let w = do_path_traversal new_best_path is_lb_hash_curr_tip in
            (Interruptible.local w ~f:ignore, Deferred.return (), sl_ref) )
    in
    don't_wait_for d ;
    { ledger_builder_io
    ; log= Logger.child config.parent_log "ledger_builder_controller"
    ; strongest_ledgers= strongest_ledgers_reader
    ; state }

  (* TODO: implement this when sync-ledger merges *)
  let handle_sync_ledger_queries query = failwith "TODO"

  let strongest_ledgers {strongest_ledgers} = strongest_ledgers

  (** Returns a reference to a ledger_builder with hash [hash], materialize a
   fresh ledger at a specific hash if necessary *)
  let local_get_ledger t hash =
    let find_state tree lb_hash =
      Transition_with_target_tree.find_map tree ~f:(fun w ->
          if
            Ledger_builder_hash.equal
              (Transition_with_target.ledger_builder_hash w)
              lb_hash
          then Some (Transition_with_target.target_state w)
          else None )
    in
    Option.map t.state.ktree ~f:(fun tree ->
        (* First let's see if we have an easy case *)
        let locked = t.state.locked_ledger_builder in
        let tip = t.state.longest_branch_tip in
        let attempt_easy w err_msg_name =
          match find_state tree (Ledger_builder.hash w) with
          | None ->
              return
              @@ Or_error.errorf
                   "This was our %s, but we didn't witness the state"
                   err_msg_name
          | Some state -> return @@ Ok (w, state)
        in
        if Ledger_builder_hash.equal hash (Ledger_builder.hash locked) then
          attempt_easy locked "locked_head"
        else if Ledger_builder_hash.equal hash (Ledger_builder.hash tip) then
          attempt_easy tip "tip"
        else
          (* Now we need to materialize it *)
          match
            Option.map
              (Transition_with_target_tree.path tree ~f:(fun w ->
                   Ledger_builder_hash.equal hash
                     (Transition_with_target.ledger_builder_hash w) ))
              ~f:Path.of_tree_path
          with
          | Some path ->
              let lb_start = t.state.locked_ledger_builder in
              assert_valid_state' (Path.source path) lb_start ;
              let lb = Ledger_builder.copy lb_start in
              (* Fast-forward the lb *)
              let%map () = force_apply_transitions lb (Path.path path) in
              assert (Ledger_builder_hash.equal (Ledger_builder.hash lb) hash) ;
              Ok
                ( lb
                , List.last_exn (Path.path path)
                  |> Transition_with_target.target_state )
          | None -> return (Or_error.error_string "Hash not found locally") )
    |> Option.value
         ~default:(return @@ Or_error.error_string "Haven't seen any nodes yet")
end

let%test_module "test" =
  ( module struct
    module Inputs = struct
      module Ledger_builder_hash = Int
      module Ledger_hash = Int
      (* A ledger_builder transition will just add to a "ledger" integer *)
      module Ledger_builder_transition = Int

      module Ledger = struct
        include Int

        let merkle_root t = t

        let copy t = t
      end

      module Ledger_builder = struct
        type t = int ref [@@deriving eq, sexp, bin_io]

        type aux_data = int [@@deriving bin_io]

        type proof = ()

        let ledger t = !t

        let create x = ref x

        let copy t = ref !t

        let hash t = !t

        let of_aux_and_ledger aux l = Ok (create l)

        let apply (t: t) (x: Ledger_builder_transition.t) =
          t := x ;
          return (Ok (Some (x, ())))
      end

      module State_hash = Int
      module Strength = Int

      module State = struct
        type t =
          { ledger_builder_hash: Ledger_builder_hash.t
          ; hash: State_hash.t
          ; strength: Strength.t
          ; previous_state_hash: State_hash.t
          ; ledger_hash: Ledger_hash.t }
        [@@deriving eq, sexp, compare, bin_io, fields]
      end

      (* Not sure if we even need this *)
      module Valid_transaction = Int

      module Net = struct
        type t = State.t State_hash.Table.t

        type net = State.t list

        let create states =
          let tbl = State_hash.Table.create () in
          List.iter states ~f:(fun s ->
              State_hash.Table.add_exn tbl ~key:(State.hash s) ~data:s ) ;
          tbl

        let get_ledger_builder_aux_at_hash t hash =
          return (Ok (hash, State_hash.Table.find_exn t hash))

        let glue_sync_ledger t q a =
          don't_wait_for
            (Linear_pipe.iter q ~f:(fun (h, _) -> Linear_pipe.write a (h, h)))
      end

      module Sync_ledger = struct
        type answer = Ledger.t [@@deriving bin_io]

        type query = unit [@@deriving bin_io]

        type t =
          { mutable ledger: Ledger.t
          ; answer_pipe:
              (Ledger_hash.t * answer) Linear_pipe.Reader.t
              * (Ledger_hash.t * answer) Linear_pipe.Writer.t
          ; query_pipe:
              (Ledger_hash.t * query) Linear_pipe.Reader.t
              * (Ledger_hash.t * query) Linear_pipe.Writer.t }

        let create ledger ~goal =
          let t =
            { ledger
            ; answer_pipe= Linear_pipe.create ()
            ; query_pipe= Linear_pipe.create () }
          in
          don't_wait_for
            (Linear_pipe.iter (fst t.answer_pipe) ~f:(fun (h, l) ->
                 t.ledger <- h ;
                 Deferred.return () )) ;
          t

        let answer_writer {answer_pipe} = snd answer_pipe

        let query_reader {query_pipe} = fst query_pipe

        let destroy t = ()

        let new_goal t h = ()

        let wait_until_valid t h = return (`Ok t.ledger)
      end

      module Store = Storage.Memory

      module State_with_proof_checked = struct
        type t = {state: State.t}
        [@@deriving fields, bin_io, compare, eq, sexp]
      end

      module Step = struct
        (* This checks the SNARKs in State/LB and does the transition *)

        let step (lb, state) transition =
          let open Deferred.Or_error.Let_syntax in
          let%bind _proof_option = Ledger_builder.apply lb transition in
          Deferred.Or_error.return
          @@ { State.ledger_builder_hash= !lb
             ; hash= !lb
             ; strength= state.State.strength + 1
             ; previous_state_hash= State.hash state
             ; ledger_hash= !lb }
      end
    end

    module Lbc = Make (Inputs)

    let transition x parent strength =
      ( []
      , { Inputs.State.ledger_builder_hash= x
        ; hash= x
        ; strength
        ; ledger_hash= x
        ; previous_state_hash= parent }
      , x )

    let slowly_pipe_of_list xs =
      let r, w = Linear_pipe.create () in
      don't_wait_for
        (Deferred.List.iter xs ~f:(fun x ->
             (* Without the wait here, we get interrupted before doing anything interesting *)
             let%bind () = after (Time_ns.Span.of_ms 100.) in
             Linear_pipe.write w x )) ;
      r

    let config transitions =
      let ledger_builder_transitions = slowly_pipe_of_list transitions in
      let net_input = List.map transitions ~f:(fun (_, s, _) -> s) in
      Lbc.Config.make ~parent_log:(Logger.create ())
        ~net_deferred:(return net_input) ~ledger_builder_transitions
        ~genesis_ledger:0 ~disk_location:"/tmp/test_lbc_disk"

    let take_map ~f p cnt =
      let rec go acc cnt =
        if cnt = 0 then return acc
        else
          match%bind Linear_pipe.read p with
          | `Eof -> return acc
          | `Ok x -> go (f x :: acc) (cnt - 1)
      in
      go [] cnt >>| List.rev

    let assert_strongest_ledgers lbc_deferred ~transitions ~expected =
      Backtrace.elide := false ;
      let res =
        Async.Thread_safe.block_on_async (fun () ->
            let%bind lbc = lbc_deferred in
            let%map results =
              take_map (Lbc.strongest_ledgers lbc) (List.length expected) ~f:
                (fun (lb, _) -> !lb )
            in
            assert (List.equal results expected ~equal:Int.equal) )
      in
      match res with
      | Ok () -> ()
      | Error e -> printf !"Got exn %s\n%!" (Exn.to_string e)

    let%test_unit "strongest_ledgers updates appropriately when new_states \
                   flow in within tree" =
      let transitions =
        let f = transition in
        [ f 0 (-1) 0
        ; f 1 0 1
        ; f 2 1 2
        ; f 3 0 1
        ; f 4 0 1
        ; f 5 2 3
        ; f 6 1 2
        ; f 7 5 4 ]
      in
      let config = config transitions in
      assert_strongest_ledgers (Lbc.create config) ~transitions
        ~expected:[1; 2; 5; 7]

    let%test_unit "strongest_ledgers updates appropriately using the network" =
      let transitions =
        let f = transition in
        [ f 0 (-1) 0
        ; f 1 0 1
        ; f 2 1 2
        ; f 3 8 6 (* This one comes over the network *)
        ; f 4 2 3
          (* Here this would have extended, if we didn't kill the tree *)
        ; f 5 3 7
        (* Now we attach to the one from the network *) ]
      in
      let config = config transitions in
      let lbc_deferred = Lbc.create config in
      assert_strongest_ledgers lbc_deferred ~transitions ~expected:[1; 2; 3; 5]

    let%test_unit "local_get_ledger can materialize a ledger locally" =
      Backtrace.elide := false ;
      let transitions =
        let f = transition in
        [ f 0 (-1) 0
        ; f 1 0 1
        ; f 2 1 2
        ; f 3 0 1
        ; f 4 0 1
        ; f 5 2 3
        ; f 6 1 2
        ; f 7 5 4 ]
      in
      let config = config transitions in
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind lbc = Lbc.create config in
          (* Drain the first few strongest_ledgers *)
          let%bind _ = take_map (Lbc.strongest_ledgers lbc) 4 ~f:ignore in
          match%map Lbc.local_get_ledger lbc 6 with
          | Ok (lb, s) -> assert (!lb = 6)
          | Error e ->
              failwithf "Unexpected error %s" (Error.to_string_hum e) () )
  end )
