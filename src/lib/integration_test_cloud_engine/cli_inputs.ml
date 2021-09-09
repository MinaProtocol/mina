open Cmdliner

type t = {coda_automation_location: string}

let term =
  let coda_automation_location =
    let doc =
      "Location of the coda automation repository to use when deploying the \
       network."
    in
    let env = Arg.env_var "CODA_AUTOMATION_LOCATION" ~doc in
    Arg.(
      value & opt string "./automation"
      & info
          ["coda-automation-location"]
          ~env ~docv:"CODA_AUTOMATION_LOCATION" ~doc)
  in
  let cons_inputs coda_automation_location = {coda_automation_location} in
  Term.(const cons_inputs $ coda_automation_location)
