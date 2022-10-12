open Core


module Cmd = struct
  let parse_conf =
    let open Command.Param in
    let open Command.Let_syntax in
    let%map rosetta_port = flag "p" (optional int) ~doc:"Port The port Rosetta server listens on."
    and rosetta_host = flag "h" (optional string) ~doc:"Host The host Rosetta server runs on." in
    Conf.make
        ?rosetta_host
        ?rosetta_port
        ()

  let status =
    Async.Command.async
      ~summary:"Get Rosetta server's status."
      (let open Command.Let_syntax in
       let%map conf = parse_conf in
       Rosetta.call_and_display ~conf (module Network.Status))
end


let command =
  Async.Command.group
    ~summary:"Rosetta API client."
    [ ("status", Cmd.status) ]

let () = Command.run command
