open Cmdliner

type t =
  { mina_automation_location : string
  ; check_capacity : bool
  ; check_capacity_delay : int
  ; check_capacity_retries : int
  }

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
  let check_capacity =
    let doc =
      "Whether or not to check the capacity of the cloud cluster before \
       execution.  Default: true"
    in
    Arg.(value & opt bool true & info [ "capacity-check" ] ~doc)
  in
  let check_capacity_delay =
    let doc =
      "Upon a failed capacity check, how much time in seconds to wait before \
       trying.  Only holds meaning if check-capacity is true.  Default: 60"
    in
    Arg.(value & opt int 60 & info [ "capacity-check-delay" ] ~doc)
  in
  let check_capacity_retries =
    let doc =
      "Upon a failed capacity check, how many times to retry before giving \
       up.  Only holds meaning if check-capacity is true.  Default: 10"
    in
    Arg.(value & opt int 10 & info [ "capacity-check-retries" ] ~doc)
  in
  let cons_inputs mina_automation_location check_capacity check_capacity_delay
      check_capacity_retries =
    { mina_automation_location
    ; check_capacity
    ; check_capacity_delay
    ; check_capacity_retries
    }
  in

  Term.(
    const cons_inputs $ mina_automation_location $ check_capacity
    $ check_capacity_delay $ check_capacity_retries)
