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
  ; generate_code_coverage : bool
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
  [ ("cloud", (module Integration_test_cloud_engine : Intf.Engine.S)) ]

let tests : test list =
  [ ( "peers-reliability"
    , (module Peers_reliability_test.Make : Intf.Test.Functor_intf) )
  ; ( "chain-reliability"
    , (module Chain_reliability_test.Make : Intf.Test.Functor_intf) )
  ; ("payments", (module Payments_test.Make : Intf.Test.Functor_intf))
  ; ("delegation", (module Delegation_test.Make : Intf.Test.Functor_intf))
  ; ("gossip-consis", (module Gossip_consistency.Make : Intf.Test.Functor_intf))
  ; ("medium-bootstrap", (module Medium_bootstrap.Make : Intf.Test.Functor_intf))
  ; ("zkapps", (module Zkapps.Make : Intf.Test.Functor_intf))
  ; ("zkapps-timing", (module Zkapps_timing.Make : Intf.Test.Functor_intf))
  ; ("zkapps-nonce", (module Zkapps_nonce_test.Make : Intf.Test.Functor_intf))
  ; ( "verification-key"
    , (module Verification_key_update.Make : Intf.Test.Functor_intf) )
  ; ( "opt-block-prod"
    , (module Block_production_priority.Make : Intf.Test.Functor_intf) )
  ; ("snark", (module Snark_test.Make : Intf.Test.Functor_intf))
  ; ("snarkyjs", (module Snarkyjs.Make : Intf.Test.Functor_intf))
  ; ("block-reward", (module Block_reward_test.Make : Intf.Test.Functor_intf))
  ]

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
      Test_result.calculate_test_result ~log_error_set ~internal_error_set
        ~logger
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
  let images =
    { Test_config.Container_images.mina = inputs.mina_image
    ; archive_node =
        Option.value inputs.archive_image ~default:"archive_image_unused"
    ; user_agent = "codaprotocol/coda-user-agent:0.1.5"
    ; bots = "minaprotocol/mina-bots:latest"
    ; points = "codaprotocol/coda-points-hack:32b.4"
    }
  in
  let%bind () = validate_inputs ~logger inputs T.config in
  [%log trace] "expanding network config" ;
  let network_config =
    Engine.Network_config.expand ~logger ~test_name ~cli_inputs
      ~debug:inputs.debug ~test_config:T.config ~images
      ~generate_code_coverage:inputs.generate_code_coverage
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
        let%bind network, net_manager, dsl =
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
          (network, net_manager, dsl)
        in
        [%log trace] "initializing network abstraction" ;
        let%bind () = Engine.Network.initialize_infra ~logger network in

        [%log info] "Starting the daemons within the pods" ;
        let start_print (node : Engine.Network.Node.t) =
          let open Malleable_error.Let_syntax in
          [%log info] "starting %s ..." (Engine.Network.Node.id node) ;
          let%bind res = Engine.Network.Node.start ~fresh_state:false node in
          [%log info] "%s started" (Engine.Network.Node.id node) ;
          Malleable_error.return res
        in
        let seed_nodes =
          network |> Engine.Network.seeds |> Core.String.Map.data
        in
        let non_seed_pods =
          network |> Engine.Network.all_non_seed_pods |> Core.String.Map.data
        in
        (* TODO: parallelize (requires accumlative hard errors) *)
        let%bind () = Malleable_error.List.iter seed_nodes ~f:start_print in
        let%bind () =
          Dsl.wait_for dsl (Dsl.Wait_condition.nodes_to_initialize seed_nodes)
        in
        let%bind () = Malleable_error.List.iter non_seed_pods ~f:start_print in
        [%log info] "Daemons started" ;
        [%log trace] "executing test" ;
        let%bind result = T.run network dsl in
        let open Malleable_error.Let_syntax in
        let%bind () =
          Engine.Network_manager.generate_code_coverage net_manager network
        in
        Malleable_error.return result )
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

let generate_code_coverage_arg =
  let doc =
    "Dump coverage data of each mina process to specified bucket. Requires \
     special version of mina package (built with --instrument-with flag) and \
     env variable 'BISECT_SIGTERM=yes' in mina container. WARNING: this is \
     destructive operation as coverage data is generated on sig term signal. \
     Process iterates of every applicable pod (which have mina process) and \
     kills it. After that downloads coverage data and upload to gcloud bucket"
  in
  let env = Arg.env_var "GENERATE_COVERAGE" ~doc in
  Arg.(
    value
      ( opt bool false
      & info [ "generate-coverage" ] ~env ~docv:"GENERATE_COVERAGE" ~doc ))

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
    let cons_inputs test_inputs test mina_image archive_image debug
        generate_code_coverage =
      { test_inputs
      ; test
      ; mina_image
      ; archive_image
      ; debug
      ; generate_code_coverage
      }
    in
    Term.(
      const cons_inputs $ test_inputs_with_cli_inputs_arg $ test_arg
      $ mina_image_arg $ archive_image_arg $ debug_arg
      $ generate_code_coverage_arg)
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
