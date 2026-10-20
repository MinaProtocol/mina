(* Reads rows back through the archive's own Processor loaders, so the tests
   check what the archive reads, not a query of their own. *)

open Async
module B = Synthetic_archive
module P = Archive_lib.Processor

let ok ~ctx result = result >>| Mina_caqti.ok_exn ~ctx

let block conn id = ok ~ctx:"block" (P.Block.load conn ~id)

let protocol_version conn id =
  ok ~ctx:"protocol version" (P.Protocol_versions.load conn id)

let public_key conn id = ok ~ctx:"public key" (P.Public_key.find_by_id conn id)

let public_key_of_identifier conn id =
  let%bind identifier =
    ok ~ctx:"account identifier" (P.Account_identifiers.load conn id)
  in
  public_key conn identifier.public_key_id

let user_command conn id =
  ok ~ctx:"user command" (P.User_command.Signed_command.load conn ~id)

let user_command_inclusion conn ~block_id ~user_command_id ~sequence_no =
  ok ~ctx:"user command inclusion"
    (P.Block_and_signed_command.load conn ~block_id ~user_command_id
       ~sequence_no )

let internal_command conn id =
  ok ~ctx:"internal command" (P.Internal_command.load conn ~id)

let internal_command_inclusion conn ~block_id ~internal_command_id ~sequence_no
    =
  ok ~ctx:"internal command inclusion"
    (P.Block_and_internal_command.load conn ~block_id ~internal_command_id
       ~sequence_no ~secondary_sequence_no:0 )

let accounts_created conn ~block_id =
  ok ~ctx:"accounts created" (P.Accounts_created.all_from_block conn block_id)

let zkapp_command conn id =
  ok ~ctx:"zkapp command" (P.User_command.Zkapp_command.load conn id)

let zkapp_command_inclusion conn ~block_id ~zkapp_command_id ~sequence_no =
  ok ~ctx:"zkapp command inclusion"
    (P.Block_and_zkapp_command.load conn ~block_id ~zkapp_command_id
       ~sequence_no )

let zkapp_failure conn id =
  ok ~ctx:"zkapp failure" (P.Zkapp_account_update_failures.load conn id)

let account_update_body conn account_update_id =
  let%bind update =
    ok ~ctx:"account update"
      (P.Zkapp_account_update.load conn account_update_id)
  in
  ok ~ctx:"account update body"
    (P.Zkapp_account_update_body.load conn update.body_id)
