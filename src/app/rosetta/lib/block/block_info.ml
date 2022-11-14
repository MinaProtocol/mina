open Core_kernel
open Rosetta_lib
open Rosetta_models

(* TODO: should timestamp be string?; Block_time.t is an unsigned 64-bit int *)
type t =
  { block_identifier : Block_identifier.t
  ; parent_block_identifier : Block_identifier.t
  ; creator : [ `Pk of string ]
  ; winner : [ `Pk of string ]
  ; timestamp : int64
  ; internal_info : Internal_command_info.t list
  ; user_commands : User_command_info.t list
  ; zkapp_commands : Zkapp_command_info.t list
  ; zkapps_account_updates : Zkapp_account_update_info.t list
  }

let creator_metadata { creator = `Pk pk; _ } =
  `Assoc [ ("creator", `String pk) ]

let block_winner_metadata { winner = `Pk pk; _ } =
  `Assoc [ ("winner", `String pk) ]

let dummy =
  { block_identifier =
      Block_identifier.create (Int64.of_int_exn 4) "STATE_HASH_BLOCK"
  ; creator = `Pk "Alice"
  ; winner = `Pk "Babu"
  ; parent_block_identifier =
      Block_identifier.create (Int64.of_int_exn 3) "STATE_HASH_PARENT"
  ; timestamp = Int64.of_int_exn 1594937771
  ; internal_info = Internal_command_info.dummies
  ; user_commands = User_command_info.dummies
  ; zkapp_commands = Zkapp_command_info.dummies
  ; zkapps_account_updates = Zkapp_account_update_info.dummies
  }
