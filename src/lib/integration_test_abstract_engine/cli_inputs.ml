open Cmdliner

type t = { mina_automation_location : string }

let term =
  let mina_automation_location =
    let doc =
      "Location of the Mina automation repository to use when deploying the \
       network."
    in
    let env = Arg.env_var "MINA_AUTOMATION_LOCATION" ~doc in
    Arg.(
      value & opt string "./automation"
      & info
          [ "mina-automation-location" ]
          ~env ~docv:"MINA_AUTOMATION_LOCATION" ~doc)
  in
  let lift mina_automation_location = { mina_automation_location } in
  Term.(const lift $ mina_automation_location)
