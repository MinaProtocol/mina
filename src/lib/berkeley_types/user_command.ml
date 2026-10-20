(* A user command of the Berkeley era, as a precomputed block writes it. A
   zkApp command's call forest is written with the digest of each account
   update and the hash of each stack, so a command keeps them as read,
   which lets it be written back without the Berkeley account update
   hashing. *)

module Digest = Mina_base.Zkapp_command.Digest

type zkapp_command =
  ( Account_update.t
  , Digest.Account_update.t
  , Digest.Forest.t )
  Mina_base.Zkapp_command.with_forest

type t =
  (Mina_base.Signed_command.t, zkapp_command) Mina_base.User_command.Poly.t

let to_yojson : t -> Yojson.Safe.t =
  Mina_base.User_command.Poly.to_yojson Mina_base.Signed_command.to_yojson
    (Mina_base.Zkapp_command.with_forest_to_yojson
       Account_update.Stable.Latest.to_yojson Digest.Account_update.to_yojson
       Digest.Forest.to_yojson )

let of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or =
  Mina_base.User_command.Poly.of_yojson Mina_base.Signed_command.of_yojson
    (Mina_base.Zkapp_command.with_forest_of_yojson
       Account_update.Stable.Latest.of_yojson Digest.Account_update.of_yojson
       Digest.Forest.of_yojson )

let forget_digests ({ fee_payer; account_updates; memo } : zkapp_command) :
    Zkapp_command.Stable.V1.t =
  { fee_payer
  ; account_updates =
      Mina_base.Zkapp_command.Call_forest.forget_hashes account_updates
  ; memo
  }

(** The transaction hash of [t], by the Berkeley rules. Those for signed
    commands are unchanged. *)
let hash : t -> Mina_transaction.Transaction_hash.t = function
  | Signed_command signed_command ->
      Mina_transaction.Transaction_hash.hash_signed_command signed_command
  | Zkapp_command zkapp_command ->
      Zkapp_command.hash (forget_digests zkapp_command)

let to_mesa : t -> Mina_base.User_command.Stable.Latest.t = function
  | Signed_command signed_command ->
      Signed_command signed_command
  | Zkapp_command zkapp_command ->
      Zkapp_command (Zkapp_command.to_mesa (forget_digests zkapp_command))
