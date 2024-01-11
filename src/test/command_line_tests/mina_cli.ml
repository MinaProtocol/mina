open Core
open Async

module MinaCli = struct
  type t = { port : int; mina_exe : string }

  let create port mina_exe = { port; mina_exe }

  let stop_daemon t =
    Process.run () ~prog:t.mina_exe
      ~args:[ "client"; "stop-daemon"; "-daemon-port"; sprintf "%d" t.port ]

  let daemon_status t =
    Process.run ~prog:t.mina_exe
      ~args:[ "client"; "status"; "-daemon-port"; sprintf "%d" t.port ]
      ()
end
