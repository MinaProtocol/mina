open Core
open Async
open Mina_transaction
open Re2

let send_zkapp_command mina zkapp_command =
  let update_error_message error_msg =
    (* Define the pattern to match and the replacement message *)
    let pattern =
      Re2.create_exn "Verification_failed \\(Invalid_proof \"In progress\"\\)"
    in
    let replacement =
      "Stale verification key detected. Please make sure that deployed \
       verification key reflects zkApp changes."
    in
    (* Replace the matched pattern with the replacement message *)
    Re2.replace_exn pattern ~f:(fun _ -> replacement) error_msg
  in
  match Mina_commands.setup_and_submit_zkapp_command mina zkapp_command with
  | `Active f -> (
      match%map f with
      | Ok zkapp_command ->
          let cmd =
            { Types.Zkapp_command.With_status.data = zkapp_command
            ; status = Enqueued
            }
          in
          let cmd_with_hash =
            Types.Zkapp_command.With_status.map cmd ~f:(fun cmd ->
                { With_hash.data = cmd
                ; hash = Transaction_hash.hash_command (Zkapp_command cmd)
                } )
          in
          Ok cmd_with_hash
      | Error e ->
          let original_error_msg = Error.to_string_hum e in
          let updated_error_msg = update_error_message original_error_msg in
          Error (sprintf "Couldn't send zkApp command: %s" updated_error_msg) )
  | `Bootstrapping ->
      return (Error "Daemon is bootstrapping")
