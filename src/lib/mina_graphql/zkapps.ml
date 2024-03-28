open Core
open Async
open Mina_transaction

let send_zkapp_command mina zkapp_command =
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
          Error
            (sprintf "Couldn't send zkApp command: %s" (Error.to_string_hum e))
      )
  | `Bootstrapping ->
      return (Error "Daemon is bootstrapping")
