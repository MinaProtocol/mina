open Core
open Async
open Cmdliner
open Integration_test_lib

type test = string * (module Test_functor)

type inputs = {test: test; coda_image: string}

let tests : test list =
  [("block-production", (module Block_production_test.Make : Test_functor))]

let main inputs =
  let raise_error deferred_or_error =
    match%map deferred_or_error with Ok x -> x | Error err -> Error.raise err
  in
  (* TODO: abstract over which engine is in use, allow engine to be set form CLI *)
  let module Engine = Integration_test_cloud_engine in
  let test_name, (module Test) = inputs.test in
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
  don't_wait_for
    (* TODO: here is where we would collect the Network_config.Abstract.t for the test we want to execute *)
    (let%bind net_manager = Engine.Network_manager.create network_config in
     let%bind network = Engine.Network_manager.deploy net_manager in
     let%bind log_engine =
       raise_error (Engine.Log_engine.create ~logger network)
     in
     let%bind () = raise_error (T.run network log_engine) in
     let%bind () = Engine.Network_manager.cleanup net_manager in
     exit 0)

let start inputs =
  never_returns (Async.Scheduler.go_main ~main:(fun () -> main inputs) ())

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
      $ const (module Block_production_test.Make : Test_functor))
  in
  let test_executive_info =
    let doc = "Run coda integration test(s)." in
    Term.info "test_executive" ~doc ~exits:Term.default_exits
  in
  Term.(exit @@ eval (test_executive_term, test_executive_info))
