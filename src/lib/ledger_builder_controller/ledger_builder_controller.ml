open Core_kernel
open Async_kernel
open Pipe_lib
open O1trace

module Make (Inputs : Inputs.S) : sig
  open Inputs

  include
    Coda_lib.Ledger_builder_controller_intf
    with type staged_ledger := Staged_ledger.t
     and type staged_ledger_hash := Staged_ledger_hash.t
     and type ledger := Ledger.t
     and type maskable_ledger := Ledger.maskable_ledger
     and type ledger_proof := Ledger_proof.t
     and type net := Net.net
     and type protocol_state := Consensus_mechanism.Protocol_state.value
     and type ledger_hash := Ledger_hash.t
     and type sync_query := Sync_ledger.query
     and type sync_answer := Sync_ledger.answer
     and type external_transition := External_transition.t
     and type consensus_local_state := Consensus_mechanism.Local_state.t
     and type tip := Tip.t
     and type public_key_compressed := Public_key.Compressed.t

  val staged_ledger_io : t -> Net.t
end = struct
  open Inputs
  open Consensus_mechanism

  module Config = struct
    type t =
      { parent_log: Logger.t
      ; net_deferred: Net.net Deferred.t
      ; external_transitions:
          (External_transition.t * Unix_timestamp.t) Linear_pipe.Reader.t
      ; genesis_tip: Tip.t
      ; ledger: Ledger.maskable_ledger
      ; consensus_local_state: Consensus_mechanism.Local_state.t
      ; proposer_public_key: Public_key.Compressed.t option
      ; longest_tip_location: string }
    [@@deriving make]
  end

  module Transition_logic_inputs = struct
    include Inputs

    module Step = struct
      let apply' t diff logger =
        let open Deferred.Or_error.Let_syntax in
        let%map _, `Ledger_proof proof = Staged_ledger.apply t diff ~logger in
        Option.map proof ~f:(fun proof ->
            ( Ledger_proof.statement proof |> Ledger_proof_statement.target
            , proof ) )

      let step logger {With_hash.data= tip; hash= tip_hash}
          {With_hash.data= transition; hash= transition_target_hash} =
        let open Deferred.Or_error.Let_syntax in
        let old_state = tip.Tip.state in
        let new_state = External_transition.protocol_state transition in
        let%bind verified =
          verify_blockchain
            (External_transition.protocol_state_proof transition)
            new_state
        in
        let%bind ledger_hash =
          match%map
            apply' tip.staged_ledger
              (External_transition.staged_ledger_diff transition)
              logger
          with
          | Some (h, _) -> h
          | None ->
              old_state |> Protocol_state.blockchain_state
              |> Blockchain_state.ledger_hash
        in
        let staged_ledger_hash = Staged_ledger.hash tip.staged_ledger in
        let%map () =
          if
            verified
            && Staged_ledger_hash.equal staged_ledger_hash
                 ( new_state |> Protocol_state.blockchain_state
                 |> Blockchain_state.staged_ledger_hash )
            && Frozen_ledger_hash.equal ledger_hash
                 ( new_state |> Protocol_state.blockchain_state
                 |> Blockchain_state.ledger_hash )
            && State_hash.equal tip_hash
                 (new_state |> Protocol_state.previous_state_hash)
          then Deferred.return (Ok ())
          else Deferred.Or_error.error_string "TODO: Punish"
        in
        { With_hash.data=
            { tip with
              state= new_state
            ; proof= External_transition.protocol_state_proof transition }
        ; hash= transition_target_hash }
    end

    module Transition_logic_state = Transition_logic_state.Make (Inputs)

    module Catchup = Catchup.Make (struct
      include Inputs
      module Transition_logic_state = Transition_logic_state
    end)
  end

  module Transition_logic = Transition_logic.Make (Transition_logic_inputs)
  open Transition_logic_inputs

  (** For tests *)
  module Transition_tree = Transition_logic_state.Transition_tree

  type t =
    { staged_ledger_io: Net.t
    ; log: Logger.t
    ; handler: Transition_logic.t
    ; strongest_ledgers_reader:
        (Staged_ledger.t * External_transition.t) Linear_pipe.Reader.t }

  let strongest_tip t =
    let state = Transition_logic.state t.handler in
    Transition_logic_state.assert_state_valid state ;
    Transition_logic_state.longest_branch_tip state |> With_hash.data

  let staged_ledger_io {staged_ledger_io; _} = staged_ledger_io

  let load_tip_and_genesis_hash {Config.genesis_tip; _} log =
    let genesis_state_hash = Protocol_state.hash genesis_tip.state in
    Logger.info log
      "TODO: re-implement serialization File for ledger builder controller \
       tip does not exist. Using Genesis tip" ;
    {With_hash.data= genesis_tip; hash= genesis_state_hash}

  let create (config : Config.t) =
    let log = Logger.child config.parent_log "ledger_builder_controller" in
    let genesis_tip_state_hash =
      Protocol_state.hash config.genesis_tip.state
    in
    let {With_hash.data= tip; hash= stored_genesis_state_hash} =
      load_tip_and_genesis_hash config log
    in
    let tip =
      if State_hash.equal genesis_tip_state_hash stored_genesis_state_hash then
        tip
      else (
        Logger.warn log "HARD RESET DETECTED: reseting to new blockchain" ;
        config.genesis_tip )
    in
    let state =
      Transition_logic_state.create
        ?proposer_public_key:config.proposer_public_key
        ~consensus_local_state:config.consensus_local_state
        (With_hash.of_data tip ~hash_data:(fun tip ->
             tip.Tip.state |> Protocol_state.hash ))
    in
    let%map net = config.net_deferred in
    let net = Net.create net in
    let catchup = Catchup.create ~net ~parent_log:log in
    (* Here we effectfully listen to transitions and emit what we believe are
       the strongest staged_ledgers *)
    let strongest_ledgers_reader, strongest_ledgers_writer =
      Linear_pipe.create ()
    in
    let t =
      { staged_ledger_io= net
      ; log
      ; strongest_ledgers_reader
      ; handler= Transition_logic.create state log }
    in
    don't_wait_for
    @@ trace_task "strongest_tip" (fun () ->
           Linear_pipe.iter (Transition_logic.strongest_tip t.handler)
             ~f:(fun (tip, transition) ->
               Deferred.return
               @@ Linear_pipe.write_or_exn ~capacity:5 strongest_ledgers_writer
                    t.strongest_ledgers_reader
                    (tip.staged_ledger, transition) ) ) ;
    (* Handle new transitions *)
    let possibly_jobs =
      trace_task "external transitions" (fun () ->
          Linear_pipe.filter_map_unordered ~max_concurrency:1
            config.external_transitions ~f:(fun (transition, time_received) ->
              let transition_with_hash =
                With_hash.of_data transition ~hash_data:(fun t ->
                    t |> External_transition.protocol_state
                    |> Protocol_state.hash )
              in
              let%map job =
                Transition_logic.on_new_transition catchup t.handler
                  transition_with_hash ~time_received
              in
              Option.map job ~f:(fun job -> (job, time_received)) ) )
    in
    let replace last
        ( {Job.input= {With_hash.data= current_transition; hash= _}; _}
        , time_received ) =
      match last with
      | None -> `Cancel_and_do_next
      | Some last -> (
          let {With_hash.data= last_transition; _}, _ = last in
          match
            Consensus_mechanism.select
              ~existing:
                (Protocol_state.consensus_state
                   (External_transition.protocol_state last_transition))
              ~candidate:
                (Protocol_state.consensus_state
                   (External_transition.protocol_state current_transition))
              ~logger:log ~time_received
          with
          | `Keep -> `Skip
          | `Take -> `Cancel_and_do_next )
    in
    don't_wait_for
    @@ trace_task "possible jobs" (fun () ->
           Linear_pipe.fold possibly_jobs ~init:None
             ~f:(fun last
                ( (({Job.input= current_transition_with_hash; _} as job), _) as
                job_with_time )
                ->
               Deferred.return
                 ( match replace last job_with_time with
                 | `Skip -> last
                 | `Cancel_and_do_next ->
                     Option.iter last ~f:(fun (input, ivar) ->
                         Ivar.fill_if_empty ivar input ) ;
                     trace_event "running a job" ;
                     let w, this_ivar = Job.run job in
                     let () =
                       Deferred.upon w.Interruptible.d (function
                         | Ok () -> Logger.trace log "Job is completed"
                         | Error () -> Logger.trace log "Job is destroyed" )
                     in
                     Some (current_transition_with_hash, this_ivar) ) )
           >>| ignore ) ;
    t

  module For_tests = struct
    let load_tip t config =
      let open With_hash in
      let open Deferred.Let_syntax in
      let%map {data= tip; _} =
        Deferred.return (load_tip_and_genesis_hash config t.log)
      in
      tip
  end

  let strongest_ledgers {strongest_ledgers_reader; _} =
    strongest_ledgers_reader

  let local_get_ledger' t hash ~p_tip ~p_trans ~f_result =
    let open Deferred.Or_error.Let_syntax in
    let%map tip, state =
      Transition_logic.local_get_tip t.handler ~p_tip:(p_tip hash)
        ~p_trans:(p_trans hash)
    in
    (f_result tip, state)

  (** Returns a reference to a staged_ledger with hash [hash], materialize a
   fresh ledger at a specific hash if necessary; also gives back target_state *)
  let local_get_ledger t hash =
    Logger.trace t.log
      !"Attempting to local-get-ledger for %{sexp: Staged_ledger_hash.t}"
      hash ;
    local_get_ledger' t hash
      ~p_tip:(fun hash {With_hash.data= tip; hash= _} ->
        Staged_ledger_hash.equal
          (Staged_ledger.hash tip.Tip.staged_ledger)
          hash )
      ~p_trans:(fun hash {With_hash.data= trans; hash= _} ->
        Staged_ledger_hash.equal
          ( trans |> External_transition.protocol_state
          |> Protocol_state.blockchain_state
          |> Blockchain_state.staged_ledger_hash )
          hash )
      ~f_result:(fun {With_hash.data= tip; hash= _} -> tip.Tip.staged_ledger)

  let prev_hash = ref None

  let prev_ledger = ref None

  let handle_sync_ledger_queries :
         t
      -> Ledger_hash.t * Sync_ledger.query
      -> (Ledger_hash.t * Sync_ledger.answer) Deferred.Or_error.t =
   fun t (hash, query) ->
    (* TODO: this caching shouldn't be necessary *)
    trace_recurring_task "answer sync query" (fun () ->
        let open Deferred.Or_error.Let_syntax in
        Logger.trace t.log
          !"Attempting to handle a sync-ledger query for %{sexp: Ledger_hash.t}"
          hash ;
        let%map ledger =
          if Option.equal Ledger_hash.equal (Some hash) !prev_hash then
            return (Option.value_exn !prev_ledger)
          else
            let%map ll =
              local_get_ledger' t hash
                ~p_tip:(fun hash {With_hash.data= tip; hash= _} ->
                  Ledger_hash.equal
                    ( tip.Tip.staged_ledger |> Staged_ledger.ledger
                    |> Ledger.merkle_root )
                    hash )
                ~p_trans:(fun hash {With_hash.data= trans; hash= _} ->
                  Ledger_hash.equal
                    ( trans |> External_transition.protocol_state
                    |> Protocol_state.blockchain_state
                    |> Blockchain_state.staged_ledger_hash
                    |> Staged_ledger_hash.ledger_hash )
                    hash )
                ~f_result:(fun {With_hash.data= tip; hash= _} ->
                  tip.Tip.staged_ledger |> Staged_ledger.ledger )
              >>| fst
            in
            prev_hash := Some hash ;
            prev_ledger := Some ll ;
            ll
        in
        trace_event "local ledger get" ;
        let responder = Sync_ledger.Responder.create ledger ignore in
        (hash, Sync_ledger.Responder.answer_query responder query) )
end

let%test_module "test" =
  ( module struct
    open Core
    open Async

    module Make_test
        (Store : Storage.With_checksum_intf with type location = string) =
    struct
      module Inputs = struct
        module Security = struct
          let max_depth = `Finite 50
        end

        module Ledger_hash = Int
        module Frozen_ledger_hash = Int

        module Ledger_proof_statement = struct
          type t = Frozen_ledger_hash.t

          let target t = t
        end

        module Ledger_proof = struct
          type t = Ledger_proof_statement.t

          let statement t = t
        end

        module Private_key = struct
          type t = unit
        end

        module Public_key = struct
          module Private_key = Private_key

          module Compressed = struct
            module T = struct
              type t = unit [@@deriving compare, sexp, bin_io]
            end

            include T
            include Comparable.Make (T)
          end

          type t = unit [@@deriving sexp]

          let compress t = t

          let of_private_key_exn t = t
        end

        module Staged_ledger_hash = struct
          include Int

          let ledger_hash = Fn.id
        end

        (* A staged_ledger transition will just add to a "ledger" integer *)
        module Staged_ledger_diff = struct
          type t = int [@@deriving bin_io, sexp]

          module With_valid_signatures_and_proofs = struct
            type t = int
          end
        end

        module Ledger = struct
          include Int

          type serializable = t [@@deriving bin_io]

          type maskable_ledger = int

          let merkle_root t = t

          let copy t = t
        end

        module Staged_ledger_aux_hash = struct
          type t = int [@@deriving sexp]
        end

        module Staged_ledger = struct
          type t = int ref [@@deriving sexp, bin_io]

          type serializable = int [@@deriving bin_io]

          module Aux = struct
            type t = int [@@deriving bin_io]

            let hash t = t

            let is_valid _ = true
          end

          let serializable_of_t t = !t

          let ledger t = !t

          let create ~ledger = ref ledger

          let copy t = ref !t

          let hash t = !t

          let of_serialized_and_unserialized ~serialized:_ ~unserialized:ledger
              =
            create ~ledger

          let of_aux_and_ledger ~snarked_ledger_hash:_ ~ledger ~aux:_ =
            Deferred.return (Ok (create ~ledger))

          let aux t = !t

          let apply (t : t) (x : Staged_ledger_diff.t) ~logger:_ =
            t := x ;
            return (Ok (`Hash_after_applying (hash t), `Ledger_proof (Some x)))

          let apply_diff_unchecked (_t : t) (_x : 'a) =
            failwith "Unimplemented"

          let snarked_ledger :
                 t
              -> snarked_ledger_hash:Frozen_ledger_hash.t
              -> Ledger.t Or_error.t =
           fun t ~snarked_ledger_hash:_ -> Ok !t
        end

        module State_hash = struct
          include Int

          let to_bits t = [t <> 0]

          let to_bytes = string_of_int
        end

        module Protocol_state_proof = Unit

        module Consensus_mechanism = struct
          module Local_state = struct
            type t = unit
          end

          module Blockchain_state = struct
            type value =
              { staged_ledger_hash: Staged_ledger_hash.t
              ; ledger_hash: Ledger_hash.t }
            [@@deriving eq, sexp, fields, bin_io, compare]
          end

          module Consensus_state = struct
            type value = {strength: int} [@@deriving eq, sexp, bin_io, compare]
          end

          module Protocol_state = struct
            type t =
              { previous_state_hash: State_hash.t
              ; blockchain_state: Blockchain_state.value
              ; consensus_state: Consensus_state.value }
            [@@deriving eq, sexp, fields, bin_io, compare]

            type value = t [@@deriving sexp, bin_io, eq, compare]

            let hash t = t.blockchain_state.staged_ledger_hash

            let create_value ~previous_state_hash ~blockchain_state
                ~consensus_state =
              {previous_state_hash; blockchain_state; consensus_state}

            let genesis =
              { previous_state_hash= -1
              ; blockchain_state= {staged_ledger_hash= 0; ledger_hash= 0}
              ; consensus_state= {strength= 0} }

            let to_string_record _ = "<opaque>"
          end

          let lock_transition ?proposer_public_key:_ _ _ ~snarked_ledger:_
              ~local_state:() =
            ()

          let select ~existing:Consensus_state.({strength= s1})
              ~candidate:Consensus_state.({strength= s2}) ~logger:_
              ~time_received:_ =
            if s1 >= s2 then `Keep else `Take
        end

        module External_transition = struct
          include Consensus_mechanism.Protocol_state

          let protocol_state = Fn.id

          let of_state = Fn.id

          let staged_ledger_diff = Consensus_mechanism.Protocol_state.hash

          let protocol_state_proof _ = ()
        end

        module Tip = struct
          type t =
            { state: Consensus_mechanism.Protocol_state.value
            ; proof: Protocol_state_proof.t
            ; staged_ledger: Staged_ledger.t }
          [@@deriving sexp, fields]

          let copy t =
            {t with staged_ledger= Staged_ledger.copy t.staged_ledger}

          let of_transition_and_lb transition staged_ledger =
            { state= External_transition.protocol_state transition
            ; proof= External_transition.protocol_state_proof transition
            ; staged_ledger }

          let bin_tip =
            [%bin_type_class:
              Consensus_mechanism.Protocol_state.value
              * Protocol_state_proof.t
              * Staged_ledger.serializable]
        end

        module Net = struct
          type t = Consensus_mechanism.Protocol_state.value State_hash.Table.t

          type net = Consensus_mechanism.Protocol_state.value list

          let create states =
            let tbl = State_hash.Table.create () in
            List.iter states ~f:(fun s ->
                State_hash.Table.add_exn tbl
                  ~key:(Consensus_mechanism.Protocol_state.hash s)
                  ~data:s ) ;
            tbl

          let get_staged_ledger_aux_at_hash _t hash = return (Ok hash)

          let glue_sync_ledger _t q a =
            don't_wait_for
              (Linear_pipe.iter q ~f:(fun (h, _) -> Linear_pipe.write a (h, h)))
        end

        module Sync_ledger = struct
          type answer = Ledger.t [@@deriving bin_io]

          type query = unit [@@deriving bin_io]

          module Responder = struct
            type t = unit

            let create _ = failwith "unused"

            let answer_query _ = failwith "unused"
          end

          type t =
            { mutable ledger: Ledger.t
            ; answer_pipe:
                (Ledger_hash.t * answer) Linear_pipe.Reader.t
                * (Ledger_hash.t * answer) Linear_pipe.Writer.t
            ; query_pipe:
                (Ledger_hash.t * query) Linear_pipe.Reader.t
                * (Ledger_hash.t * query) Linear_pipe.Writer.t }

          let create ledger ~parent_log:_ =
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

          let fetch _t h = return (`Ok h)
        end

        module Store = Store

        let verify_blockchain _ _ = Deferred.Or_error.return true
      end

      include Make (Inputs)
      open Inputs

      let slowly_pipe_of_list xs =
        let r, w = Linear_pipe.create () in
        don't_wait_for
          (Deferred.List.iter xs ~f:(fun x ->
               (* SUSP WAIT: Without the wait here, we get interrupted before doing anything interesting *)
               let%bind () = after (Time.Span.of_ms 100.) in
               let time =
                 Time.now () |> Time.to_span_since_epoch |> Time.Span.to_ms
                 |> Unix_timestamp.of_float
               in
               Linear_pipe.write w (x, time) )) ;
        r

      let config transitions longest_tip_location =
        let staged_ledger_transitions = slowly_pipe_of_list transitions in
        let net_input = transitions in
        let staged_ledger = Staged_ledger.create ~ledger:0 in
        let ledger = Staged_ledger.ledger staged_ledger in
        Config.make ~parent_log:(Logger.create ())
          ~net_deferred:(return net_input)
          ~external_transitions:
            (Linear_pipe.map staged_ledger_transitions
               ~f:External_transition.of_state)
          ~genesis_tip:
            { state= Inputs.Consensus_mechanism.Protocol_state.genesis
            ; proof= ()
            ; staged_ledger }
          ~ledger ~longest_tip_location ~consensus_local_state:()

      let create_transition x parent strength =
        { Inputs.Consensus_mechanism.Protocol_state.previous_state_hash= parent
        ; blockchain_state= {staged_ledger_hash= x; ledger_hash= x}
        ; consensus_state= {strength} }

      let no_catchup_transitions =
        let f = create_transition in
        [f 1 0 1; f 2 1 2; f 3 0 1; f 4 0 1; f 5 2 3; f 6 1 2; f 7 5 4]

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
          [ (d >>| fun d -> Ok d)
          ; ( Async.after (Time.Span.of_sec 5.)
            >>| fun () -> Or_error.error_string "Timeout" ) ]
        >>| Or_error.ok_exn

      let assert_strongest_ledgers lbc_deferred ~expected =
        Backtrace.elide := false ;
        Async.Thread_safe.block_on_async_exn (fun () ->
            let%bind lbc = lbc_deferred in
            let%map results =
              take_map (strongest_ledgers lbc) (List.length expected)
                ~f:(fun (lb, _) -> !lb )
            in
            assert (List.equal results expected ~equal:Int.equal) )
    end

    open Core
    module Lbc = Make_test (Storage.Memory)

    let storage_folder = Filename.temp_dir_name ^/ "lbc_test"

    let memory_storage_location = storage_folder ^/ "test_lbc_disk"

    let%test_unit "strongest_ledgers updates appropriately when new_states \
                   flow in within tree" =
      Backtrace.elide := false ;
      let config =
        Lbc.config Lbc.no_catchup_transitions memory_storage_location ()
      in
      Lbc.assert_strongest_ledgers (Lbc.create config) ~expected:[1; 2; 5; 7]

    (*    let%test_unit "strongest_ledgers updates appropriately using the network" =
      Backtrace.elide := false ;
      let transitions =
        let f = Lbc.create_transition in
        [ f 1 0 1
        ; f 2 1 2
        ; f 3 8 6 (* This one comes over the network *)
        ; f 4 2 3
          (* Here this would have extended, if we didn't kill the tree *)
        ; f 5 3 7
        (* Now we attach to the one from the network *) ]
      in
      let config = Lbc.config transitions memory_storage_location () in
      let lbc_deferred = Lbc.create config in
      Lbc.assert_strongest_ledgers lbc_deferred ~expected:[1; 2; 3; 5]

    let%test_unit "local_get_ledger can materialize a ledger locally" =
      Backtrace.elide := false ;
      let config =
        Lbc.config Lbc.no_catchup_transitions memory_storage_location ()
      in
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind lbc = Lbc.create config in
          (* Drain the first few strongest_ledgers *)
          let%bind _ = Lbc.take_map (Lbc.strongest_ledgers lbc) 4 ~f:ignore in
          match%map Lbc.local_get_ledger lbc 6 with
          | Ok (lb, _s) -> assert (!lb = 6)
          | Error e ->
              failwithf "Unexpected error %s" (Error.to_string_hum e) () )
 *)
    (*
    module Broadcastable_storage_disk (Pipe : sig
      val writer : [`Finished_write] Linear_pipe.Writer.t
    end) =
    struct
      include Storage.Disk

      let store controller location data =
        let%bind () = store controller location data in
        Linear_pipe.write Pipe.writer `Finished_write
    end
       *)
    (*
    let%test_unit "Files get saved" =
      Backtrace.elide := false ;
      let reader, writer = Linear_pipe.create () in
      let module Lbc_disk = Make_test (Broadcastable_storage_disk (struct
        let writer = writer
      end)) in
      Async.Thread_safe.block_on_async_exn (fun () ->
          File_system.with_temp_dir storage_folder ~f:
            (fun temp_storage_folder ->
              let config =
                Lbc_disk.config Lbc_disk.no_catchup_transitions
                  (temp_storage_folder ^/ "lbc")
              in
              let%bind lbc = Lbc_disk.create config in
              let%bind _ = Lbc.take_map reader 4 ~f:ignore in
              let%map tip = Lbc_disk.For_tests.load_tip lbc config in
              let lb =
                Lbc_disk.strongest_tip lbc
                |> Lbc_disk.Inputs.Tip.staged_ledger
              in
              assert (! (Lbc_disk.Inputs.Tip.staged_ledger tip) = !lb) ) )

    let%test_unit "Continue from last file" =
      Backtrace.elide := false ;
      let reader, writer = Linear_pipe.create () in
      let module Lbc_disk = Make_test (Broadcastable_storage_disk (struct
        let writer = writer
      end)) in
      Async.Thread_safe.block_on_async_exn (fun () ->
          File_system.with_temp_dir storage_folder ~f:
            (fun temp_storage_folder ->
              let storage_location = temp_storage_folder ^/ "lbc" in
              let config =
                Lbc_disk.config Lbc_disk.no_catchup_transitions
                  storage_location
              in
              let%bind lbc = Lbc_disk.create config in
              let%bind _ = Lbc.take_map reader 4 ~f:ignore in
              let lb =
                Lbc_disk.strongest_tip lbc
                |> Lbc_disk.Inputs.Tip.staged_ledger
              in
              let config_new = Lbc_disk.config [] storage_location in
              let%map lbc_new = Lbc_disk.create config_new in
              let lb_new =
                Lbc_disk.strongest_tip lbc_new
                |> Lbc_disk.Inputs.Tip.staged_ledger
              in
              assert (!lb = !lb_new) ) )
       *)
  end )
