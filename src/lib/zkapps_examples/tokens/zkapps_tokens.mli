open Signature_lib
open Mina_base
open Pickles_types

val compile : unit -> unit

val tag :
  ( Zkapp_statement.Checked.t
  , Zkapp_statement.t
  , Nat.N0.n
  , Nat.N2.n )
  Pickles.Tag.t
  Lazy.t

val vk : Pickles.Side_loaded.Verification_key.t Lazy.t

module P :
  Pickles.Proof_intf
    with type statement = Zkapp_statement.t
     and type t = (Nat.N0.n, Nat.N0.n) Pickles.Proof.t

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

val update_state :
     Public_key.Compressed.t
  -> Token_id.t
  -> Snark_params.Tick.Field.t list
  -> unit
  -> ( ( Account_update.t
       , Zkapp_command.Digest.Account_update.t
       , Zkapp_command.Digest.Forest.t )
       Zkapp_command.Call_forest.tree
     * unit )
     Async_kernel.Deferred.t
