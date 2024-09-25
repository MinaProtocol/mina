open Core
open Async
open Cmdliner
open Pipe_lib
open Integration_test_lib

type test = string * (module Intf.Test.Functor_intf)

type engine = string * (module Intf.Engine.S)

module Make_test_inputs (Engine : Intf.Engine.S) () :
  Intf.Test.Inputs_intf
    with type Engine.Network_config.Cli_inputs.t =
      Engine.Network_config.Cli_inputs.t = struct
  module Engine = Engine

  module Dsl = Dsl.Make (Engine) ()
end

type test_inputs_with_cli_inputs =
  | Test_inputs_with_cli_inputs :
      (module Intf.Test.Inputs_intf
         with type Engine.Network_config.Cli_inputs.t = 'cli_inputs )
      * 'cli_inputs
      -> test_inputs_with_cli_inputs

type inputs =
  { test_inputs : test_inputs_with_cli_inputs
  ; test : test
  ; mina_image : string
  ; archive_image : string option
  ; debug : bool
  }

let validate_inputs ~logger inputs (test_config : Test_config.t) :
    unit Deferred.t =
  if String.is_empty inputs.mina_image then (
    [%log fatal] "mina-image argument cannot be an empty string" ;
    exit 1 )
  else if
    test_config.num_archive_nodes > 0 && Option.is_none inputs.archive_image
  then (
    [%log fatal]
      "This test uses archive nodes.  archive-image argument cannot be absent \
       for this test" ;
    exit 1 )
  else Deferred.return ()

let engines : engine list =
  [ ("cloud", (module Integration_test_cloud_engine : Intf.Engine.S))
  ; ("local", (module Integration_test_local_engine : Intf.Engine.S))
  ]

let tests : test list =
  [ ( "peers-reliability"
    , (module Peers_reliability_test.Make : Intf.Test.Functor_intf) )
  ; ( "chain-reliability"
    , (module Chain_reliability_test.Make : Intf.Test.Functor_intf) )
  ; ("payments", (module Payments_test.Make : Intf.Test.Functor_intf))
  ; ("gossip-consis", (module Gossip_consistency.Make : Intf.Test.Functor_intf))
  ; ("medium-bootstrap", (module Medium_bootstrap.Make : Intf.Test.Functor_intf))
  ; ("zkapps", (module Zkapps.Make : Intf.Test.Functor_intf))
  ; ("zkapps-timing", (module Zkapps_timing.Make : Intf.Test.Functor_intf))
  ; ("zkapps-nonce", (module Zkapps_nonce_test.Make : Intf.Test.Functor_intf))
  ; ( "verification-key"
    , (module Verification_key_update.Make : Intf.Test.Functor_intf) )
  ; ( "block-prod-prio"
    , (module Block_production_priority.Make : Intf.Test.Functor_intf) )
  ; ("block-reward", (module Block_reward_test.Make : Intf.Test.Functor_intf))
  ; ("hard-fork", (module Hard_fork.Make : Intf.Test.Functor_intf))
  ; ("epoch-ledger", (module Epoch_ledger.Make : Intf.Test.Functor_intf))
  ; ("slot-end", (module Slot_end_test.Make : Intf.Test.Functor_intf))
  ]

let report_test_errors ~log_error_set ~internal_error_set =
  (* TODO: we should be able to show which sections passed as well *)
  let open Test_error in
  let open Test_error.Set in
  let color_eprintf color =
    Printf.ksprintf (fun s -> Print.eprintf "%s%s%s" color s Bash_colors.none)
  in
  let color_of_severity = function
    | `None ->
        Bash_colors.green
    | `Soft ->
        Bash_colors.yellow
    | `Hard ->
        Bash_colors.red
  in
  let category_prefix_of_severity = function
    | `None ->
        "✓"
    | `Soft ->
        "-"
    | `Hard ->
        "×"
  in
  let print_category_header severity =
    Printf.ksprintf
      (color_eprintf
         (color_of_severity severity)
         "%s %s\n"
         (category_prefix_of_severity severity) )
  in
  let max_sev a b =
    match (a, b) with
    | `Hard, _ | _, `Hard ->
        `Hard
    | `Soft, _ | _, `Soft ->
        `Soft
    | _ ->
        `None
  in
  let max_severity_of_list severities =
    List.fold severities ~init:`None ~f:max_sev
  in
  let combine_errors error_set =
    Error_accumulator.combine
      [ Error_accumulator.map error_set.soft_errors ~f:(fun err -> (`Soft, err))
      ; Error_accumulator.map error_set.hard_errors ~f:(fun err -> (`Hard, err))
      ]
  in
  let internal_errors = combine_errors internal_error_set in
  let internal_errors_severity = max_severity internal_error_set in
  let log_errors = combine_errors log_error_set in
  let log_errors_severity = max_severity log_error_set in
  let report_log_errors log_type =
    color_eprintf
      (color_of_severity log_errors_severity)
      "=== Log %ss ===\n" log_type ;
    Error_accumulator.iter_contexts log_errors ~f:(fun node_id log_errors ->
        color_eprintf Bash_colors.light_magenta "    %s:\n" node_id ;
        List.iter log_errors ~f:(fun (severity, { error_message; _ }) ->
            color_eprintf
              (color_of_severity severity)
              "        [%s] %s\n"
              (Time.to_string error_message.timestamp)
              (Yojson.Safe.to_string (Logger.Message.to_yojson error_message)) ) ;
        Print.eprintf "\n" )
  in
  (* check invariants *)
  match log_errors.from_current_context with
  | _ :: _ ->
      failwith "all error logs should be contextualized by node id"
  | [] ->
      (* report log errors *)
      Print.eprintf "\n" ;
      ( match log_errors_severity with
      | `None ->
          ()
      | `Soft ->
          report_log_errors "Warning"
      | `Hard ->
          report_log_errors "Error" ) ;
      (* report contextualized internal errors *)
      color_eprintf Bash_colors.magenta "=== Test Results ===\n" ;
      Error_accumulator.iter_contexts internal_errors ~f:(fun context errors ->
          print_category_header
            (max_severity_of_list (List.map errors ~f:fst))
            "%s" context ;
          List.iter errors ~f:(fun (severity, { occurrence_time; error }) ->
              color_eprintf
                (color_of_severity severity)
                "    [%s] %s\n"
                (Time.to_string occurrence_time)
                (Error.to_string_hum error) ) ) ;
      (* report non-contextualized internal errors *)
      List.iter internal_errors.from_current_context
        ~f:(fun (severity, { occurrence_time; error }) ->
          color_eprintf
            (color_of_severity severity)
            "[%s] %s\n"
            (Time.to_string occurrence_time)
            (Error.to_string_hum error) ) ;
      (* determine if test is passed/failed and exit accordingly *)
      let test_failed =
        match (log_errors_severity, internal_errors_severity) with
        | _, `Hard | _, `Soft ->
            true
        (* TODO: re-enable log error checks after libp2p logs are cleaned up *)
        | `Hard, _ | `Soft, _ | `None, `None ->
            false
      in
      Print.eprintf "\n" ;
      let exit_code =
        if test_failed then (
          color_eprintf Bash_colors.red
            "The test has failed. See the above errors for details.\n\n" ;
          match (internal_error_set.exit_code, log_error_set.exit_code) with
          | None, None ->
              Some 1
          | Some exit_code, _ | None, Some exit_code ->
              Some exit_code )
        else (
          color_eprintf Bash_colors.green
            "The test has completed successfully.\n\n" ;
          None )
      in
      let%bind () = Writer.(flushed (Lazy.force stderr)) in
      return exit_code

(* TODO: refactor cleanup system (smells like a monad for composing linear resources would help a lot) *)

let dispatch_cleanup ~logger ~pause_cleanup_func ~network_cleanup_func
    ~log_engine_cleanup_func ~lift_accumulated_errors_func ~net_manager_ref
    ~log_engine_ref ~network_state_writer_ref ~cleanup_deferred_ref ~exit_reason
    ~test_result : unit Deferred.t =
  let cleanup () : unit Deferred.t =
    let%bind log_engine_cleanup_result =
      Option.value_map !log_engine_ref
        ~default:(Deferred.Or_error.return ())
        ~f:log_engine_cleanup_func
    in
    Option.value_map !network_state_writer_ref ~default:()
      ~f:Broadcast_pipe.Writer.close ;
    let%bind test_error_set = Malleable_error.lift_error_set_unit test_result in
    let log_error_set = lift_accumulated_errors_func () in
    let internal_error_set =
      let open Test_error.Set in
      combine [ test_error_set; of_hard_or_error log_engine_cleanup_result ]
    in
    let%bind exit_code =
      report_test_errors ~log_error_set ~internal_error_set
    in
    let%bind () = pause_cleanup_func () in
    let%bind () =
      Option.value_map !net_manager_ref ~default:Deferred.unit
        ~f:network_cleanup_func
    in
    Deferred.Option.map ~f:exit (return exit_code) >>| ignore
  in
  match !cleanup_deferred_ref with
  | Some deferred ->
      [%log error]
        "additional call to cleanup testnet while already cleaning up (reason: \
         $reason)"
        ~metadata:[ ("reason", `String exit_reason) ] ;
      deferred
  | None ->
      [%log info] "cleaning up testnet (reason: $reason)"
        ~metadata:[ ("reason", `String exit_reason) ] ;
      let deferred = cleanup () in
      cleanup_deferred_ref := Some deferred ;
      deferred

let main inputs =
  (* TODO: abstract over which engine is in use, allow engine to be set form CLI *)
  let (Test_inputs_with_cli_inputs ((module Test_inputs), cli_inputs)) =
    inputs.test_inputs
  in
  let open Test_inputs in
  let test_name, (module Test) = inputs.test in
  let (module T) =
    (module Test (Test_inputs) : Intf.Test.S
      with type network = Engine.Network.t
       and type node = Engine.Network.Node.t
       and type dsl = Dsl.t )
  in
  (*
    (module Test (Test_inputs)
    : Intf.Test.S
      with type network = Engine.Network.t
       and type log_engine = Engine.Log_engine.t )
    *)
  (* TODO:
   *   let (module Exec) = (module Execute.Make (Engine)) in
   *   Exec.execute ~logger ~engine_cli_inputs ~images (module Test (Engine))
   *)
  let logger = Logger.create () in
  let constants : Test_config.constants =
    let protocol =
      { Genesis_constants.Compiled.genesis_constants.protocol with
        k = 20
      ; delta = 0
      ; slots_per_epoch = 3 * 8 * 20
      ; slots_per_sub_window = 2
      ; grace_period_slots = 140
      }
    in
    { genesis_constants =
        { Genesis_constants.Compiled.genesis_constants with
          protocol
        ; txpool_max_size = 3000
        }
    ; constraint_constants = Genesis_constants.Compiled.constraint_constants
    ; compile_config = Mina_compile_config.Compiled.t
    }
  in
  let images =
    { Test_config.Container_images.mina = inputs.mina_image
    ; archive_node =
        Option.value inputs.archive_image ~default:"archive_image_unused"
    ; user_agent = "codaprotocol/coda-user-agent:0.1.5"
    ; bots = "minaprotocol/mina-bots:latest"
    ; points = "codaprotocol/coda-points-hack:32b.4"
    }
  in
  let test_config = T.config ~constants in
  let%bind () = validate_inputs ~logger inputs test_config in
  [%log trace] "expanding network config" ;
  let network_config =
    Engine.Network_config.expand ~logger ~test_name ~cli_inputs
      ~debug:inputs.debug ~constants ~images ~test_config
  in
  (* resources which require additional cleanup at end of test *)
  let net_manager_ref : Engine.Network_manager.t option ref = ref None in
  let log_engine_ref : Engine.Log_engine.t option ref = ref None in
  let error_accumulator_ref = ref None in
  let network_state_writer_ref = ref None in
  let cleanup_deferred_ref = ref None in
  [%log trace] "preparing up cleanup phase" ;
  let f_dispatch_cleanup =
    let pause_cleanup_func () =
      if inputs.debug then
        Util.prompt_continue "Pausing cleanup. Enter [y/Y] to continue: "
      else Deferred.unit
    in
    let lift_accumulated_errors_func () =
      Option.value_map !error_accumulator_ref ~default:Test_error.Set.empty
        ~f:Dsl.lift_accumulated_log_errors
    in
    dispatch_cleanup ~logger ~pause_cleanup_func
      ~network_cleanup_func:Engine.Network_manager.cleanup
      ~log_engine_cleanup_func:Engine.Log_engine.destroy
      ~lift_accumulated_errors_func ~net_manager_ref ~log_engine_ref
      ~network_state_writer_ref ~cleanup_deferred_ref
  in
  (* run test while gracefully recovering handling exceptions and interrupts *)
  [%log trace] "attaching signal handler" ;
  Signal.handle Signal.terminating ~f:(fun signal ->
      [%log info] "handling signal %s" (Signal.to_string signal) ;
      let error =
        Error.of_string
        @@ Printf.sprintf "received signal %s" (Signal.to_string signal)
      in
      don't_wait_for
        (f_dispatch_cleanup ~exit_reason:"signal received"
           ~test_result:(Malleable_error.hard_error error) ) ) ;
  let%bind monitor_test_result =
    let on_fatal_error message =
      don't_wait_for
        (f_dispatch_cleanup
           ~exit_reason:
             (sprintf
                !"log engine fatal error: %s"
                (Yojson.Safe.to_string (Logger.Message.to_yojson message)) )
           ~test_result:(Malleable_error.hard_error_string "fatal error") )
    in
    Monitor.try_with ~here:[%here] ~extract_exn:false (fun () ->
        let open Malleable_error.Let_syntax in
        let%bind network, dsl =
          let lift ?exit_code =
            Deferred.bind ~f:(Malleable_error.or_hard_error ?exit_code)
          in
          [%log trace] "initializing network manager" ;
          let%bind net_manager =
            Engine.Network_manager.create ~logger network_config
          in
          net_manager_ref := Some net_manager ;
          [%log trace] "deploying network" ;
          let%bind network = Engine.Network_manager.deploy net_manager in
          [%log trace] "initializing log engine" ;
          let%map log_engine =
            lift ~exit_code:6 (Engine.Log_engine.create ~logger ~network)
          in
          log_engine_ref := Some log_engine ;
          let event_router =
            Dsl.Event_router.create ~logger
              ~event_reader:(Engine.Log_engine.event_reader log_engine)
          in
          error_accumulator_ref :=
            Some (Dsl.watch_log_errors ~logger ~event_router ~on_fatal_error) ;
          [%log trace] "beginning to process network events" ;
          let network_state_reader, network_state_writer =
            Dsl.Network_state.listen ~logger event_router
          in
          network_state_writer_ref := Some network_state_writer ;
          [%log trace] "initializing dsl" ;
          let (`Don't_call_in_tests dsl) =
            Dsl.create ~logger ~network ~event_router ~network_state_reader
          in
          (network, dsl)
        in
        [%log trace] "initializing network abstraction" ;
        let%bind () = Engine.Network.initialize_infra ~logger network in

        [%log info] "Starting the daemons within the pods" ;
        let start_print (node : Engine.Network.Node.t) =
          let open Malleable_error.Let_syntax in
          [%log info] "starting %s ..." (Engine.Network.Node.infra_id node) ;
          let%bind res = Engine.Network.Node.start ~fresh_state:false node in
          [%log info] "%s started" (Engine.Network.Node.infra_id node) ;
          Malleable_error.return res
        in
        let seed_nodes =
          network |> Engine.Network.seeds |> Core.String.Map.data
        in
        let non_seed_pods =
          network |> Engine.Network.all_non_seed_nodes |> Core.String.Map.data
        in
        let _offline_node_event_subscription =
          (* Monitor for offline nodes; abort the test if a node goes down
             unexpectedly.
          *)
          Dsl.Event_router.on (Dsl.event_router dsl) Node_offline
            ~f:(fun offline_node () ->
              let node_name = Engine.Network.Node.infra_id offline_node in
              [%log info] "Detected node offline $node"
                ~metadata:[ ("node", `String node_name) ] ;
              if Engine.Network.Node.should_be_running offline_node then (
                [%log fatal] "Offline $node is required for this test"
                  ~metadata:[ ("node", `String node_name) ] ;
                failwith "Aborted because of required offline node" ) ;
              Async_kernel.Deferred.return `Continue )
        in
        (* TODO: parallelize (requires accumlative hard errors) *)
        let%bind () = Malleable_error.List.iter seed_nodes ~f:start_print in
        let%bind () =
          Dsl.wait_for dsl (Dsl.Wait_condition.nodes_to_initialize seed_nodes)
        in
        let%bind () = Malleable_error.List.iter non_seed_pods ~f:start_print in
        [%log info] "Daemons started" ;
        [%log trace] "executing test" ;
        T.run network dsl )
  in
  let exit_reason, test_result =
    match monitor_test_result with
    | Ok malleable_error ->
        let exit_reason =
          if Malleable_error.is_ok malleable_error then "test completed"
          else "errors occurred"
        in
        (exit_reason, Deferred.return malleable_error)
    | Error exn ->
        [%log error] "%s" (Exn.to_string_mach exn) ;
        ("exception thrown", Malleable_error.hard_error (Error.of_exn exn))
  in
  let%bind () = f_dispatch_cleanup ~exit_reason ~test_result in
  exit 0

let start inputs =
  never_returns
    (Async.Scheduler.go_main ~main:(fun () -> don't_wait_for (main inputs)) ())

let test_arg =
  (* we nest the tests in a redundant index so that we still get the name back after cmdliner evaluates the argument *)
  let indexed_tests =
    List.map tests ~f:(fun (name, test) -> (name, (name, test)))
  in
  let doc = "The name of the test to execute." in
  Arg.(required & pos 0 (some (enum indexed_tests)) None & info [] ~doc)

let mina_image_arg =
  let doc = "Identifier of the Mina docker image to test." in
  let env = Arg.env_var "MINA_IMAGE" ~doc in
  Arg.(
    required
    & opt (some string) None
    & info [ "mina-image" ] ~env ~docv:"MINA_IMAGE" ~doc)

let archive_image_arg =
  let doc = "Identifier of the archive node docker image to test." in
  let env = Arg.env_var "ARCHIVE_IMAGE" ~doc in
  Arg.(
    value
      ( opt (some string) None
      & info [ "archive-image" ] ~env ~docv:"ARCHIVE_IMAGE" ~doc ))

let debug_arg =
  let doc =
    "Enable debug mode. On failure, the test executive will pause for user \
     input before destroying the network it deployed."
  in
  Arg.(value & flag & info [ "debug"; "d" ] ~doc)

let help_term = Term.(ret @@ const (`Help (`Plain, None)))

let engine_cmd ((engine_name, (module Engine)) : engine) =
  let info =
    let doc = "Run mina integration test(s) on remote cloud provider." in
    Term.info engine_name ~doc ~exits:Term.default_exits
  in
  let test_inputs_with_cli_inputs_arg =
    let wrap_cli_inputs cli_inputs =
      Test_inputs_with_cli_inputs
        ((module Make_test_inputs (Engine) ()), cli_inputs)
    in
    Term.(const wrap_cli_inputs $ Engine.Network_config.Cli_inputs.term)
  in
  let inputs_term =
    let cons_inputs test_inputs test mina_image archive_image debug =
      { test_inputs; test; mina_image; archive_image; debug }
    in
    Term.(
      const cons_inputs $ test_inputs_with_cli_inputs_arg $ test_arg
      $ mina_image_arg $ archive_image_arg $ debug_arg)
  in
  let term = Term.(const start $ inputs_term) in
  (term, info)

let help_cmd =
  let doc = "Print out test executive documentation." in
  let info = Term.info "help" ~doc ~exits:Term.default_exits in
  (help_term, info)

let default_cmd =
  let doc = "Run mina integration test(s)." in
  let info = Term.info "test_executive" ~doc ~exits:Term.default_error_exits in
  (help_term, info)

(* TODO: move required args to positions instead of flags, or provide reasonable defaults to make them optional *)
let () =
  let engine_cmds = List.map engines ~f:engine_cmd in
  Term.(exit @@ eval_choice default_cmd (engine_cmds @ [ help_cmd ]))
