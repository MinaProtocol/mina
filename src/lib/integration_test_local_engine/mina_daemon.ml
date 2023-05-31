open Config
open Core
open Async
open Integration_test_lib

module MinaDaemon = struct
  type t = { process : Process.t; config : Config.t }

  let create process config = { process; config }

  let force_kill t =
    Process.send_signal t.process Core.Signal.kill ;
    Deferred.map (Process.wait t.process) ~f:Or_error.return
  
  let get_graphql_api ~logger t= 
    Test_graphql.create
      ~logger_metadata:[]
      ~uri:(Uri.make ~scheme:"http" ~host:"localhost" ~path:"/graphql" ~port:t.config.port ())
      ~enabled:true
      ~logger    
end
