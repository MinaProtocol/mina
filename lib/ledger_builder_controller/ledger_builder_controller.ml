open Core_kernel
open Async_kernel

module type Inputs_intf = sig
  module Ledger_builder_hash : sig
    type t [@@deriving eq, bin_io]
  end

  module Ledger_hash : sig
    type t [@@deriving bin_io]
  end

  module Ledger_builder_diff : sig
    type t [@@deriving sexp, bin_io]
  end

  module Internal_transition : sig
    type t [@@deriving sexp]
  end

  module Ledger : sig
    type t

    val copy : t -> t

    val merkle_root : t -> Ledger_hash.t
  end

  module Ledger_builder : sig
    type t [@@deriving bin_io]

    type proof

    module Aux : sig
      type t [@@deriving bin_io]
    end

    val ledger : t -> Ledger.t

    val create : Ledger.t -> t

    val of_aux_and_ledger : Ledger.t -> Aux.t -> t Or_error.t

    val copy : t -> t

    val hash : t -> Ledger_builder_hash.t

    val apply :
         t
      -> Ledger_builder_diff.t
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

    module Proof : sig
      type t [@@deriving bin_io]
    end
  end

  module Tip :
    Protocols.Coda_pow.Tip_intf
    with type ledger_builder := Ledger_builder.t
     and type state := State.t
     and type state_proof := State.Proof.t

  module External_transition : sig
    type t [@@deriving bin_io, eq, compare, sexp]

    val state : t -> State.t

    val state_proof : t -> State.Proof.t

    val ledger_builder_diff : t -> Ledger_builder_diff.t
  end

  module Valid_transaction : sig
    type t [@@deriving eq, sexp, compare, bin_io]
  end

  module Sync_ledger : sig
    type t

    type answer [@@deriving bin_io]

    type query [@@deriving bin_io]

    val create : Ledger.t -> Ledger_hash.t -> t

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
      -> External_transition.t
      -> State.t Deferred.Or_error.t
  end

  module Net : sig
    include Coda.Ledger_builder_io_intf
            with type sync_ledger_query := Sync_ledger.query
             and type sync_ledger_answer := Sync_ledger.answer
             and type ledger_builder_hash := Ledger_builder_hash.t
             and type ledger_builder_aux := Ledger_builder.Aux.t
             and type ledger_hash := Ledger_hash.t
             and type state := State.t
  end

  module Store : Storage.With_checksum_intf
end

module Make (Inputs : Inputs_intf) : sig
  include Coda.Ledger_builder_controller_intf
          with type ledger_builder := Inputs.Ledger_builder.t
           and type ledger_builder_hash := Inputs.Ledger_builder_hash.t
           and type internal_transition := Inputs.Internal_transition.t
           and type ledger := Inputs.Ledger.t
           and type ledger_proof := Inputs.Ledger_builder.proof
           and type net := Inputs.Net.net
           and type state := Inputs.State.t
           and type ledger_hash := Inputs.Ledger_hash.t
           and type sync_query := Inputs.Sync_ledger.query
           and type sync_answer := Inputs.Sync_ledger.answer
           and type external_transition := Inputs.External_transition.t
           and type tip := Inputs.Tip.t

  val ledger_builder_io : t -> Inputs.Net.t
