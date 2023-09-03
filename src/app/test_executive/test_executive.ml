open Core
open Async
open Cmdliner
open Pipe_lib
open Integration_test_lib

type test = (module Intf.Test.Functor_intf)

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
  ; config_path : string option
  ; keypairs_path : string
  ; mock_alias : (string * string) option
  }

let test_name (test : test)
    (module Inputs : Integration_test_lib.Intf.Test.Inputs_intf) =
  let module Test = (val test) (Inputs) in
  Test.test_name

let validate_inputs ~logger inputs (test_config : Test_config.t) :
    unit Deferred.t =
  if String.is_empty inputs.mina_image then (
    [%log fatal] "mina-image argument cannot be an empty string" ;
    exit 1 )
  else if
    List.length test_config.archive_nodes > 0
    && Option.is_none inputs.archive_image
  then (
    [%log fatal]
      "This test uses archive nodes.  archive-image argument cannot be absent \
       for this test" ;
    exit 1 )
  else
    let (Test_inputs_with_cli_inputs ((module Inputs), _)) =
      inputs.test_inputs
    in
    if
      String.(test_name inputs.test (module Inputs) = "mock")
      && Option.is_none inputs.mock_alias
      && (Option.is_none @@ Sys.getenv "MOCK_NETWORK")
    then (
      [%log fatal]
        "Must provide either --mock command line arg or set MOCK_NETWORK env \
         var" ;
      ignore @@ exit 1 ) ;
    let keypairs_path =
      if String.(suffix inputs.keypairs_path 1 = "/") then
        String.drop_suffix inputs.keypairs_path 1
      else inputs.keypairs_path
    in
    let keypairs_ls = Stdlib.Sys.readdir keypairs_path in
    (* check network-keypairs *)
    if
      not
        ( Array.exists keypairs_ls ~f:(String.equal "network-keypairs")
        && (Stdlib.Sys.is_directory @@ keypairs_path ^ "/network-keypairs") )
    then (
      [%log fatal]
        "No network-keypairs directory present in %s \n\
        \ Consider cloning the pre-generated keypairs repo: \n\
        \   git clone git@github.com:MinaFoundation/lucy-keypairs.git"
        keypairs_path ;
      ignore @@ exit 1 ) ;
    (* check libp2p-keypairs *)
    if
      not
        ( Array.exists keypairs_ls ~f:(String.equal "libp2p-keypairs")
        && (Stdlib.Sys.is_directory @@ keypairs_path ^ "/libp2p-keypairs") )
    then (
      [%log fatal]
        "No libp2p-keypairs directory present in %s \n\
        \ Consider cloning the pre-generated keypairs repo: \n\
        \   git clone git@github.com:MinaFoundation/lucy-keypairs.git"
        keypairs_path ;
      ignore @@ exit 1 ) ;
    match Inputs.Engine.name with
    | "abstract" ->
        if Option.is_none inputs.config_path then (
          [%log fatal]
            "Must provide a config file when using the abstract engine" ;
          exit 1 )
        else Deferred.unit
    | _ ->
        [%log debug]
          "Config file is only used for the abstract engine. It will be \
           ignored." ;
        Deferred.unit

let engines : engine list =
  [ ("abstract", (module Integration_test_abstract_engine : Intf.Engine.S))
  ; ("cloud", (module Integration_test_cloud_engine : Intf.Engine.S))
  ]

