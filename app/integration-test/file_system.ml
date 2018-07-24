open Core
open Async

let create_dir optional_dir =
  let open Deferred.Let_syntax in
  let%bind home = Sys.home_directory () in
  let dir = Option.value ~default:(home ^/ Command_util.default_log_dir) optional_dir in
  let%map () = Unix.mkdir ~p:() dir in
  dir