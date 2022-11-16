open Signature_lib
open Mina_base
open Pickles_types

val compile : unit -> unit

val tag :
  ( Zkapp_statement.Checked.t
  , Zkapp_statement.t
  , Nat.N2.n
  , Nat.N3.n )
  Pickles.Tag.t
  Lazy.t

val vk : Pickles.Side_loaded.Verification_key.t Lazy.t

module P :
  Pickles.Proof_intf
    with type statement = Zkapp_statement.t
     and type t = (Nat.N2.n, Nat.N2.n) Pickles.Proof.t

val initialize :
     Public_key.Compressed.t
  -> Token_id.t
  -> unit
  -> ( ( Account_update.t
       , Zkapp_command.Digest.Account_update.t
       , Zkapp_command.Digest.Forest.t )
       Zkapp_command.Call_forest.tree
     * unit )
     Async_kernel.Deferred.t

val mint :
     owner_public_key:Public_key.Compressed.t
  -> owner_token_id:Token_id.t
  -> amount:Currency.Amount.t
  -> mint_to_public_key:Public_key.Compressed.t
  -> unit
  -> ( ( Account_update.t
       , Zkapp_command.Digest.Account_update.t
       , Zkapp_command.Digest.Forest.t )
       Zkapp_command.Call_forest.tree
     * unit )
     Async_kernel.Deferred.t

val child_forest :
     Public_key.Compressed.t
  -> Token_id.t
  -> unit
  -> ( ( Account_update.t
       , Zkapp_command.Digest.Account_update.t
       , Zkapp_command.Digest.Forest.t )
       Zkapp_command.Call_forest.tree
     * unit )
     Async_kernel.Deferred.t
