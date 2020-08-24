open Core
open Async
open Cmdliner
open Integration_test_lib

type test = string * (module Test_functor_intf)

type inputs = {test: test; coda_image: string}

let tests : test list =
  [ ( "block-production"
    , (module Block_production_test.Make : Test_functor_intf) ) ]

let to_or_error = Deferred.map ~f:Or_error.return

let report_test_errors error_set =
  let open Test_error in
  let open Test_error.Set in
  let errors =
    List.concat
      [ List.map error_set.soft_errors ~f:(fun err -> (`Soft, err))
      ; List.map error_set.hard_errors ~f:(fun err -> (`Hard, err)) ]
  in
  if List.length errors > 0 then (
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
    Out_channel.(flush stderr) ;
    exit 1 )
  else Deferred.unit

let main inputs =
  (* TODO: abstract over which engine is in use, allow engine to be set form CLI *)
  let module Engine = Integration_test_cloud_engine in
  let test_name, (module Test) = inputs.test in
  (*  let test_name =
    test_name ^ String.init 3 ~f:(fun _ -> (Int.to_string (Random.int 10)).[0])
  in
*)
  let (module T) =
    (module Test (Engine)
    : Test_intf
      with type network = Engine.Network.t
       and type log_engine = Engine.Log_engine.t )
  in
  let logger = Logger.create () in
  let images =
    { Container_images.coda= inputs.coda_image
    ; user_agent= "codaprotocol/coda-user-agent:0.1.5"
    ; bots= "codaprotocol/coda-bots:0.0.13-beta-1"
    ; points= "codaprotocol/coda-points-hack:32b.4" }
  in
  let network_config =
    Engine.Network_config.expand ~logger ~test_name ~test_config:T.config
      ~images
  in
  (* resources which require additional cleanup at end of test *)
  let net_manager_ref : Engine.Network_manager.t option ref = ref None in
  let log_engine_ref : Engine.Log_engine.t option ref = ref None in
  let cleanup_deferred_ref = ref None in
  let dispatch_cleanup reason test_error =
    let open Deferred.Let_syntax in
    let cleanup test_error =
      let test_error_set =
        match test_error with
        | None ->
            Test_error.Set.empty
        | Some err ->
            Test_error.Set.hard_singleton (Test_error.internal_error err)
      in
      let%bind log_engine_error_set =
        Option.value_map !log_engine_ref
          ~default:(Deferred.return Test_error.Set.empty) ~f:(fun log_engine ->
            match%map Engine.Log_engine.destroy log_engine with
            | Ok errors ->
                errors
            | Error err ->
                Test_error.Set.hard_singleton (Test_error.internal_error err)
        )
      in
      let%bind () =
        Option.value_map !net_manager_ref ~default:Deferred.unit
          ~f:Engine.Network_manager.cleanup
      in
      report_test_errors
        (Test_error.Set.combine [test_error_set; log_engine_error_set])
    in
    match !cleanup_deferred_ref with
    | Some deferred ->
        [%log error]
          "additional call to cleanup testnet while already cleaning up \
           ($reason, $error)"
          ~metadata:
            [ ("reason", `String reason)
            ; ( "error"
              , `String
                  ( Option.map test_error ~f:Error.to_string_hum
                  |> Option.value ~default:"<none>" ) ) ] ;
        deferred
    | None ->
        [%log info] "cleaning up testnet ($reason, $error)"
          ~metadata:
            [ ("reason", `String reason)
            ; ( "error"
              , `String
                  ( Option.map test_error ~f:Error.to_string_hum
                  |> Option.value ~default:"<none>" ) ) ] ;
        let deferred = cleanup test_error in
        cleanup_deferred_ref := Some deferred ;
        deferred
  in
  (* run test while gracefully recovering handling exceptions and interrupts *)
  Signal.handle Signal.terminating ~f:(fun signal ->
      [%log info] "handling signal %s" (Signal.to_string signal) ;
      let error =
        Error.of_string
        @@ Printf.sprintf "received signal %s" (Signal.to_string signal)
      in
      don't_wait_for (dispatch_cleanup "signal received" (Some error)) ) ;
  let%bind test_result =
    Monitor.try_with_join_or_error ~extract_exn:true (fun () ->
        let open Deferred.Or_error.Let_syntax in
        let%bind net_manager =
          to_or_error @@ Engine.Network_manager.create network_config
        in
        net_manager_ref := Some net_manager ;
        let%bind network =
          to_or_error @@ Engine.Network_manager.deploy net_manager
        in
        let%bind log_engine =
          Engine.Log_engine.create ~logger ~network ~on_fatal_error:(fun () ->
              don't_wait_for (dispatch_cleanup "log engine fatal error" None)
          )
        in
        log_engine_ref := Some log_engine ;
        T.run network log_engine )
  in
  let%bind () = dispatch_cleanup "test completed" (Result.error test_result) in
  exit 0

let start inputs =
  never_returns
    (Async.Scheduler.go_main ~main:(fun () -> don't_wait_for (main inputs)) ())

(* TODO: move required args to positions instead of flags, or provide reasonable defaults to make them optional *)
let () =
  let test =
    (* we nest the tests in a redundant index so that we still get the name back after cmdliner evaluates the argument *)
    let indexed_tests =
      List.map tests ~f:(fun (name, test) -> (name, (name, test)))
    in
    let doc = "The name of the test to execute." in
    Arg.(required & pos 0 (some (enum indexed_tests)) None & info [] ~doc)
  in
  let coda_image =
    let doc = "Identifier of the coda docker image to test." in
    let env = Arg.env_var "CODA_IMAGE" ~doc in
    Arg.(
      required
      & opt (some string) None
      & info ["coda-image"] ~env ~docv:"CODA_IMAGE" ~doc)
  in
  (*
  let coda_automation_location =
    let doc =
      "Location of the coda automation repository to use when deploying the \
       network."
    in
    let env = Arg.env_var "CODA_AUTOMATION_LOCATION" ~doc in
    Arg.(
      required
      & opt (some string) None
      & info
          ["coda-automation-location"]
          ~env ~docv:"CODA_AUTOMATION_LOCATION" ~doc)
  in
  *)
  let inputs =
    let cons_inputs test coda_image = {test; coda_image} in
    Term.(const cons_inputs $ test $ coda_image)
  in
  let test_executive_term =
    Term.(
      const start $ inputs
      $ const (module Block_production_test.Make : Test_functor_intf))
  in
  let test_executive_info =
    let doc = "Run coda integration test(s)." in
    Term.info "test_executive" ~doc ~exits:Term.default_exits
  in
  Term.(exit @@ eval (test_executive_term, test_executive_info))