end = struct
  open Inputs

  module Config = struct
    type t =
      { parent_log: Logger.t
      ; net_deferred: Net.net Deferred.t
      ; external_transitions: External_transition.t Linear_pipe.Reader.t
      ; genesis_tip: Tip.t
      ; disk_location: string }
    [@@deriving make]
  end

  module External_transition = struct
    include External_transition
    open State

    let target_state = state

    let ledger_builder_hash t = state t |> ledger_builder_hash

    let ledger_hash t = state t |> ledger_hash

    let state_hash t = state t |> hash

    let strength t = state t |> strength

    let previous_state_hash t = state t |> previous_state_hash
  end

  let assert_valid_state (witness: External_transition.t) builder =
    assert (
      Ledger_builder_hash.equal
        (External_transition.ledger_builder_hash witness)
        (Ledger_builder.hash builder) ) ;
    ()

  let assert_valid_state' (state: Inputs.State.t) builder =
    assert (
      Ledger_builder_hash.equal
        (Inputs.State.ledger_builder_hash state)
        (Ledger_builder.hash builder) ) ;
    ()

  module Handler_state = Handler0.Make (Tip) (External_transition)

  module Transition_logic_inputs = struct
    module State = struct
      type hash = State_hash.t

      include State
    end

    module Transition = struct
      include External_transition

      let is_parent_of ~child ~parent =
        State_hash.equal
          (External_transition.state_hash parent)
          (External_transition.previous_state_hash child)
    end

    module Heavy = struct
      include Tip

      let state tip = tip.state

      let copy t = {t with ledger_builder= Ledger_builder.copy t.ledger_builder}

      let transition_unchecked t transition =
        let%map () =
          let open Deferred.Let_syntax in
          match%map
            Ledger_builder.apply t.ledger_builder
              (Transition.ledger_builder_diff transition)
          with
          | Ok None -> ()
          | Ok (Some _) -> ()
          (* We've already verified that all the patches can be
            applied successfully before we added to the ktree, so we
            can force-unwrap here *)
          | Error e ->
              failwithf
                "We should have already verified patches can be applied: %s"
                (Error.to_string_hum e) ()
        in
        assert_valid_state transition t.ledger_builder ;
        { t with
          state= Transition.target_state transition
        ; proof= Transition.state_proof transition }

      let is_parent_of ~child ~parent =
        State_hash.equal
          (Inputs.State.hash (state parent))
          (Transition.previous_state_hash child)

      let is_materialization_of t transition =
        State_hash.equal
          (Inputs.State.hash (state t))
          (Inputs.State.hash (Transition.target_state transition))
    end

    module Handler_state = Handler0.Make (Tip) (Transition)

    module Step = struct
      let step (heavy: Heavy.t) transition =
        let open Deferred.Or_error.Let_syntax in
        let%map state =
          Step.step (heavy.ledger_builder, heavy.state) transition
        in
        {heavy with state; proof= Transition.state_proof transition}
    end

    module Select = struct
      let select s1 s2 =
        if Strength.( > ) (State.strength s1) (State.strength s2) then s1
        else s2
    end

    (* TODO: Move this logic to a separate Catchup module in a later PR *)
    module Catchup = struct
      type t = {net: Net.t; log: Logger.t; sl_ref: Sync_ledger.t option ref}

      let create net parent_log =
        {net; log= Logger.child parent_log __MODULE__; sl_ref= ref None}

      (* Perform the `Sync interruptible work *)
      let do_sync {net; log; sl_ref} (state: Handler_state.t) transition =
        let h = Transition.ledger_hash transition in
        (* Lazily recreate the sync_ledger if necessary *)
        let sl : Sync_ledger.t =
          match !sl_ref with
          | None ->
              let ledger =
                Ledger_builder.ledger state.locked_tip.ledger_builder
                |> Ledger.copy
              in
              let sl = Sync_ledger.create ledger h in
              Net.glue_sync_ledger net
                (Sync_ledger.query_reader sl)
                (Sync_ledger.answer_writer sl) ;
              sl_ref := Some sl ;
              sl
          | Some sl -> sl
        in
        let open Interruptible.Let_syntax in
        let ivar : Transition.t Ivar.t = Ivar.create () in
        let work =
          match%bind
            Interruptible.lift
              (Sync_ledger.wait_until_valid sl h)
              (Deferred.map (Ivar.read ivar) ~f:(fun transition ->
                   Sync_ledger.new_goal sl (Transition.ledger_hash transition) ;
                   transition ))
          with
          | `Ok ledger -> (
              (* TODO: This should be parallelized with the syncing *)
              match%map
                Interruptible.uninterruptible
                  (Net.get_ledger_builder_aux_at_hash net
                     (External_transition.ledger_builder_hash transition))
              with
              | Ok aux -> (
                match Ledger_builder.of_aux_and_ledger ledger aux with
                (* TODO: We'll need the full history in order to trust that
                   the ledger builder we get is actually valid. See #285 *)
                | Ok lb ->
                    let new_tree =
                      Handler_state.Transition_tree.single transition
                    in
                    sl_ref := None ;
                    Option.iter !sl_ref ~f:Sync_ledger.destroy ;
                    let new_heavy =
                      { Heavy.ledger_builder= lb
                      ; state= External_transition.target_state transition
                      ; proof= External_transition.state_proof transition }
                    in
                    let open Handler_state.Change in
                    [ Ktree new_tree
                    ; Locked_tip new_heavy
                    ; Longest_branch_tip new_heavy ]
                | Error e ->
                    Logger.info log "Malicious aux data received from net %s"
                      (Error.to_string_hum e) ;
                    (* TODO: Retry? see #361 *)
                    [] )
              | Error e ->
                  Logger.info log "Network failed to send aux %s"
                    (Error.to_string_hum e) ;
                  [] )
          | `Target_changed -> return []
        in
        (work, ivar)

      let sync (t: t) (state: Handler_state.t) transition =
        (transition, do_sync t state)
    end
  end

  module Transition_logic = Transition_logic.Make (Transition_logic_inputs)
  open Transition_logic_inputs

  type t =
    { ledger_builder_io: Net.t
    ; log: Logger.t
    ; mutable handler: Transition_logic.t
    ; strongest_ledgers:
        (Ledger_builder.t * External_transition.t) Linear_pipe.Reader.t }

  let strongest_tip t =
    let state = Transition_logic.state t.handler in
    state.Handler_state.longest_branch_tip

  let ledger_builder_io {ledger_builder_io; _} = ledger_builder_io

  let force_apply_transitions lb transitions =
    Deferred.List.fold ~init:() transitions ~f:(fun () w ->
        let open Deferred.Let_syntax in
        match%map
          Ledger_builder.apply lb (External_transition.ledger_builder_diff w)
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
      Store.Controller.create ~parent_log:log
        [%bin_type_class : Handler_state.t]
    in
    let%bind state =
      match%map Store.load storage_controller config.disk_location with
      | Ok state -> state
      | Error (`IO_error e) ->
          Logger.info log "Ledger failed to load from storage %s; recreating"
            (Error.to_string_hum e) ;
          Handler_state.create config.genesis_tip
      | Error `No_exist ->
          Logger.info log "Ledger doesn't exist in storage; recreating" ;
          Handler_state.create config.genesis_tip
      | Error `Checksum_no_match ->
          Logger.warn log "Checksum failed when loading ledger, recreating" ;
          Handler_state.create config.genesis_tip
    in
    let%map net = config.net_deferred in
    let net = Net.create net in
    let catchup = Catchup.create net log in
    (* Here we effectfully listen to transitions and emit what we belive are
       the strongest ledger_builders *)
    let strongest_ledgers_reader, strongest_ledgers_writer =
      Linear_pipe.create ()
    in
    let t =
      { ledger_builder_io= net
      ; log= Logger.child config.parent_log "ledger_builder_controller"
      ; strongest_ledgers= strongest_ledgers_reader
      ; handler= Transition_logic.create state log }
    in
    let mutate_state_reader, mutate_state_writer = Linear_pipe.create () in
    (* The mutation "thread" *)
    don't_wait_for
      (Linear_pipe.iter mutate_state_reader ~f:(fun (changes, transition) ->
           let old_state = Transition_logic.state t.handler in
           (* TODO: We can make change-resolving more intelligent if different
         * concurrent processes took different times to finish. Since we
         * serialize to one job at a time this shouldn't happen anyway though *)
           let new_state = Handler_state.apply_all old_state changes in
           t.handler <- Transition_logic.create new_state log ;
           ( if
               not
                 (State.equal old_state.longest_branch_tip.Tip.state
                    new_state.longest_branch_tip.Tip.state)
             then
               let lb = new_state.longest_branch_tip.Tip.ledger_builder in
               Linear_pipe.write_or_exn ~capacity:5 strongest_ledgers_writer
                 strongest_ledgers_reader (lb, transition) ) ;
           Store.store storage_controller config.disk_location new_state )) ;
    (* Handle new transitions *)
    let possibly_jobs =
      Linear_pipe.filter_map_unordered ~max_concurrency:1
        config.external_transitions ~f:(fun transition ->
          let%bind changes, job =
            Transition_logic.on_new_transition catchup t.handler transition
          in
          let%map () =
            match changes with
            | [] -> return ()
            | changes ->
                Linear_pipe.write mutate_state_writer (changes, transition)
          in
          job )
    in
    don't_wait_for
      ( Linear_pipe.fold possibly_jobs ~init:None ~f:(fun last job ->
            Option.iter last ~f:(fun (input, ivar) ->
                Ivar.fill_if_empty ivar input ) ;
            let this_input, _ = job in
            let w, this_ivar = Job.run job in
            let%bind () =
              Deferred.bind w.Interruptible.d ~f:(function
                | Ok [] -> return ()
                | Ok changes ->
                    Linear_pipe.write mutate_state_writer (changes, this_input)
                | Error _ -> return () )
            in
            return (Some (this_input, this_ivar)) )
      >>| ignore ) ;
    t

  (* TODO: implement this when sync-ledger merges *)
  let handle_sync_ledger_queries _query = failwith "TODO"

  let strongest_ledgers {strongest_ledgers; _} = strongest_ledgers

  (** Returns a reference to a ledger_builder with hash [hash], materialize a
   fresh ledger at a specific hash if necessary; also gives back target_state *)
  let local_get_ledger t hash =
    let open Deferred.Or_error.Let_syntax in
    let%map heavy, state =
      Transition_logic.local_get_heavy t.handler
        ~p_heavy:(fun heavy ->
          Ledger_builder_hash.equal
            (Ledger_builder.hash heavy.Tip.ledger_builder)
            hash )
        ~p_trans:(fun trans ->
          Ledger_builder_hash.equal
            (External_transition.ledger_builder_hash trans)
            hash )
    in
    (heavy.Tip.ledger_builder, state)
end

let%test_module "test" =
  ( module struct
    module Inputs = struct
      module Ledger_builder_hash = Int
      module Ledger_hash = Int
      (* A ledger_builder transition will just add to a "ledger" integer *)
      module Ledger_builder_diff = Int

      module Ledger = struct
        include Int

        let merkle_root t = t

        let copy t = t
      end

      module Ledger_builder = struct
        type t = int ref [@@deriving eq, sexp, bin_io]

        module Aux = struct
          type t = int [@@deriving bin_io]
        end

        type proof = ()

        let ledger t = !t

        let create x = ref x

        let copy t = ref !t

        let hash t = !t

        let of_aux_and_ledger _aux l = Ok (create l)

        let apply (t: t) (x: Ledger_builder_diff.t) =
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

        let genesis =
          { ledger_builder_hash= 0
          ; hash= 0
          ; strength= 0
          ; previous_state_hash= 0
          ; ledger_hash= 0 }

        module Proof = Unit
      end

      module Tip = struct
        type t =
          { state: State.t
          ; proof: State.Proof.t
          ; ledger_builder: Ledger_builder.t }
        [@@deriving bin_io, sexp, fields]
      end

      module External_transition = struct
        include State

        let state = Fn.id

        let ledger_builder_diff = State.hash

        let state_proof _ = ()
      end

      module Internal_transition = External_transition
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

        let get_ledger_builder_aux_at_hash _t hash = return (Ok hash)

        let glue_sync_ledger _t q a =
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

        let create ledger _goal =
          let t =
            { ledger
            ; answer_pipe= Linear_pipe.create ()
            ; query_pipe= Linear_pipe.create () }
          in
          don't_wait_for
            (Linear_pipe.iter (fst t.answer_pipe) ~f:(fun (h, _l) ->
                 t.ledger <- h ;
                 Deferred.return () )) ;
          t

        let answer_writer {answer_pipe; _} = snd answer_pipe

        let query_reader {query_pipe; _} = fst query_pipe

        let destroy _t = ()

        let new_goal _t _h = ()

        let wait_until_valid t _h = return (`Ok t.ledger)
      end

      module Store = Storage.Memory

      module Step = struct
        (* This checks the SNARKs in State/LB and does the transition *)

        let step (lb, state) transition =
          let open Deferred.Or_error.Let_syntax in
          let%bind _proof_option =
            Ledger_builder.apply lb
              (External_transition.ledger_builder_diff transition)
          in
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
      { Inputs.External_transition.ledger_builder_hash= x
      ; hash= x
      ; strength
      ; ledger_hash= x
      ; previous_state_hash= parent }

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
      let net_input = transitions in
      Lbc.Config.make ~parent_log:(Logger.create ())
        ~net_deferred:(return net_input)
        ~external_transitions:ledger_builder_transitions
        ~genesis_tip:
          { state= Inputs.State.genesis
          ; proof= ()
          ; ledger_builder= Inputs.Ledger_builder.create 0 }
        ~disk_location:"/tmp/test_lbc_disk"

    let take_map ~f p cnt =
      let rec go acc cnt =
        if cnt = 0 then return acc
        else
          match%bind Linear_pipe.read p with
          | `Eof -> return acc
          | `Ok x -> go (f x :: acc) (cnt - 1)
      in
      let d = go [] cnt >>| List.rev in
      Deferred.any
        [ d
        ; (Async.after (Time.Span.of_sec 3.) >>| fun () -> failwith "Timeout")
        ]

    let assert_strongest_ledgers lbc_deferred ~transitions:_ ~expected =
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
        ~expected:[0; 1; 2; 5; 7]

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
      assert_strongest_ledgers lbc_deferred ~transitions
        ~expected:[0; 1; 2; 3; 5]

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
          let%bind _ = take_map (Lbc.strongest_ledgers lbc) 5 ~f:ignore in
          match%map Lbc.local_get_ledger lbc 6 with
          | Ok (lb, _s) -> assert (!lb = 6)
          | Error e ->
              failwithf "Unexpected error %s" (Error.to_string_hum e) () )
  end )
