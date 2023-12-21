open Core
open Signature_lib
open Mina_base

module Location : Merkle_ledger.Location_intf.S

module Db :
  Merkle_ledger.Database_intf.S
    with module Location = Location
    with module Addr = Location.Addr
    with type root_hash := Ledger_hash.t
     and type hash := Ledger_hash.t
     and type account := Account.t
     and type key := Public_key.Compressed.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t

module Any_ledger :
  Merkle_ledger.Any_ledger.S
    with module Location = Location
    with type account := Account.t
     and type key := Public_key.Compressed.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
     and type hash := Ledger_hash.t

module Mask :
  Merkle_mask.Masking_merkle_tree_intf.S
    with module Location = Location
     and module Attached.Addr = Location.Addr
    with type account := Account.t
     and type key := Public_key.Compressed.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
     and type hash := Ledger_hash.t
     and type location := Location.t
     and type parent := Any_ledger.M.t

module Maskable :
  Merkle_mask.Maskable_merkle_tree_intf.S
    with module Location = Location
    with module Addr = Location.Addr
    with type account := Account.t
     and type key := Public_key.Compressed.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
     and type hash := Ledger_hash.t
     and type root_hash := Ledger_hash.t
     and type unattached_mask := Mask.t
     and type attached_mask := Mask.Attached.t
     and type t := Any_ledger.M.t

include
  Merkle_mask.Maskable_merkle_tree_intf.S
    with module Location := Location
    with module Addr = Location.Addr
    with type root_hash := Ledger_hash.t
     and type hash := Ledger_hash.t
     and type account := Account.t
     and type key := Public_key.Compressed.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
     and type t = Mask.Attached.t
     and type attached_mask = Mask.Attached.t
     and type unattached_mask = Mask.t

(* We override the type of unregister_mask_exn that comes from
   Merkle_mask.Maskable_merkle_tree_intf.S because at this level callers aren't
   doing reparenting and shouldn't be able to turn off the check parameter.
*)
val unregister_mask_exn : loc:string -> Mask.Attached.t -> Mask.t

(* The maskable ledger is t = Mask.Attached.t because register/unregister
 * work off of this type *)
type maskable_ledger = t

val with_ledger : depth:int -> f:(t -> 'a) -> 'a

val with_ephemeral_ledger : depth:int -> f:(t -> 'a) -> 'a

val create : ?directory_name:string -> depth:int -> unit -> t

val create_ephemeral : depth:int -> unit -> t

val of_database : Db.t -> t

(** This is not _really_ copy, merely a stop-gap until we remove usages of copy in our codebase. What this actually does is creates a new empty mask on top of the current ledger *)
val copy : t -> t

val register_mask : t -> Mask.t -> Mask.Attached.t

val commit : Mask.Attached.t -> unit

include
  Mina_transaction_logic.S with type ledger := t and type location := Location.t

(** Raises if the ledger is full, or if an account already exists for the given
    [Account_id.t].
*)
val create_new_account_exn : t -> Account_id.t -> Account.t -> unit

(** update action state, returned slot is new last action slot
    made available here so we can use this logic in the Zkapp_command generators
*)
val update_action_state :
     Snark_params.Tick.Field.t Pickles_types.Vector.Vector_5.t
  -> Zkapp_account.Actions.t
  -> txn_global_slot:Mina_numbers.Global_slot_since_genesis.t
  -> last_action_slot:Mina_numbers.Global_slot_since_genesis.t
  -> Snark_params.Tick.Field.t Pickles_types.Vector.Vector_5.t
     * Mina_numbers.Global_slot_since_genesis.t

val has_locked_tokens :
     global_slot:Mina_numbers.Global_slot_since_genesis.t
  -> account_id:Account_id.t
  -> t
  -> bool Or_error.t

val merkle_root_after_zkapp_command_exn :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> global_slot:Mina_numbers.Global_slot_since_genesis.t
  -> txn_state_view:Zkapp_precondition.Protocol_state.View.t
  -> t
  -> Zkapp_command.Valid.t
  -> Ledger_hash.t

val merkle_root_after_user_command_exn :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_global_slot:Mina_numbers.Global_slot_since_genesis.t
  -> t
  -> Signed_command.With_valid_signature.t
  -> Ledger_hash.t

(** Raises if the ledger is full. *)
val create_empty_exn : t -> Account_id.t -> Path.t * Account.t

val num_accounts : t -> int

type init_state =
  ( Signature_lib.Keypair.t
  * Currency.Amount.t
  * Mina_numbers.Account_nonce.t
  * Account_timing.t )
  array
[@@deriving sexp_of]

(** Generate an initial ledger state. There can't be a regular Quickcheck
    generator for this type because you need to detach a mask from its parent
    when you're done with it - the GC doesn't take care of that. *)
val gen_initial_ledger_state : init_state Quickcheck.Generator.t

(** Apply a generated state to a blank, concrete ledger. *)
val apply_initial_ledger_state : t -> init_state -> unit

module Ledger_inner : Ledger_intf.S with type t = t

module For_tests : sig
  open Currency
  open Mina_numbers

  val validate_timing_with_min_balance :
       account:Account.t
    -> txn_amount:Amount.t
    -> txn_global_slot:Global_slot_since_genesis.t
    -> (Account.Timing.t * [> `Min_balance of Balance.t ]) Or_error.t

  val validate_timing :
       account:Account.t
    -> txn_amount:Amount.t
    -> txn_global_slot:Global_slot_since_genesis.t
    -> Account.Timing.t Or_error.t
end
