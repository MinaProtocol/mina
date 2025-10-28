(** Constants used throughout the verification application.

    This module centralizes all magic values, default paths, and configuration
    constants to improve maintainability and avoid scattered literals.
*)

open Core

(** Default paths and locations *)
module Paths = struct
  let default_genesis_ledger_dir = "/var/lib/coda"

  let default_forking_from_config = "/var/lib/coda/mainnet.json"

  let fallback_forking_from_config = "genesis_ledgers/mainnet.json"

  let mina_lock_file = "~/.mina-config/.mina-lock"

  let installed_config_glob = "/var/lib/coda/config_*.json"
end

(** Default executable paths (fallbacks when not in PATH) *)
module Executables = struct
  let mina_fallback = "./_build/default/src/app/cli/src/mina.exe"

  let mina_genesis_fallback =
    "./_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe"

  let mina_legacy_genesis_fallback = "./runtime_genesis_ledger_of_mainnet.exe"

  let create_runtime_config_fallback =
    "./scripts/hardfork/create_runtime_config.sh"
end

(** Environment variable names *)
module EnvVars = struct
  let mina_exe = "MINA_EXE"

  let mina_genesis_exe = "MINA_GENESIS_EXE"

  let mina_legacy_genesis_exe = "MINA_LEGACY_GENESIS_EXE"

  let create_runtime_config = "CREATE_RUNTIME_CONFIG"

  let gsutil = "GSUTIL"

  let precomputed_fork_block = "PRECOMPUTED_FORK_BLOCK"

  let packaged_daemon_config = "PACKAGED_DAEMON_CONFIG"

  let genesis_ledger_dir = "GENESIS_LEDGER_DIR"

  let forking_from_config_json = "FORKING_FROM_CONFIG_JSON"

  let seconds_per_slot = "SECONDS_PER_SLOT"

  let mina_log_level = "MINA_LOG_LEVEL"

  let mina_ledger_s3_bucket = "MINA_LEDGER_S3_BUCKET"

  let no_test_ledger_download = "NO_TEST_LEDGER_DOWNLOAD"

  let mina_libp2p_pass = "MINA_LIBP2P_PASS"
end

(** Network and protocol defaults *)
module Network = struct
  let default_seconds_per_slot = "180"

  let default_log_level = "info"

  let default_s3_bucket =
    "https://s3-us-west-2.amazonaws.com/snark-keys-ro.o1test.net"

  let precomputed_block_prefix_template = "gs://mina_network_block_data/%s"
end

(** Timeouts and retry parameters *)
module Timeouts = struct
  let daemon_ready_poll_interval_sec = 60.0

  let daemon_ready_poll_interval =
    Core.Time.Span.of_sec daemon_ready_poll_interval_sec
end

(** File permissions *)
module Permissions = struct
  let directory_default = 0o755

  let keys_directory = 0o700
end

(** JSON field paths for extracting values from configurations *)
module JsonPaths = struct
  (** Paths in fork config *)
  module ForkConfig = struct
    let state_hash = "proof.fork.state_hash"

    let blockchain_length = "proof.fork.blockchain_length"
  end

  (** Paths in precomputed block *)
  module PrecomputedBlock = struct
    let staking_hash =
      "data.protocol_state.body.consensus_state.staking_epoch_data.ledger.hash"

    let next_hash =
      "data.protocol_state.body.consensus_state.next_epoch_data.ledger.hash"

    let ledger_hash =
      "data.protocol_state.body.blockchain_state.staged_ledger_hash.non_snark.ledger_hash"
  end

  (** Paths in legacy hashes JSON *)
  module LegacyHashes = struct
    let staking_hash = "epoch_data.staking.hash"

    let next_hash = "epoch_data.next.hash"

    let ledger_hash = "ledger.hash"
  end

  (** Paths in daemon config *)
  module DaemonConfig = struct
    let genesis_timestamp = "genesis.genesis_state_timestamp"

    let staking_hash = "epoch_data.staking.hash"

    let next_hash = "epoch_data.next.hash"

    let ledger_hash = "ledger.hash"
  end
end

(** File naming patterns *)
module FileNames = struct
  let precomputed_fork_block = "precomputed_fork_block.json"

  let config_orig = "config_orig.json"

  let config = "config.json"

  let config_substituted = "config-substituted.json"

  let legacy_hashes = "legacy_hashes.json"

  let hashes = "hashes.json"

  let override_genesis_timestamp = "override-genesis-timestamp.json"

  let p2p_key = "p2p"

  (** Generate prefixed filename *)
  let prefixed prefix suffix = sprintf "%s-%s.json" prefix suffix

  (** Generate scan filename *)
  let scan_file prefix = sprintf "%s.scan" prefix
end

(** Subdirectory names within workdir *)
module Subdirs = struct
  let ledgers = "ledgers"

  let ledgers_backup = "ledgers-backup"

  let ledgers_downloaded = "ledgers-downloaded"

  let legacy_ledgers = "legacy_ledgers"

  let keys = "keys"
end

(** User-facing messages *)
module Messages = struct
  let generating_genesis_ledgers =
    "generating genesis ledgers ... (this may take a while)\n"

  let exporting_ledgers =
    "exporting ledgers from running node ... (this may take a while)\n"

  let performing_final_comparisons = "Performing final comparisons...\n"

  let validation_successful = "Validation successful\n"

  let validation_failed = "Error: failed validation\n"

  let daemon_died = "daemon died before exporting ledgers\n"
end