let tests : test list =
  [ (module Block_production_priority.Make : Intf.Test.Functor_intf)
  ; (module Block_reward_test.Make : Intf.Test.Functor_intf)
  ; (module Chain_reliability_test.Make : Intf.Test.Functor_intf)
  ; (module Delegation_test.Make : Intf.Test.Functor_intf)
  ; (module Gossip_consistency.Make : Intf.Test.Functor_intf)
  ; (module Medium_bootstrap.Make : Intf.Test.Functor_intf)
  ; (module Mock.Make : Intf.Test.Functor_intf)
  ; (module Payments_test.Make : Intf.Test.Functor_intf)
  ; (module Peers_reliability_test.Make : Intf.Test.Functor_intf)
  ; (module Snarkyjs.Make : Intf.Test.Functor_intf)
  ; (module Verification_key_update.Make : Intf.Test.Functor_intf)
  ; (module Zkapps.Make : Intf.Test.Functor_intf)
  ; (module Zkapps_nonce_test.Make : Intf.Test.Functor_intf)
  ; (module Zkapps_timing.Make : Intf.Test.Functor_intf)
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
    let open Error_accumulator in
    combine
      [ map error_set.soft_errors ~f:(fun err -> (`Soft, err))
      ; map error_set.hard_errors ~f:(fun err -> (`Hard, err))
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
  let (Test_inputs_with_cli_inputs ((module Test_inputs), cli_inputs)) =
    inputs.test_inputs
  in
  let open Test_inputs in
  let (module Test) = inputs.test in
  let test_name = test_name inputs.test (module Test_inputs) in
  let module T = Test (Test_inputs) in
  let logger = Logger.create () in
  let images =
    Test_config.Container_images.mk inputs.mina_image inputs.archive_image
  in
  let%bind () = validate_inputs ~logger inputs T.config in
  [%log trace] "expanding network config" ;
  let network_config =
    Engine.Network_config.expand ~logger ~test_name ~cli_inputs
      ~debug:inputs.debug ~test_config:T.config ~images
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
  (* run test while gracefully recovering, handling exceptions, and interrupts *)
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
            Engine.Network_manager.create ~logger network_config T.config
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
        if String.equal test_name "mock" then (
          [%log info] "No node interactions in mock network" ;
          return () )
        else (
          [%log info] "starting the daemons within the pods" ;
          let start_print (node : Engine.Network.Node.t) =
            let open Malleable_error.Let_syntax in
            [%log info] "starting %s..." (Engine.Network.Node.id node) ;
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
            Dsl.(wait_for dsl @@ Wait_condition.nodes_to_initialize seed_nodes)
          in
          let%bind () = Malleable_error.List.iter non_seed_pods ~f:start_print in
          [%log info] "daemons started" ;
          [%log trace] "executing test" ;
          T.run network dsl ) )
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

let test_arg inputs =
  let indexed_tests =
    List.map tests ~f:(fun test -> (test_name test inputs, test))
  in
  let doc = "The name of the test to execute." in
  Arg.(required & pos 0 (some (enum indexed_tests)) None & info [] ~doc)

let config_path_arg =
  let doc = "Path to the CI config file." in
  let env = Arg.env_var "MINA_CI_CONFIG_PATH" ~doc in
  Arg.(
    value
    & opt (some non_dir_file) None
    & info [ "config-path"; "config" ] ~env ~docv:"MINA_CI_CONFIG_PATH" ~doc)

let mock_alias_arg =
  let doc = "Alias to use for the mock network binary." in
  let env = Arg.env_var "MOCK_NETWORK" ~doc in
  Arg.(
    value
    & opt (some string) None
    & info [ "mock-network"; "mock"; "alias" ] ~env ~docv:"MOCK_NETWORK" ~doc)

let keypair_dir_path_arg =
  let doc = "Path to the pre-generated network and libp2p keypair directory." in
  let env = Arg.env_var "MINA_KEYPAIRS_PATH" ~doc in
  Arg.(
    required
    & opt (some dir) None
    & info [ "keypairs-path" ] ~env ~docv:"MINA_KEYPAIRS_PATH" ~doc)

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
    & opt (some string) None
    & info [ "archive-image" ] ~env ~docv:"ARCHIVE_IMAGE" ~doc)

let debug_arg =
  let doc =
    "Enable debug mode. On failure, the test executive will pause for user \
     input before destroying the network it deployed."
  in
  Arg.(value & flag & info [ "debug"; "d" ] ~doc)

let help_term = Term.(ret @@ const (`Help (`Plain, None)))

let info engine_name =
  let doc =
    match engine_name with
    | "abstract" ->
        "Run mina integration tests with the abstract engine."
    | "cloud" ->
        "Run mina integration tests on a remote cloud provider."
    | _ ->
        assert false
  in
  Term.info engine_name ~doc ~exits:Term.default_exits

let engine_cmd ((engine_name, (module Engine)) : engine) =
  let info = info engine_name in
  let module Inputs = Make_test_inputs (Engine) () in
  let set_config path =
    Option.iter path ~f:(fun p -> Engine.Network.config_path := p) ;
    path
  in
  let set_keypair path =
    Engine.Network.keypairs_path := path ;
    path
  in
  let set_mina_image image =
    Engine.Network.mina_image := image ;
    image
  in
  let set_archive_image image =
    Engine.Network.archive_image := image ;
    image
  in
  let set_alias alias =
    let alias = Option.map alias ~f:(fun a -> ("MOCK_NETWORK", a)) in
    Engine.Network.alias := alias ;
    alias
  in
  let test_inputs_with_cli_inputs_arg =
    let wrap_cli_inputs cli_inputs =
      Test_inputs_with_cli_inputs ((module Inputs), cli_inputs)
    in
    Term.(const wrap_cli_inputs $ Engine.Network_config.Cli_inputs.term)
  in
  let inputs_term =
    let cons_inputs test_inputs test debug archive_image mina_image config_path
        keypairs_path mock_alias =
      { test_inputs
      ; test
      ; mina_image
      ; archive_image
      ; debug
      ; config_path
      ; keypairs_path
      ; mock_alias
      }
    in
    Term.(
      const cons_inputs $ test_inputs_with_cli_inputs_arg
      $ test_arg (module Inputs)
      $ debug_arg
      $ (const set_archive_image $ archive_image_arg)
      $ (const set_mina_image $ mina_image_arg)
      $ (const set_config $ config_path_arg)
      $ (const set_keypair $ keypair_dir_path_arg)
      $ (const set_alias $ mock_alias_arg))
  in
  (Term.(const start $ inputs_term), info)

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
