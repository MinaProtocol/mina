(** Domain types for the verification application.

    This module defines the core types used throughout the verification process,
    providing type safety and clear domain modeling for configuration validation.
*)

open Core

(** Configuration for executable paths used during verification *)
type executable_paths =
  { mina : string  (** Path to the mina CLI executable *)
  ; mina_genesis : string  (** Path to the mina-create-genesis executable *)
  ; mina_legacy_genesis : string
        (** Path to the mina-create-legacy-genesis executable *)
  ; create_runtime_config : string
        (** Path to the create runtime config script *)
  ; gsutil : string  (** Path to gsutil for GCS operations *)
  }
[@@deriving sexp_of]

(** Main validation configuration *)
type validation_config =
  { network_name : string  (** Name of the network (e.g., mainnet, devnet) *)
  ; fork_config : string  (** Path to the fork configuration JSON file *)
  ; workdir : string  (** Working directory for temporary files and outputs *)
  ; precomputed_block_prefix : string  (** GCS prefix for precomputed blocks *)
  ; packaged_daemon_config : string
        (** Path to the packaged daemon configuration *)
  ; genesis_ledger_dir : string
        (** Directory containing genesis ledger files *)
  ; seconds_per_slot : string  (** Network parameter: seconds per slot *)
  ; forking_from_config_json : string
        (** Path to the config JSON we're forking from *)
  ; executables : executable_paths  (** Paths to all required executables *)
  ; precomputed_fork_block : string option
        (** Optional explicit path to precomputed fork block *)
  ; test_ledger_download : bool
        (** Whether to test ledger download functionality *)
  ; mina_log_level : string  (** Log level for mina daemon *)
  ; mina_ledger_s3_bucket : string  (** S3 bucket URL for ledger storage *)
  }
[@@deriving sexp_of]

(** Individual validation steps in the verification process *)
type validation_step =
  | ExecutableResolution  (** Resolving paths to required executables *)
  | PrecomputedBlockFetch  (** Fetching the precomputed fork block *)
  | LibP2PKeyGeneration  (** Generating libp2p keypair *)
  | LegacyLedgerGeneration  (** Generating legacy format ledgers *)
  | LegacyHashVerification
      (** Verifying legacy hashes match precomputed block *)
  | NewLedgerGeneration  (** Generating new format ledgers *)
  | RuntimeConfigCreation  (** Creating runtime configuration *)
  | LedgerExport of string
      (** Exporting ledgers from daemon (with config name) *)
  | ConfigHashComparison  (** Comparing configuration hashes *)
  | LedgerComparison of string  (** Comparing ledger JSON files *)
  | RocksDBComparison of string  (** Comparing RocksDB database contents *)
[@@deriving sexp_of]

(** Error information for validation failures *)
type validation_error =
  { step : validation_step  (** The step where validation failed *)
  ; message : string  (** Human-readable error message *)
  ; details : string option  (** Optional additional details *)
  }
[@@deriving sexp_of]

(** Ledger hashes extracted from various sources *)
type ledger_hashes =
  { staking_hash : string  (** Hash of the staking epoch ledger *)
  ; next_hash : string  (** Hash of the next epoch ledger *)
  ; ledger_hash : string  (** Hash of the main ledger *)
  }
[@@deriving sexp_of, compare, equal]

(** Result of hash comparison between two sources *)
type hash_comparison_result =
  { field_name : string  (** Name of the hash field being compared *)
  ; source1_hash : string  (** Hash from first source *)
  ; source2_hash : string  (** Hash from second source *)
  ; matches : bool  (** Whether the hashes match *)
  }
[@@deriving sexp_of]

(** Result type for validation operations *)
type 'a validation_result = ('a, validation_error) Result.t Async.Deferred.t
