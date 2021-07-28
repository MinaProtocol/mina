open Core_kernel
open Mina_base

let check :
       User_command.Verifiable.t
    -> [ `Valid of User_command.Valid.t
       | `Invalid
       | `Valid_assuming of User_command.Valid.t * _ list ] = function
  | User_command.Signed_command c -> (
      match Signed_command.check c with
      | None ->
          `Invalid
      | Some c ->
          `Valid (User_command.Signed_command c) )
  | _ ->
      failwith "TODO"
