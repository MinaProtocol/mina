(** The data structure underlying the transaction pool. We want to efficently
    support all the operations necessary. We also need to make sure that an
    attacker can't craft transactions or sequences thereof that take up an
    unacceptable amount of resources leading to a DoS.
*)
open Core

open Mina_base
open Mina_transaction
open Mina_numbers

module Command_error : sig
  type t =
    | Invalid_nonce of
        [ `Expected of Account.Nonce.t
        | `Between of Account.Nonce.t * Account.Nonce.t ]
        * Account.Nonce.t
    | Insufficient_funds of
        [ `Balance of Currency.Amount.t ] * Currency.Amount.t
    | (* NOTE: don't punish for this, attackers can induce nodes to banlist
          each other that way! *)
        Insufficient_replace_fee of
        [ `Replace_fee of Currency.Fee.t ] * Currency.Fee.t
    | Overflow
    | Bad_token
    | Expired of
        [ `Valid_until of Mina_numbers.Global_slot.t
        | `Timestamp_predicate of string ]
        * [ `Global_slot_since_genesis of Mina_numbers.Global_slot.t ]
    | Unwanted_fee_token of Mina_base.Token_id.t
  [@@deriving sexp, to_yojson]

  val grounds_for_diff_rejection : t -> bool
end

val replace_fee : Currency.Fee.t

module Config : sig
  type t
end

module Sender_local_state : sig
  type t [@@deriving sexp, to_yojson]

  val sender : t -> Account_id.t

  val is_remove : t -> bool
end

(** Transaction pool. This is a purely functional data structure. *)
type t [@@deriving sexp_of]

val config : t -> Config.t

val get_sender_local_state : t -> Account_id.t -> Sender_local_state.t

val set_sender_local_state : t -> Sender_local_state.t -> t

module rec Update : sig
  val apply : Update.t -> t -> t

  type t [@@deriving to_yojson, sexp]

  val merge : t -> t -> t

  val empty : t
end

(* TODO sexp is debug only, remove *)

(** Empty pool *)
val empty :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> consensus_constants:Consensus.Constants.t
  -> time_controller:Block_time.Controller.t
  -> expiry_ns:Time_ns.Span.t
  -> t

(** How many transactions are currently in the pool *)
val size : t -> int

(* The least fee per weight unit of all transactions in the transaction pool *)
val min_fee : t -> Currency.Fee_rate.t option

val transactions :
  t -> Transaction_hash.User_command_with_valid_signature.t Sequence.t

(** Remove the command from the pool with the lowest fee per wu,
    along with any others from the same account with higher nonces. *)
val remove_lowest_fee :
  t -> Transaction_hash.User_command_with_valid_signature.t Sequence.t * t

(** Remove all the user commands that are expired. (Valid-until < Current-global-slot) *)
val remove_expired :
  t -> Transaction_hash.User_command_with_valid_signature.t Sequence.t * t

(** Get the applicable command in the pool with the highest fee per wu *)
val get_highest_fee :
  t -> Transaction_hash.User_command_with_valid_signature.t option

(** Add a command to the pool. Pass the current nonce for the account and
    its current balance. Throws if the contents of the pool before adding the
    new command are invalid given the supplied current nonce and balance - you
    are required to keep the pool in sync with the ledger you are applying
    transactions against.
*)
val add_from_gossip_exn :
     t
  -> Transaction_hash.User_command_with_valid_signature.t
  -> Account_nonce.t
  -> Currency.Amount.t
  -> ( Transaction_hash.User_command_with_valid_signature.t
       * t
       * Transaction_hash.User_command_with_valid_signature.t Sequence.t
     , Command_error.t )
     Result.t
(** Returns the commands dropped as a result of adding the command, which will
    be empty unless we're replacing one. *)

(** Add a command to the pool that was removed from the best tip because we're
    switching chains. Must be called in reverse order i.e. newest-to-oldest.
*)
val add_from_backtrack :
     t
  -> Transaction_hash.User_command_with_valid_signature.t
  -> (t, Command_error.t) Result.t

(** Check whether a command is in the pool *)
val member : t -> Transaction_hash.User_command.t -> bool

(** Check whether the pool has any commands for a given fee payer *)
val has_commands_for_fee_payer : t -> Account_id.t -> bool

(** Get all the user commands sent by a user with a particular account *)
val all_from_account :
  t -> Account_id.t -> Transaction_hash.User_command_with_valid_signature.t list

(** Get all user commands in the pool. *)
val get_all : t -> Transaction_hash.User_command_with_valid_signature.t list

val find_by_hash :
     t
  -> Transaction_hash.t
  -> Transaction_hash.User_command_with_valid_signature.t option

(** Check the contents of the pool are valid against the current ledger. Call
    this whenever the transition frontier is (re)created.
*)
val revalidate :
     t
  -> [ `Entire_pool | `Subset of Account_id.Set.t ]
  -> (Account_id.t -> Account_nonce.t * Currency.Amount.t)
     (** Lookup an account in the new ledger *)
  -> t * Transaction_hash.User_command_with_valid_signature.t Sequence.t

(** Get the global slot since genesis according to the pool's time controller. *)
val global_slot_since_genesis : t -> Mina_numbers.Global_slot.t

module For_tests : sig
  (** Checks the invariants of the data structure. If this throws an exception
      there is a bug. *)
  val assert_invariants : t -> unit
end
