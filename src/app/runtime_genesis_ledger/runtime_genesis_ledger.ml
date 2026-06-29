open Core
open Async
module Ledger = Mina_ledger.Ledger

module Hashes = struct
  type t = { s3_data_hash : string; hash : string } [@@deriving to_yojson]
end

module Hash_json = struct
  type epoch_data = { staking : Hashes.t; next : Hashes.t }
  [@@deriving to_yojson]

  type t = { ledger : Hashes.t; epoch_data : epoch_data } [@@deriving to_yojson]
end

module Output_config = struct
  type epoch_ledger = { seed : string; hash : string; s3_data_hash : string }
  [@@deriving to_yojson]

  type epoch_data = { staking : epoch_ledger; next : epoch_ledger }
  [@@deriving to_yojson]

  type ledger = { add_genesis_winner : bool; hash : string; s3_data_hash : string }
  [@@deriving to_yojson]

  type proof_fork =
    { state_hash : string
    ; blockchain_length : int
    ; global_slot_since_genesis : int
    }
  [@@deriving to_yojson]

  type proof = { fork : proof_fork } [@@deriving to_yojson]

  type genesis = { genesis_state_timestamp : string } [@@deriving to_yojson]

  type t =
    { genesis : genesis
    ; proof : proof
    ; ledger : ledger
    ; epoch_data : epoch_data
    }
  [@@deriving to_yojson]
end

let logger = Logger.create ()

let apply_delegate_overrides ~unstake_pk ~self_delegate_missing
    (accounts : Runtime_config.Accounts.t) : Runtime_config.Accounts.t =
  let open Runtime_config.Accounts.Single in
  List.map accounts ~f:(fun a ->
      match unstake_pk with
      | Some upd_pk when String.equal a.pk upd_pk ->
          { a with delegate = None }
      | _ ->
          if self_delegate_missing && Option.is_none a.delegate then
            { a with delegate = Some a.pk }
          else a )

let load_ledger ~ignore_missing_fields ~pad_app_state ~hardfork_slot
    ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    (accounts : Runtime_config.Accounts.t) =
  let transform_account account =
    let account_padded =
      Runtime_config.Accounts.Single.to_account ~ignore_missing_fields
        ~pad_app_state account
    in
    match hardfork_slot with
    | None ->
        account_padded
    | Some hardfork_slot ->
        Mina_base.Account.slot_reduction_update ~hardfork_slot account_padded
  in

  let accounts =
    List.map accounts ~f:(fun account -> (None, transform_account account))
  in
  let packed =
    Genesis_ledger_helper.Ledger.packed_genesis_ledger_of_accounts ~logger
      ~depth:constraint_constants.ledger_depth ~genesis_backing_type:Stable_db
      (lazy accounts)
  in
  Lazy.force (Genesis_ledger.Packed.t packed)

let generate_ledger_tarball ~genesis_dir ~ledger_name_prefix ledger =
  let%bind tar_path =
    Deferred.Or_error.ok_exn
    @@ Genesis_ledger_helper.Ledger.generate_ledger_tar ~genesis_dir ~logger
         ~ledger_name_prefix ledger
  in
  [%log info] "Generated ledger tar at %s" tar_path ;
  let hash =
    Mina_base.Ledger_hash.to_base58_check
    @@ Mina_ledger.Ledger.merkle_root ledger
  in
  let%map s3_data_hash = Genesis_ledger_helper.sha3_hash tar_path in
  { Hashes.s3_data_hash; hash }

let generate_hash_json ~genesis_dir ledger staking_ledger next_ledger =
  let%bind ledger_hashes =
    generate_ledger_tarball ~ledger_name_prefix:"genesis_ledger" ~genesis_dir
      ledger
  in
  let%bind staking =
    generate_ledger_tarball ~ledger_name_prefix:"epoch_ledger" ~genesis_dir
      staking_ledger
  in
  let%map next =
    (* If next ledger has the same merkle root as staking ledger, reuse the
       same tar file to avoid generating it twice with different timestamps/hashes *)
    let staking_hash = Mina_ledger.Ledger.merkle_root staking_ledger in
    let next_hash = Mina_ledger.Ledger.merkle_root next_ledger in
    if Mina_base.Ledger_hash.equal staking_hash next_hash then (
      [%log info]
        "Next epoch ledger has the same hash as staking ledger, reusing \
         staking ledger tar" ;
      Deferred.return staking )
    else
      generate_ledger_tarball ~ledger_name_prefix:"epoch_ledger" ~genesis_dir
        next_ledger
  in
  { Hash_json.ledger = ledger_hashes; epoch_data = { staking; next } }

let is_dirty_proof = function
  | Runtime_config.Proof_keys.
      { level = None
      ; sub_windows_per_window = None
      ; ledger_depth = None
      ; work_delay = None
      ; block_window_duration_ms = None
      ; transaction_capacity = None
      ; coinbase_amount = None
      ; supercharged_coinbase_factor = None
      ; account_creation_fee = None
      ; _
      } ->
      false
  | _ ->
      true

