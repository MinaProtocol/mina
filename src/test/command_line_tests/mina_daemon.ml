open Config
open Core
open Async

module MinaDaemon = struct
  type t = { process : Process.t; config : Config.t }

  let create process config = { process; config }

  let force_kill t =
    Process.send_signal t.process Core.Signal.kill ;
    Deferred.map (Process.wait t.process) ~f:Or_error.return
end
