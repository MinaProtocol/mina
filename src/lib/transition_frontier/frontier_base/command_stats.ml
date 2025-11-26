open Core_kernel
open Mina_base

type t = { total : int; zkapp_commands : int; has_coinbase : bool }

let has_coinbase (staged_ledger_diff : Staged_ledger_diff.t) =
  let d1, d2 = staged_ledger_diff.diff in
  match (d1.coinbase, d2) with
  | Zero, None | Zero, Some { coinbase = Zero; _ } ->
      false
  | Zero, Some { coinbase = One _; _ } | One _, _ | Two _, _ ->
      true

let of_body (body : Mina_block.Body.t) =
  let staged_ledger_diff = Staged_ledger_diff.Body.staged_ledger_diff body in
  Staged_ledger_diff.commands staged_ledger_diff
  |> List.fold
       ~init:
         { total = 0
         ; zkapp_commands = 0
         ; has_coinbase = has_coinbase staged_ledger_diff
         }
       ~f:
         (fun v -> function
           | { With_status.data = User_command.Signed_command _; _ } ->
               { v with total = v.total + 1 }
           | { data = Zkapp_command _; _ } ->
               { v with
                 total = v.total + 1
               ; zkapp_commands = v.zkapp_commands + 1
               } )