let sanitize_proof (pf : Runtime_config.Proof_keys.t) =
  { pf with
    level = None
  ; sub_windows_per_window = None
  ; ledger_depth = None
  ; work_delay = None
  ; block_window_duration_ms = None
  ; transaction_capacity = None
  ; coinbase_amount = None
  ; supercharged_coinbase_factor = None
  ; account_creation_fee = None
  }

let extract_accounts_exn = function
  | { Runtime_config.Ledger.base = Accounts accounts
    ; num_accounts = None
    ; balances = []
    ; hash = _
    ; name = None
    ; add_genesis_winner = Some false
    ; s3_data_hash = _
    } ->
      accounts
  | _ ->
      failwith "Wrong ledger supplied"

let sanitize_runtime_config (config : Runtime_config.t) : Runtime_config.t =
  if Option.is_some config.daemon then
    [%log warn] "Ignoring field .daemon from runtime config" ;
  if Option.is_some config.genesis then
    [%log warn] "Ignoring field .genesis from runtime config" ;
  if Option.value_map ~default:false ~f:is_dirty_proof config.proof then
    [%log warn]
      "Ignoring field .proof | {level, sub_windows_per_window, ledger_depth, \
       work_delay, block_window_duration_ms, transaction_capacity, \
       coinbase_amount, supercharged_coinbase_factor, account_creation_fee} \
       from runtime config" ;
  { config with
    daemon = None
  ; genesis = None
  ; proof = Option.map ~f:sanitize_proof config.proof
  }

let load_config_exn config_file =
  let%map config_json =
    Deferred.Or_error.ok_exn
    @@ Genesis_ledger_helper.load_config_json config_file
  in
  let config =
    Runtime_config.of_yojson config_json
    |> Result.map_error ~f:(fun err ->
           Failure ("Could not parse configuration: " ^ err) )
    |> Result.ok_exn
  in
  let config = sanitize_runtime_config config in
  let ledger = Option.value_exn ~message:"No ledger provided" config.ledger in
  let staking_ledger =
    let%map.Option { staking; _ } = config.epoch_data in
    staking.ledger
  in
  let next_ledger =
    let%bind.Option { next; _ } = config.epoch_data in
    let%map.Option { ledger; _ } = next in
    ledger
  in
  ( extract_accounts_exn ledger
  , Option.map ~f:extract_accounts_exn staking_ledger
  , Option.map ~f:extract_accounts_exn next_ledger
  , config )

let write_output_config
    ~(config : Runtime_config.t)
    ~(genesis_state_timestamp : string)
    ~(hash_json : Hash_json.t)
    ~(output_config_path : string) =
  let proof =
    Option.value_exn ~message:"No proof provided in config" config.proof
  in
  let fork =
    Option.value_exn ~message:"No fork proof in config" proof.fork
  in
  let proof_fork : Output_config.proof_fork =
    { state_hash = fork.state_hash
    ; blockchain_length = fork.blockchain_length
    ; global_slot_since_genesis = fork.global_slot_since_genesis
    }
  in
  let epoch_data_cfg =
    Option.value_exn ~message:"No epoch data in config" config.epoch_data
  in
  let staking_seed = epoch_data_cfg.staking.seed in
  let next_seed =
    Option.map epoch_data_cfg.next ~f:(fun n -> n.seed)
  in
  let h = hash_json.epoch_data in
  let epoch_data : Output_config.epoch_data =
    { staking =
        { seed = staking_seed
        ; hash = h.staking.hash
        ; s3_data_hash = h.staking.s3_data_hash
        }
    ; next =
        { seed = Option.value ~default:staking_seed next_seed
        ; hash = h.next.hash
        ; s3_data_hash = h.next.s3_data_hash
        }
    }
  in
  let output : Output_config.t =
    { genesis = { genesis_state_timestamp }
    ; proof = { fork = proof_fork }
    ; ledger =
        { add_genesis_winner = false
        ; hash = hash_json.ledger.hash
        ; s3_data_hash = hash_json.ledger.s3_data_hash
        }
    ; epoch_data
    }
  in
  [%log info] "Writing output config to %s" output_config_path ;
  Async.Writer.save output_config_path
    ~contents:(Yojson.Safe.to_string (Output_config.to_yojson output))

