(* Trigger Mina artifact builds *)

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
         with type Engine.Network_config.Cli_inputs.t = 'cli_inputs)
      * 'cli_inputs
      -> test_inputs_with_cli_inputs

type inputs =
  { test_inputs: test_inputs_with_cli_inputs
  ; test: test
  ; coda_image: string
  ; debug: bool }

let validate_inputs {coda_image; _} =
  if String.is_empty coda_image then
    failwith "Coda image cannot be an empt string"

let engines : engine list =
  [("cloud", (module Integration_test_cloud_engine : Intf.Engine.S))]

let tests : test list =
  [ ("block-prod", (module Block_production_test.Make : Intf.Test.Functor_intf))
  ; ("bootstrap", (module Bootstrap_test.Make : Intf.Test.Functor_intf))
  ; ("send-payment", (module Send_payment_test.Make : Intf.Test.Functor_intf))
  ; ( "pmt-timed-accts"
    , (module Payments_timed_accounts_test.Make : Intf.Test.Functor_intf) )
    (*
  ; ( "bp-timed-accts"
    , (module Block_production_timed_accounts_test.Make : Intf.Test.Functor_intf) )
  *)
  ; ("peers", (module Peers_test.Make : Intf.Test.Functor_intf)) ]

let report_test_errors error_set
    (missing_event_reprs : Structured_log_events.repr list) =
  let open Test_error in
  let open Test_error.Set in
  let errors =
    List.concat
      [ List.map error_set.soft_errors ~f:(fun err -> (`Soft, err))
      ; List.map error_set.hard_errors ~f:(fun err -> (`Hard, err)) ]
  in
  let num_errors_total = List.length errors in
  let num_errors_internal =
    List.length
      (List.filter errors ~f:(fun (_, error) ->
           match error with
           | Internal_error _ ->
               true
           | Remote_error _ ->
               false ))
  in
  let num_missing_events = List.length missing_event_reprs in
  if num_errors_total > 0 then (
    Print.eprintf "%s=== Errors encountered while running tests ===%s\n"
      Bash_colors.red Bash_colors.none ;
    let sorted_errors =
      List.sort errors ~compare:(fun (_, err1) (_, err2) ->
          Time.compare (occurrence_time err1) (occurrence_time err2) )
    in
    List.iter sorted_errors ~f:(fun (error_type, error) ->
        let color =
          match error_type with
          | `Soft ->
              Bash_colors.yellow
          | `Hard ->
              Bash_colors.red
        in
        Print.eprintf "    %s%s%s\n" color (to_string error) Bash_colors.none
    ) ;
    Out_channel.(flush stderr) ) ;
  if num_missing_events > 0 then (
    Print.eprintf
      "%s=== Missing expected log events while running tests ===%s\n"
      Bash_colors.red Bash_colors.none ;
    List.iter missing_event_reprs ~f:(fun repr ->
        Print.eprintf "    %s%s%s\n" Bash_colors.red repr.event_name
          Bash_colors.none ) ;
    Out_channel.(flush stderr) ) ;
  (* TODO: re-enable error check after libp2p logs are cleaned up *)
  (* if num_errors_total > 0 || num_missing_events > 0 then exit 1 else Deferred.unit *)
  if num_errors_internal > 0 || num_missing_events > 0 then exit 1
  else Deferred.unit

(* TODO: refactor cleanup system (smells like a monad for composing linear resources would help a lot) *)

