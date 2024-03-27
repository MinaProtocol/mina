open Executor
open Core

module Output = struct
  type t =
    { target_epoch_ledgers_state_hash : string
    ; target_fork_state_hash : string
    ; target_genesis_ledger : Runtime_config.Ledger.t option
    ; target_epoch_data : Runtime_config.Epoch_data.t option
    }
  [@@deriving yojson]

  let of_json_file_exn file =
    Yojson.Safe.from_file file |> of_yojson |> Result.ok_or_failwith
end

module InputConfig = struct
  type t =
    { target_epoch_ledgers_state_hash : string option [@default None]
    ; start_slot_since_genesis : int64 [@default 0L]
    ; genesis_ledger : Runtime_config.Ledger.t
    ; first_pass_ledger_hashes : Mina_base.Ledger_hash.t list [@default []]
    ; last_snarked_ledger_hash : Mina_base.Ledger_hash.t option [@default None]
    }
  [@@deriving yojson]

  let of_runtime_config_file_exn config target_epoch_ledgers_state_hash =
    let runtime_config =
      Yojson.Safe.from_file config
      |> Runtime_config.of_yojson |> Result.ok_or_failwith
    in
    { target_epoch_ledgers_state_hash
    ; start_slot_since_genesis = 0L
    ; genesis_ledger = Option.value_exn runtime_config.ledger
    ; first_pass_ledger_hashes = []
    ; last_snarked_ledger_hash = None
    }

  let to_yojson_file t output = Yojson.Safe.to_file output (to_yojson t)

  let of_ledger_file_exn ledger_file ~target_epoch_ledgers_state_hash =
    let genesis_ledger =
      Yojson.Safe.from_file ledger_file
      |> Runtime_config.Ledger.of_yojson |> Result.ok_or_failwith
    in
    { target_epoch_ledgers_state_hash
    ; start_slot_since_genesis = 0L
    ; genesis_ledger
    ; first_pass_ledger_hashes = []
    ; last_snarked_ledger_hash = None
    }

  let of_checkpoint_file file target_epoch_ledgers_state_hash =
    let t = Yojson.Safe.from_file file |> of_yojson |> Result.ok_or_failwith in
    { target_epoch_ledgers_state_hash
    ; start_slot_since_genesis = t.start_slot_since_genesis
    ; genesis_ledger = t.genesis_ledger
    ; first_pass_ledger_hashes = t.first_pass_ledger_hashes
    ; last_snarked_ledger_hash = t.last_snarked_ledger_hash
    }
end

include Executor

let of_context context =
  Executor.of_context ~context ~dune_name:"src/app/replayer/replayer.exe"
    ~official_name:"mina-replayer"

let run t ?(migration_mode = false) ~archive_uri ~input_config
    ~interval_checkpoint ?checkpoint_output_folder ?checkpoint_file_prefix
    ~output_ledger =
  let migration_mode_args =
    match migration_mode with true -> [ "--migration-mode" ] | false -> []
  in
  let checkpoint_output_folder =
    match checkpoint_output_folder with
    | Some checkpoint_output_folder ->
        [ "--checkpoint-output-folder"; checkpoint_output_folder ]
    | None ->
        []
  in
  let checkpoint_file_prefix =
    match checkpoint_file_prefix with
    | Some checkpoint_file_prefix ->
        [ "--checkpoint-file-prefix"; checkpoint_file_prefix ]
    | None ->
        []
  in
  let args =
    [ "--archive-uri"
    ; archive_uri
    ; "--input-file"
    ; input_config
    ; "--checkpoint-interval"
    ; string_of_int interval_checkpoint
    ; "--output-file"
    ; output_ledger
    ]
    @ checkpoint_output_folder @ checkpoint_file_prefix @ migration_mode_args
  in

  run t ~args
