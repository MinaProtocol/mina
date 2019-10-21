open Core

let () =
  Commander.Command_spec.client ~daemon_port:Registrar_lib.Commander.port
    ~summary:"Registrar client" Registrar_lib.Commander.commands
  |> Command.run