let dispatch_cleanup ~logger ~init_cleanup_func ~network_cleanup_func
    ~log_engine_cleanup_func ~lift_accumulated_errors_func ~net_manager_ref
    ~log_engine_ref ~network_state_writer_ref ~cleanup_deferred_ref
    ~expected_error_event_reprs ~exit_reason ~test_result : unit Deferred.t =
  let cleanup () : unit Deferred.t =
    let open Structured_log_events in
    let%bind () = init_cleanup_func () in
    let%bind log_engine_cleanup_result =
      Option.value_map !log_engine_ref
        ~default:(Deferred.Or_error.return ())
        ~f:log_engine_cleanup_func
    in
    let%bind () =
      Option.value_map !net_manager_ref ~default:Deferred.unit
        ~f:network_cleanup_func
    in
    let%bind test_error_set =
      Malleable_error.lift_error_set_unit test_result
    in
    Option.value_map !network_state_writer_ref ~default:()
      ~f:Broadcast_pipe.Writer.close ;
    let all_errors =
      let open Test_error.Set in
      combine
        [ lift_accumulated_errors_func ()
        ; test_error_set
        ; of_hard_or_error log_engine_cleanup_result ]
    in
    let expected_error_event_ids =
      List.map expected_error_event_reprs ~f:(fun repr -> repr.id)
    in
    let is_expected_error (err : Test_error.t) =
      match err with
      | Internal_error _ ->
          false
      | Remote_error rem_err -> (
        match rem_err.error_message.event_id with
        | None ->
            false
        | Some id ->
            List.mem expected_error_event_ids id
              ~equal:Structured_log_events.equal_id )
    in
    let received_expected_errors, unexpected_errors =
      Test_error.Set.partition_tf all_errors ~f:is_expected_error
    in
    let received_expected_error_ids =
      Test_error.Set.concat_map received_expected_errors
        ~f:(fun (err : Test_error.t) ->
          match err with
          | Internal_error _ ->
              None
          | Remote_error rem_err ->
              rem_err.error_message.event_id )
      |> List.filter_opt
    in
    let missing_expected_error_reprs =
      List.filter expected_error_event_reprs ~f:(fun repr ->
          not
            (List.mem received_expected_error_ids repr.id
               ~equal:Structured_log_events.equal_id) )
    in
    report_test_errors unexpected_errors missing_expected_error_reprs
  in
  let%bind hard_error_string =
    Malleable_error.hard_error_to_string test_result
  in
  match !cleanup_deferred_ref with
  | Some deferred ->
      [%log error]
        "additional call to cleanup testnet while already cleaning up \
         (reason: $reason, hard error: $error)"
        ~metadata:
          [ ("reason", `String exit_reason)
          ; ("error", `String hard_error_string) ] ;
      deferred
  | None ->
      [%log info] "cleaning up testnet (reason: $reason, hard error: $error)"
        ~metadata:
          [ ("reason", `String exit_reason)
          ; ("error", `String hard_error_string) ] ;
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
    (module Test (Test_inputs)
    : Intf.Test.S
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
    { Test_config.Container_images.coda= inputs.coda_image
    ; user_agent= "codaprotocol/coda-user-agent:0.1.5"
    ; bots= "codaprotocol/coda-bots:0.0.13-beta-1"
    ; points= "codaprotocol/coda-points-hack:32b.4" }
  in
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
  let f_dispatch_cleanup =
    let init_cleanup_func () =
      if inputs.debug then
        Util.prompt_continue "Pausing cleanup. Enter [y/Y] to continue: "
      else Deferred.unit
    in
    let lift_accumulated_errors_func () =
      Option.value_map !error_accumulator_ref ~default:Test_error.Set.empty
        ~f:Dsl.lift_accumulated_errors
    in
    dispatch_cleanup ~logger ~init_cleanup_func
      ~network_cleanup_func:Engine.Network_manager.cleanup
      ~log_engine_cleanup_func:Engine.Log_engine.destroy
      ~lift_accumulated_errors_func ~net_manager_ref ~log_engine_ref
      ~network_state_writer_ref ~cleanup_deferred_ref
      ~expected_error_event_reprs:T.expected_error_event_reprs
  in
  (* run test while gracefully recovering handling exceptions and interrupts *)
  Signal.handle Signal.terminating ~f:(fun signal ->
      [%log info] "handling signal %s" (Signal.to_string signal) ;
      let error =
        Error.of_string
        @@ Printf.sprintf "received signal %s" (Signal.to_string signal)
      in
      don't_wait_for
        (f_dispatch_cleanup ~exit_reason:"signal received"
           ~test_result:(Malleable_error.of_error_hard error)) ) ;
  let%bind monitor_test_result =
    let on_fatal_error message =
      don't_wait_for
        (f_dispatch_cleanup
           ~exit_reason:
             (sprintf
                !"log engine fatal error: %s"
                (Yojson.Safe.to_string (Logger.Message.to_yojson message)))
           ~test_result:(Malleable_error.return ()))
    in
    Monitor.try_with ~extract_exn:false (fun () ->
        let init_result =
          let open Deferred.Or_error.Let_syntax in
          let lift = Deferred.map ~f:Or_error.return in
          let%bind net_manager =
            lift @@ Engine.Network_manager.create ~logger network_config
          in
          net_manager_ref := Some net_manager ;
          let%bind network =
            lift @@ Engine.Network_manager.deploy net_manager
          in
          let%map log_engine = Engine.Log_engine.create ~logger ~network in
          log_engine_ref := Some log_engine ;
          let event_router =
            Dsl.Event_router.create ~logger
              ~event_reader:(Engine.Log_engine.event_reader log_engine)
          in
          error_accumulator_ref :=
            Some (Dsl.watch_log_errors ~logger ~event_router ~on_fatal_error) ;
          let network_state_reader, network_state_writer =
            Dsl.Network_state.listen ~logger event_router
          in
          network_state_writer_ref := Some network_state_writer ;
          let (`Don't_call_in_tests dsl) =
            Dsl.create ~logger ~network ~event_router ~network_state_reader
          in
          (network, dsl)
        in
        let open Malleable_error.Let_syntax in
        let%bind network, dsl =
          Deferred.bind init_result ~f:Malleable_error.of_or_error_hard
        in
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
        ("exception thrown", Malleable_error.of_error_hard (Error.of_exn exn))
  in
  let%bind () = f_dispatch_cleanup ~exit_reason ~test_result in
  exit 0

let start inputs =
  validate_inputs inputs ;
  never_returns
    (Async.Scheduler.go_main ~main:(fun () -> don't_wait_for (main inputs)) ())

let test_arg =
  (* we nest the tests in a redundant index so that we still get the name back after cmdliner evaluates the argument *)
  let indexed_tests =
    List.map tests ~f:(fun (name, test) -> (name, (name, test)))
  in
  let doc = "The name of the test to execute." in
  Arg.(required & pos 0 (some (enum indexed_tests)) None & info [] ~doc)

let coda_image_arg =
  let doc = "Identifier of the coda docker image to test." in
  let env = Arg.env_var "CODA_IMAGE" ~doc in
  Arg.(
    required
    & opt (some string) None
    & info ["coda-image"] ~env ~docv:"CODA_IMAGE" ~doc)

let debug_arg =
  let doc =
    "Enable debug mode. On failure, the test executive will pause for user \
     input before destroying the network it deployed."
  in
  Arg.(value & flag & info ["debug"; "d"] ~doc)

let help_term = Term.(ret @@ const (`Help (`Plain, None)))

let engine_cmd ((engine_name, (module Engine)) : engine) =
  let info =
    let doc = "Run coda integration test(s) on remote cloud provider." in
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
    let cons_inputs test_inputs test coda_image debug =
      {test_inputs; test; coda_image; debug}
    in
    Term.(
      const cons_inputs $ test_inputs_with_cli_inputs_arg $ test_arg
      $ coda_image_arg $ debug_arg)
  in
  let term = Term.(const start $ inputs_term) in
  (term, info)

let help_cmd =
  let doc = "Print out test executive documentation." in
  let info = Term.info "help" ~doc ~exits:Term.default_exits in
  (help_term, info)

let default_cmd =
  let doc = "Run coda integration test(s)." in
  let info = Term.info "test_executive" ~doc ~exits:Term.default_error_exits in
  (help_term, info)

(* TODO: move required args to positions instead of flags, or provide reasonable defaults to make them optional *)
let () =
  let engine_cmds = List.map engines ~f:engine_cmd in
  Term.(exit @@ eval_choice default_cmd (engine_cmds @ [help_cmd]))
