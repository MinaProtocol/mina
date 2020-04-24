open Core
open Async
open Coda_base
open Coda_state

(** Dummy hash. Unit tests should be run with proof_level=check. *)
val unit_test_base_hash : Snark_params.Tick.Field.t

(** Dummy proof. Unit tests should be run with proof_level=check. *)
val unit_test_base_proof : Proof.t

type t =
  { runtime_config: Runtime_config.t
  ; genesis_ledger: Genesis_ledger.Packed.t
  ; genesis_protocol_state: (Protocol_state.Value.t, State_hash.t) With_hash.t
  ; base_hash: State_hash.t
  ; base_proof: Proof.t }

val for_unit_tests : t Lazy.t

val get_ledger : Runtime_config.t -> Genesis_ledger.Packed.t

(** Load the data necessary for the runtime configuration.

    [not_found] sets the behaviour if an existing base proof is not available.
*)
val load_values :
     logger:Logger.t
  -> not_found:[`Error | `Generate | `Generate_and_store]
  -> runtime_config:Runtime_config.t
  -> unit
  -> t Or_error.t Deferred.t

(** [load_base_proof ~logger directory] load the base proof from a
    configuration directory.
*)
val load_base_proof :
  logger:Logger.t -> string -> (Runtime_config.t * Proof.t) option

val of_base_proof :
  runtime_config:Runtime_config.t -> base_proof:Proof.t -> t Deferred.t

(** Store the runtime configuration and base proof under the given root
    directory. The files are stored according to the names expected by
    [create_tar] below.
*)
val store_base_proof : root_directory:string -> t -> unit Deferred.t

(** [create_tar ~base_hash ~tar_file dirname] packages the precomputed values
    associated with [base_hash] into a .tar.gz file with path [tar_file].

    The precomputed values are expected to be in
    [dirname ^/ "base_proof_" ^ base_hash]
    and the default .tar.gz file name is
    [dirname ^/ "base_proof_" ^ base_hash ^ ".tar.gz"]
*)
val create_tar :
  base_hash:State_hash.t -> ?tar_file:string -> string -> unit Deferred.t