let main ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    ~config_file ~genesis_dir ~hash_output_file ~ignore_missing_fields
    ~pad_app_state ~prefork_genesis_config ~unstake_pk ~self_delegate_missing
    ~output_config_path ~genesis_state_timestamp () =
  let hardfork_slot =
    match prefork_genesis_config with
    | None ->
        None
    | Some prefork_genesis_config -> (
        let runtime_config =
          Yojson.Safe.from_file prefork_genesis_config
          |> Runtime_config.of_yojson |> Result.ok_or_failwith
        in
        let current_genesis_global_slot =
          let open Option.Let_syntax in
          let%bind proof = runtime_config.proof in
          let%map { global_slot_since_genesis; _ } = proof.fork in
          Mina_numbers.Global_slot_since_genesis.of_int
            global_slot_since_genesis
        in
        match
          Runtime_config.scheduled_hard_fork_genesis_slot runtime_config
        with
        | None ->
            [%log info]
              "prefork genesis config does not contain slot_chain_end and \
               hard_fork_genesis_slot_delta, skipping vesting parameter update" ;
            None
        | Some hardfork_slot_since_hf ->
            let slot =
              Mina_numbers.Global_slot_since_hard_fork
              .to_global_slot_since_genesis ~current_genesis_global_slot
                hardfork_slot_since_hf
            in
            [%log info]
              "Computed hardfork slot since genesis from prefork config: $slot"
              ~metadata:
                [ ( "slot"
                  , `String
                      (Mina_numbers.Global_slot_since_genesis.to_string slot) )
                ] ;
            Some slot )
  in
  let%bind accounts, staking_accounts_opt, next_accounts_opt, config =
    load_config_exn config_file
  in
  let accounts =
    apply_delegate_overrides ~unstake_pk ~self_delegate_missing accounts
  in
  let staking_accounts_opt =
    Option.map staking_accounts_opt
      ~f:(apply_delegate_overrides ~unstake_pk ~self_delegate_missing)
  in
  let next_accounts_opt =
    Option.map next_accounts_opt
      ~f:(apply_delegate_overrides ~unstake_pk ~self_delegate_missing)
  in
  let ledger =
    load_ledger ~ignore_missing_fields ~pad_app_state ~constraint_constants
      ~hardfork_slot accounts
  in
  let staking_ledger : Ledger.t =
    Option.value_map ~default:ledger
      ~f:
        (load_ledger ~ignore_missing_fields ~pad_app_state ~constraint_constants
           ~hardfork_slot )
      staking_accounts_opt
  in
  let next_ledger =
    Option.value_map ~default:staking_ledger
      ~f:
        (load_ledger ~ignore_missing_fields ~pad_app_state ~constraint_constants
           ~hardfork_slot )
      next_accounts_opt
  in
  let%bind hash_json =
    generate_hash_json ~genesis_dir ledger staking_ledger next_ledger
  in
  let%bind () =
    Async.Writer.save hash_output_file
      ~contents:(Yojson.Safe.to_string (Hash_json.to_yojson hash_json))
  in
  match output_config_path with
  | None ->
      Deferred.unit
  | Some output_config_path ->
      let genesis_state_timestamp =
        Option.value_exn ~message:"--genesis-state-timestamp required when using --output-config"
          genesis_state_timestamp
      in
      write_output_config ~config ~genesis_state_timestamp ~hash_json
        ~output_config_path

let () =
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  Command.run
    (Command.async
       ~summary:
         "Generate the genesis ledger and genesis proof for a given \
          configuration file."
       Command.(
         let open Let_syntax in
         let open Command.Param in
         let%map config_file =
           flag "--config-file" ~doc:"PATH path to the JSON configuration file"
             (required string)
         and genesis_dir =
           flag "--genesis-dir"
             ~doc:
               (sprintf
                  "Dir where the genesis ledger and genesis proof is to be \
                   saved (default: %s)"
                  Cache_dir.autogen_path )
             (required string)
         and hash_output_file =
           flag "--hash-output-file" (required string)
             ~doc:
               "PATH path to the file where the hashes of the ledgers are to \
                be saved"
         and ignore_missing_fields =
           flag "--ignore-missing" no_arg
             ~doc:
               "BOOL whether to ignore missing fields in account definition \
                (and replace with default values)"
         and pad_app_state =
           flag "--pad-app-state" no_arg
             ~doc:
               "BOOL whether to pad app_state to max allowed size (default: \
                false)"
         and prefork_genesis_config =
           flag "--prefork-genesis-config" (optional string)
             ~doc:
               "STRING path to prefork genesis config. The hardfork slot for \
                vesting parameter updates is computed from \
                daemon.slot_chain_end + daemon.hard_fork_genesis_slot_delta in \
                this config. If those fields are absent, no vesting parameter \
                update is performed."
         and unstake_pk =
           flag "--unstake-pk" (optional string)
             ~doc:
               "STRING public key of an account to unstake (set delegate to \
                null)."
         and self_delegate_missing =
           flag "--self-delegate-missing" no_arg
             ~doc:
               "BOOL whether to set delegate to self for accounts with no \
                delegate (excluding the unstake-pk account)."
         and output_config_path =
           flag "--output-config" (optional string)
             ~doc:
               "PATH path to write the merged daemon.json for the post-fork \
                network. Requires --genesis-state-timestamp."
         and genesis_state_timestamp =
           flag "--genesis-state-timestamp" (optional string)
             ~doc:
               "STRING RFC3339 timestamp for the fork genesis state. Required \
                when --output-config is set."
         in
         main ~constraint_constants ~config_file ~genesis_dir ~hash_output_file
           ~ignore_missing_fields ~pad_app_state ~prefork_genesis_config
           ~unstake_pk ~self_delegate_missing ~output_config_path
           ~genesis_state_timestamp) )
