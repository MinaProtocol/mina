open Core_kernel
open Async_kernel

module Make (Inputs : Inputs.S) : sig
  open Inputs

  include
    Coda_lib.Ledger_builder_controller_intf
    with type ledger_builder := Ledger_builder.t
     and type ledger_builder_hash := Ledger_builder_hash.t
     and type ledger := Ledger.t
     and type ledger_proof := Ledger_proof.t
     and type net := Net.net
     and type protocol_state := Consensus_mechanism.Protocol_state.value
     and type ledger_hash := Ledger_hash.t
     and type sync_query := Sync_ledger.query
     and type sync_answer := Sync_ledger.answer
     and type external_transition := Consensus_mechanism.External_transition.t
     and type consensus_local_state := Consensus_mechanism.Local_state.t
     and type tip := Tip.t
     and type keypair := Keypair.t

  val ledger_builder_io : t -> Net.t
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
      ; consensus_local_state: Consensus_mechanism.Local_state.t
      ; longest_tip_location: string
      ; keypair: Keypair.t }
    [@@deriving make]
  end

  module Transition_logic_inputs = struct
    include Inputs

    module Step = struct
      let apply' t diff logger =
        Deferred.Or_error.map
          (Ledger_builder.apply t diff ~logger)
          ~f:
            (Option.map ~f:(fun proof ->
                 ( Ledger_proof.statement proof |> Ledger_proof_statement.target
                 , proof ) ))

      let step logger {With_hash.data= tip; hash= tip_hash}
          {With_hash.data= transition; hash= transition_target_hash} =
        let open Deferred.Or_error.Let_syntax in
        let old_state = tip.Tip.protocol_state in
        let new_state = External_transition.protocol_state transition in
        let%bind verified =
          verify_blockchain
            (External_transition.protocol_state_proof transition)
            new_state
        in
        let%bind ledger_hash =
          match%map
            apply' tip.ledger_builder
              (External_transition.ledger_builder_diff transition)
              logger
          with
          | Some (h, _) -> h
          | None ->
              old_state |> Protocol_state.blockchain_state
              |> Blockchain_state.ledger_hash
        in
        let ledger_builder_hash = Ledger_builder.hash tip.ledger_builder in
        let%map () =
          if
            verified
            && Ledger_builder_hash.equal ledger_builder_hash
                 ( new_state |> Protocol_state.blockchain_state
                 |> Blockchain_state.ledger_builder_hash )
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
              Tip.protocol_state= new_state
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
    { ledger_builder_io: Net.t
    ; log: Logger.t
    ; store_controller: (Tip.t, State_hash.t) With_hash.t Store.Controller.t
    ; handler: Transition_logic.t
    ; strongest_ledgers_reader:
        (Ledger_builder.t * External_transition.t) Linear_pipe.Reader.t }

  let strongest_tip t =
    let state = Transition_logic.state t.handler in
    Transition_logic_state.assert_state_valid state ;
    Transition_logic_state.longest_branch_tip state |> With_hash.data

  let ledger_builder_io {ledger_builder_io; _} = ledger_builder_io

  let load_tip_and_genesis_hash
      (controller : (Tip.t, State_hash.t) With_hash.t Store.Controller.t)
      {Config.longest_tip_location; genesis_tip; _} log =
    let genesis_state_hash =
      Protocol_state.hash genesis_tip.Tip.protocol_state
    in
    match%map Store.load controller longest_tip_location with
    | Ok tip_and_genesis_hash -> tip_and_genesis_hash
    | Error `No_exist ->
        Logger.info log
          "File for ledger builder controller tip does not exist. Using \
           Genesis tip" ;
        {data= genesis_tip; hash= genesis_state_hash}
    | Error (`IO_error e) ->
        Logger.error log
          !"IO error: %s\nUsing Genesis tip"
          (Error.to_string_hum e) ;
        {data= genesis_tip; hash= genesis_state_hash}
    | Error `Checksum_no_match ->
        Logger.error log
          !"Checksum from location %s does not match with data\n\
            Using Genesis tip"
          longest_tip_location ;
        {data= genesis_tip; hash= genesis_state_hash}

  let create (config : Config.t) =
    let log = Logger.child config.parent_log "ledger_builder_controller" in
    let store_controller =
      Store.Controller.create
        (With_hash.bin_t Tip.bin_t State_hash.bin_t)
        ~parent_log:config.parent_log
    in
    let genesis_tip_state_hash =
      Protocol_state.hash config.genesis_tip.Tip.protocol_state
    in
    let%bind {data= tip; hash= stored_genesis_state_hash} =
      load_tip_and_genesis_hash store_controller config log
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
        ~consensus_local_state:config.consensus_local_state
        (With_hash.of_data tip ~hash_data:(fun tip ->
             tip.Tip.protocol_state |> Protocol_state.hash ))
    in
    let%map net = config.net_deferred in
    let net = Net.create net in
    let catchup =
      Catchup.create ~net ~parent_log:log
        ~public_key:(Public_key.compress config.keypair.public_key)
    in
    (* Here we effectfully listen to transitions and emit what we belive are
       the strongest ledger_builders *)
    let strongest_ledgers_reader, strongest_ledgers_writer =
      Linear_pipe.create ()
    in
    let store_tip_reader, store_tip_writer = Linear_pipe.create () in
    let t =
      { ledger_builder_io= net
      ; log
      ; store_controller
      ; strongest_ledgers_reader
      ; handler= Transition_logic.create state log }
    in
    don't_wait_for
      (Linear_pipe.iter (Transition_logic.strongest_tip t.handler)
         ~f:(fun (tip, transition) ->
           Linear_pipe.force_write_maybe_drop_head ~capacity:1 store_tip_writer
             store_tip_reader tip ;
           Deferred.return
           @@ Linear_pipe.write_or_exn ~capacity:5 strongest_ledgers_writer
                t.strongest_ledgers_reader
                (tip.ledger_builder, transition) )) ;
    don't_wait_for
      (Linear_pipe.iter store_tip_reader ~f:(fun tip ->
           let open With_hash in
           let tip_with_genesis_hash =
             {data= tip; hash= genesis_tip_state_hash}
           in
           Store.store store_controller config.longest_tip_location
             tip_with_genesis_hash )) ;
    (* Handle new transitions *)
    let possibly_jobs =
      Linear_pipe.filter_map_unordered ~max_concurrency:1
        config.external_transitions ~f:(fun (transition, time_received) ->
          let transition_with_hash =
            With_hash.of_data transition ~hash_data:(fun t ->
                t |> External_transition.protocol_state |> Protocol_state.hash
            )
          in
          let%map job =
            Transition_logic.on_new_transition catchup t.handler
              transition_with_hash ~time_received
          in
          Option.map job ~f:(fun job -> (job, time_received)) )
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
              (Protocol_state.consensus_state
                 (External_transition.protocol_state last_transition))
              (Protocol_state.consensus_state
                 (External_transition.protocol_state current_transition))
              ~logger:log ~time_received
          with
          | `Keep -> `Skip
          | `Take -> `Cancel_and_do_next )
    in
    don't_wait_for
      ( Linear_pipe.fold possibly_jobs ~init:None
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
        load_tip_and_genesis_hash t.store_controller config t.log
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

  (** Returns a reference to a ledger_builder with hash [hash], materialize a
   fresh ledger at a specific hash if necessary; also gives back target_state *)
  let local_get_ledger t hash =
    Logger.trace t.log
      !"Attempting to local-get-ledger for %{sexp: Ledger_builder_hash.t}"
      hash ;
    local_get_ledger' t hash
      ~p_tip:(fun hash {With_hash.data= tip; hash= _} ->
        Ledger_builder_hash.equal
          (Ledger_builder.hash tip.Tip.ledger_builder)
          hash )
      ~p_trans:(fun hash {With_hash.data= trans; hash= _} ->
        Ledger_builder_hash.equal
          ( trans |> External_transition.protocol_state
          |> Protocol_state.blockchain_state
          |> Blockchain_state.ledger_builder_hash )
          hash )
      ~f_result:(fun {With_hash.data= tip; hash= _} -> tip.Tip.ledger_builder)

  let handle_sync_ledger_queries :
         t
      -> Ledger_hash.t * Sync_ledger.query
      -> (Ledger_hash.t * Sync_ledger.answer) Deferred.Or_error.t =
   fun t (hash, query) ->
    (* TODO: We should cache, but in the future it will be free *)
    let open Deferred.Or_error.Let_syntax in
    Logger.trace t.log
      !"Attempting to handle a sync-ledger query for %{sexp: Ledger_hash.t}"
      hash ;
    let%map ledger =
      local_get_ledger' t hash
        ~p_tip:(fun hash {With_hash.data= tip; hash= _} ->
          Ledger_hash.equal
            ( tip.Tip.ledger_builder |> Ledger_builder.ledger
            |> Ledger.merkle_root )
            hash )
        ~p_trans:(fun hash {With_hash.data= trans; hash= _} ->
          Ledger_hash.equal
            ( trans |> External_transition.protocol_state
            |> Protocol_state.blockchain_state
            |> Blockchain_state.ledger_builder_hash
            |> Ledger_builder_hash.ledger_hash )
            hash )
        ~f_result:(fun {With_hash.data= tip; hash= _} ->
          tip.Tip.ledger_builder |> Ledger_builder.ledger )
      >>| fst
    in
    let responder = Sync_ledger.Responder.create ledger ignore in
    (hash, Sync_ledger.Responder.answer_query responder query)
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

        module Keypair = struct
          type t = {public_key: Public_key.t; private_key: Private_key.t}
        end

        module Ledger_builder_hash = struct
          include Int

          let ledger_hash = Fn.id
        end

        (* A ledger_builder transition will just add to a "ledger" integer *)
        module Ledger_builder_diff = Int

        module Ledger = struct
          include Int

          let merkle_root t = t

          let copy t = t
        end

        module Ledger_builder_aux_hash = struct
          type t = int [@@deriving sexp]
        end

        module Ledger_builder = struct
          type t = int ref [@@deriving sexp, bin_io]

          module Aux = struct
            type t = int [@@deriving bin_io]

            let hash t = t
          end

          type proof = ()

          let ledger t = !t

          let create ~ledger ~self:_ = ref ledger

          let copy t = ref !t

          let hash t = !t

          let of_aux_and_ledger ~snarked_ledger_hash:_ ~public_key:_ ~ledger
              ~aux:_ =
            Ok (create ~ledger ~self:())

          let aux t = !t

          let apply (t : t) (x : Ledger_builder_diff.t) ~logger:_ =
            t := x ;
            return (Ok (Some x))

          let snarked_ledger :
                 t
              -> snarked_ledger_hash:Frozen_ledger_hash.t
              -> Ledger.t Or_error.t =
           fun t ~snarked_ledger_hash:_ -> Ok !t
        end

        module State_hash = struct
          include Int

          let to_bits t = [t <> 0]
        end

        module Protocol_state_proof = Unit

        module Consensus_mechanism = struct
          module Local_state = struct
            type t = unit
          end

          module Blockchain_state = struct
            type value =
              { ledger_builder_hash: Ledger_builder_hash.t
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

            let hash t = t.blockchain_state.ledger_builder_hash

            let create_value ~previous_state_hash ~blockchain_state
                ~consensus_state =
              {previous_state_hash; blockchain_state; consensus_state}

            let genesis =
              { previous_state_hash= -1
              ; blockchain_state= {ledger_builder_hash= 0; ledger_hash= 0}
              ; consensus_state= {strength= 0} }
          end

          module External_transition = struct
            include Protocol_state

            let protocol_state = Fn.id

            let of_state = Fn.id

            let ledger_builder_diff = Protocol_state.hash

            let protocol_state_proof _ = ()
          end

          let lock_transition _ _ ~snarked_ledger:_ ~local_state:() = ()

          let select Consensus_state.({strength= s1})
              Consensus_state.({strength= s2}) ~logger:_ ~time_received:_ =
            if s1 >= s2 then `Keep else `Take
        end

        module Tip = struct
          type t =
            { protocol_state: Consensus_mechanism.Protocol_state.value
            ; proof: Protocol_state_proof.t
            ; ledger_builder: Ledger_builder.t }
          [@@deriving bin_io, sexp, fields]

          let copy t =
            {t with ledger_builder= Ledger_builder.copy t.ledger_builder}

          let of_transition_and_lb transition ledger_builder =
            { protocol_state=
                Consensus_mechanism.External_transition.protocol_state
                  transition
            ; proof=
                Consensus_mechanism.External_transition.protocol_state_proof
                  transition
            ; ledger_builder }
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

          let get_ledger_builder_aux_at_hash _t hash = return (Ok hash)

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
               (* Without the wait here, we get interrupted before doing anything interesting *)
               let%bind () = after (Time.Span.of_ms 100.) in
               let time =
                 Time.now () |> Time.to_span_since_epoch |> Time.Span.to_ms
                 |> Unix_timestamp.of_float
               in
               Linear_pipe.write w (x, time) )) ;
        r

      let config transitions longest_tip_location =
        let ledger_builder_transitions = slowly_pipe_of_list transitions in
        let net_input = transitions in
        Config.make ~parent_log:(Logger.create ())
          ~net_deferred:(return net_input)
          ~external_transitions:
            (Linear_pipe.map ledger_builder_transitions
               ~f:Consensus_mechanism.External_transition.of_state)
          ~genesis_tip:
            { protocol_state= Inputs.Consensus_mechanism.Protocol_state.genesis
            ; proof= ()
            ; ledger_builder= Ledger_builder.create ~ledger:0 ~self:() }
          ~longest_tip_location ~consensus_local_state:()
          ~keypair:{Keypair.public_key= (); private_key= ()}

      let create_transition x parent strength =
        { Inputs.Consensus_mechanism.Protocol_state.previous_state_hash= parent
        ; blockchain_state= {ledger_builder_hash= x; ledger_hash= x}
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
        Lbc.config Lbc.no_catchup_transitions memory_storage_location
      in
      Lbc.assert_strongest_ledgers (Lbc.create config) ~expected:[1; 2; 5; 7]

    let%test_unit "strongest_ledgers updates appropriately using the network" =
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
      let config = Lbc.config transitions memory_storage_location in
      let lbc_deferred = Lbc.create config in
      Lbc.assert_strongest_ledgers lbc_deferred ~expected:[1; 2; 3; 5]

    let%test_unit "local_get_ledger can materialize a ledger locally" =
      Backtrace.elide := false ;
      let config =
        Lbc.config Lbc.no_catchup_transitions memory_storage_location
      in
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind lbc = Lbc.create config in
          (* Drain the first few strongest_ledgers *)
          let%bind _ = Lbc.take_map (Lbc.strongest_ledgers lbc) 4 ~f:ignore in
          match%map Lbc.local_get_ledger lbc 6 with
          | Ok (lb, _s) -> assert (!lb = 6)
          | Error e ->
              failwithf "Unexpected error %s" (Error.to_string_hum e) () )

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
                |> Lbc_disk.Inputs.Tip.ledger_builder
              in
              assert (! (Lbc_disk.Inputs.Tip.ledger_builder tip) = !lb) ) )

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
                |> Lbc_disk.Inputs.Tip.ledger_builder
              in
              let config_new = Lbc_disk.config [] storage_location in
              let%map lbc_new = Lbc_disk.create config_new in
              let lb_new =
                Lbc_disk.strongest_tip lbc_new
                |> Lbc_disk.Inputs.Tip.ledger_builder
              in
              assert (!lb = !lb_new) ) )
       *)
  end )
