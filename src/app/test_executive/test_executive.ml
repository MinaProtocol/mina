open Core
open Async
open Cmdliner

type inputs = {coda_image: string; coda_automation_location: string}

let network_config_from_inputs {coda_image; _} =
  let open Network_config.Abstract in
  let open Network_config.Abstract.Images in
  let bal = Currency.Balance.of_string in
  { images=
      { coda= coda_image
      ; user_agent= "codaprotocol/coda-user-agent:0.1.5"
      ; bots= "codaprotocol/coda-bots:0.0.13-beta-1"
      ; points= "codaprotocol/coda-points-hack:32b.4" }
  ; cloud= Cloud.default
  ; k= 20
  ; delta= 3
  ; proof_level= Runtime_config.Proof_keys.Level.Full
  ; txpool_max_size= 3000
  ; block_producers=
      [{balance= bal "7500"}; {balance= bal "5000"}; {balance= bal "2500"}]
  ; num_snark_workers= 4
  ; snark_worker_fee= "0.025"
  ; snark_worker_public_key=
      "4vsRCVQZ41uqXfVVfkBNUuNNS7PgSJGdMDNAyKGDdU1WkdxxyxQ7oMdFcjDRf45fiGKkdYKkLPBrE1KnxmyBuvaTW97A5C8XjNSiJmvo9oHa4AwyVsZ3ACaspgQ3EyxQXk6uujaxzvQhbLDx"
  }

let main inputs () =
  don't_wait_for
    (* TODO: here is where we would collect the Network_config.Abstract.t for the test we want to execute *)
    (let%bind net =
       Network.create ~testnet_name:"test"
         ~coda_automation_location:inputs.coda_automation_location
         ~network_config:(network_config_from_inputs inputs)
     in
     let%bind () = Network.deploy net in
     (* TODO: here is where we create the log engine and execute the test *)
     let%bind () = after (Time.Span.of_sec 1800.0) in
     let%bind () = Network.cleanup net in
     exit 0)

let start inputs =
  never_returns (Async.Scheduler.go_main ~main:(main inputs) ())

(* TODO: move required args to positions instead of flags, or provide reasonable defaults to make them optional *)
let () =
  let coda_image =
    let doc = "Identifier of the coda docker image to test." in
    let env = Arg.env_var "CODA_IMAGE" ~doc in
    Arg.(
      required
      & opt (some string) None
      & info ["coda-image"] ~env ~docv:"CODA_IMAGE" ~doc)
  in
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
  let inputs =
    let cons_inputs coda_image coda_automation_location =
      {coda_image; coda_automation_location}
    in
    Term.(const cons_inputs $ coda_image $ coda_automation_location)
  in
  let test_executive_term = Term.(const start $ inputs) in
  let test_executive_info =
    let doc = "Run coda integration test(s)." in
    Term.info "test_executive" ~doc ~exits:Term.default_exits
  in
  Term.(exit @@ eval (test_executive_term, test_executive_info))
