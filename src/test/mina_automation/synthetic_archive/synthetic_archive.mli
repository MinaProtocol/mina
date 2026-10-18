(** Synthetic archives: databases on the real archive schema with hand-built
    chain content, for tests.

    A test describes the chain situation it needs -- accounts, blocks with any
    height / parent / status, commands with a status per block -- and the
    builder writes the minimal valid archive rows for it into a fresh database
    created from the real [create_schema.sql] (optionally migrated with
    [upgrade.sql]). Every column the test does not mention gets a fixed
    default, so a scenario reads like the situation it sets up.

    Names given to accounts, blocks and commands are turned into deterministic
    values (a real public key per account name, a hash per command name), so a
    failing assertion reads in the test's own terms. *)

open Async

(** {1 Databases} *)

module Db : sig
  type t = { name : string; uri : Uri.t }

  (** [create ~server_uri ~name ()] creates database [name] on the server
      [server_uri] points at (its path, if any, is ignored) and loads
      [create_schema.sql] and, with [~upgrade:true], [upgrade.sql]. A database
      of the same name left by an earlier run is dropped first, so [name] must
      start with [test_]; any other name is refused. *)
  val create :
       ?upgrade:bool
    -> server_uri:Uri.t
    -> name:string
    -> unit
    -> t Deferred.Or_error.t

  val drop : t -> unit Deferred.Or_error.t

  (** Run one of the archive's schema scripts on [t], e.g. [`Upgrade] then
      [`Rollback] for the schema of an archive from before an upgrade. A dune
      test must declare the script as a dependency. *)
  val run_script :
       t
    -> [ `CreateSchema | `DropTables | `Upgrade | `Rollback ]
    -> unit Deferred.Or_error.t

  (** The server [MINA_TEST_POSTGRES] names, as CI sets it. A test that needs
      a database calls this first: without the variable it exits with status
      2 and a message, so a missing server is never a silent pass. *)
  val test_server_uri : unit -> Uri.t

  (** [with_connection db f] runs [f] on a connection to [db] and closes it
      whatever happens, so the database can be dropped afterwards. *)
  val with_connection :
    t -> ((module Mina_caqti.CONNECTION) -> 'a Deferred.t) -> 'a Deferred.t

  (** [with_fresh ~server_uri ~name f] runs [f] on a database made by
      {!create} and drops it again unless [~keep:true]. *)
  val with_fresh :
       ?upgrade:bool
    -> ?keep:bool
    -> server_uri:Uri.t
    -> name:string
    -> (t -> 'a Deferred.Or_error.t)
    -> 'a Deferred.Or_error.t
end

(** {1 Scenarios}

    Optional arguments come first, then the scenario [t], then the rest. *)

type chain_status = Canonical | Orphaned | Pending

type command_status = Applied | Failed of string

type t

type account

type block

type user_command

type zkapp_command

type coinbase

type account_update

val create : unit -> t

(** An account on the default token. The same name gives the same key. *)
val account : t -> string -> account

(** The account's public key, base58. *)
val public_key : account -> string

(** A block. [state_hash] defaults to a value derived from [name]; [parent]
    must be a block of this scenario, and its state hash becomes this block's
    [parent_hash] (or [parent_hash] when given, e.g. for a block whose parent
    is not in the archive). Slots default to [height - 1]; [protocol_version]
    to [(4, 0, 0)]; [timestamp] (epoch ms) to a value derived from the slot. *)
val block :
     ?state_hash:string
  -> ?parent:block
  -> ?parent_hash:string
  -> ?global_slot_since_genesis:int
  -> ?global_slot_since_hard_fork:int
  -> ?protocol_version:int * int * int
  -> ?timestamp:int64
  -> ?creator:account
  -> t
  -> name:string
  -> height:int
  -> chain_status
  -> block

val state_hash : block -> string

(** A payment, included in each of [in_] with its own status. The command's
    position in a block follows the order commands are added to that block. *)
val payment :
     ?fee_payer:account
  -> ?amount:int
  -> ?fee:int
  -> t
  -> name:string
  -> source:account
  -> receiver:account
  -> in_:(block * command_status) list
  -> user_command

val delegation :
     ?fee_payer:account
  -> ?fee:int
  -> t
  -> name:string
  -> delegator:account
  -> delegate:account
  -> in_:(block * command_status) list
  -> user_command

val user_command_hash : user_command -> string

(** A coinbase paid to [receiver] in [block], applied. *)
val coinbase :
  ?amount:int -> t -> name:string -> receiver:account -> block -> coinbase

(** A zkApp account update on [account]. Equal account updates share one
    archive row, as the archive stores them, so listing the same one twice in
    a command repeats its id in [zkapp_account_updates_ids]. *)
val account_update :
     ?balance_change:int
  -> ?implicit_account_creation_fee:bool
  -> account
  -> account_update

(** A zkApp command paid by [fee_payer], included in each of [in_]. A failed
    inclusion records its reason as the first account update's failure. *)
val zkapp_command :
     ?fee:int
  -> t
  -> name:string
  -> fee_payer:account
  -> account_updates:account_update list
  -> in_:(block * command_status) list
  -> zkapp_command

val zkapp_command_hash : zkapp_command -> string

(** The coinbase's hash in [internal_commands]. *)
val coinbase_hash : coinbase -> string

(** Record that [block] created [account], charging [fee]. *)
val account_created : ?fee:int -> t -> block -> account -> unit

(** A vesting schedule, in nanomina and slots. *)
type timing =
  { initial_minimum_balance : int
  ; cliff_time : int
  ; cliff_amount : int
  ; vesting_period : int
  ; vesting_increment : int
  }

(** The state [block] recorded for [account], written as the archive writes
    it: an [accounts_accessed] row, with a schedule of zeros when there is no
    [timing]. [nonce] defaults to 0. *)
val account_state :
  ?nonce:int -> ?timing:timing -> t -> block -> account -> balance:int -> unit

(** [account] in the genesis ledger that takes effect at [genesis_height],
    written by the archive's genesis ledger writer. *)
val genesis_account :
     ?nonce:int
  -> ?timing:timing
  -> t
  -> genesis_height:int
  -> account
  -> balance:int
  -> unit

(** What [materialize] wrote, for tests that need database ids. *)
type built

val block_id : built -> block -> int

val user_command_id : built -> user_command -> int

val zkapp_command_id : built -> zkapp_command -> int

(** The coinbase's id in [internal_commands]. *)
val coinbase_id : built -> coinbase -> int

(** Write the scenario into [db]. A scenario is written once, into an
    archive with no blocks; anything else is an error. Within a
    block, user commands come first, then zkApp commands, then coinbases,
    each in the order they were added. *)
val materialize : t -> Db.t -> built Deferred.Or_error.t
