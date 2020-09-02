open Core_kernel
open Coda_base

let check_exn =
  List.map ~f:(function
    | Command_transaction.User_command c -> (
      match User_command.check c with
      | None ->
          failwith "User command signature failed"
      | Some c ->
          Command_transaction.User_command c )
    | Snapp_command (c, _vks) ->
        Or_error.ok_exn (Snapp_command.check c) ;
        Snapp_command c )
