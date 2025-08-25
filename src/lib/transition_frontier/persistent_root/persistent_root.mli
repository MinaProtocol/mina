open Core
open Mina_base
open Frontier_base
open Mina_ledger.Ledger

module rec Instance_type : sig
  type t =
    { snarked_ledger : Root.t
    ; potential_snarked_ledgers : Root.Config.t Queue.t
    ; factory : Factory_type.t
    }
end

and Factory_type : sig
  type t =
    { directory : string
    ; logger : Logger.t
    ; mutable instance : Instance_type.t option
    ; ledger_depth : int
    ; backing_type : Root.Config.backing_type
    }
end

module Instance : sig
  type t = Instance_type.t

  module Config : sig
    (** Helper to create a filesystem location (for a file or directory) inside
        the [Factory_type.t] directory. *)
    val make_instance_location : string -> Factory_type.t -> string

    (** Helper to create a [Root.Config.t] for a snarked ledger based on a
        subdirectory of the [Factory_type.t] directory *)
    val make_instance_config : string -> Factory_type.t -> Root.Config.t

    (** The config for the actual snarked ledger that is initialized and used by
        the daemon *)
    val snarked_ledger : Factory_type.t -> Root.Config.t

    (** The config for the temporary snarked ledger, used while recovering a
        vaild potential snarked ledger during startup *)
    val tmp_snarked_ledger : Factory_type.t -> Root.Config.t

    (** The name of a json file that lists the directory names of the potential
        snarked ledgers in the [potential_snarked_ledgers] queue *)
    val potential_snarked_ledgers : Factory_type.t -> string

    (** A method that generates fresh potential snarked ledger configs, each
        using a distinct root subdirectory *)
    val make_potential_snarked_ledger : Factory_type.t -> Root.Config.t

    (** The name of the file recording the [Root_identifier.t] of the snarked
        root *)
    val root_identifier : Factory_type.t -> string
  end

  val enqueue_snarked_ledger : config:Root.Config.t -> t -> unit

  val dequeue_snarked_ledger : t -> unit

  val destroy : t -> unit

  val close : t -> unit

  val create : logger:Logger.t -> Factory_type.t -> t

  (** When we load from disk,
      1. Check the potential_snarked_ledgers to see if any one of these
         matches the snarked_ledger_hash in persistent_frontier;
      2. if none of those works, we load the old snarked_ledger and check if
         the old snarked_ledger matches with persistent_frontier;
      3. if not, we just reset all the persisted data and start from genesis
   *)
  val load_from_disk :
       Factory_type.t
    -> snarked_ledger_hash:Frozen_ledger_hash.t
    -> logger:Logger.t
    -> (t, [> `Snarked_ledger_mismatch ]) result

  val snarked_ledger : t -> Root.t

  val set_root_identifier : t -> Root_identifier.t -> unit

  val load_root_identifier : t -> Root_identifier.t option

  val set_root_state_hash : t -> Frozen_ledger_hash.t -> unit
end

type t = Factory_type.t

val create : logger:Logger.t -> directory:string -> ledger_depth:int -> t

val create_instance_exn : t -> Instance_type.t

val load_from_disk_exn :
     t
  -> snarked_ledger_hash:Frozen_ledger_hash.t
  -> logger:Logger.t
  -> (Instance_type.t, [> `Snarked_ledger_mismatch ]) result

val with_instance_exn : t -> f:(Instance_type.t -> 'a) -> 'a

val reset_to_genesis_exn : t -> precomputed_values:Genesis_proof.t -> unit
