open Core_kernel
open Mina_base

type t = { total : int; zkapp_commands : int }

let of_body (body : Mina_block.Body.t) =
  Staged_ledger_diff.Body.staged_ledger_diff body
  |> Staged_ledger_diff.commands
  |> List.fold ~init:{ total = 0; zkapp_commands = 0 }
       ~f:(fun { total; zkapp_commands } -> function
       | { With_status.data = User_command.Signed_command _; _ } ->
           { total = total + 1; zkapp_commands }
       | { data = Zkapp_command _; _ } ->
           { total = total + 1; zkapp_commands = zkapp_commands + 1 } )
