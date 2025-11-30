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

let logger = Logger.create ()

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
      ; fork = _
      } ->
      false
  | _ ->
      true

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
  if
    Option.(
      is_some config.daemon || is_some config.genesis
      || Option.value_map ~default:false ~f:is_dirty_proof config.proof)
  then failwith "Runtime config has unexpected fields" ;
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
  , Option.map ~f:extract_accounts_exn next_ledger )

let main ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    ~config_file ~genesis_dir ~hash_output_file ~ignore_missing_fields
    ~pad_app_state ~hardfork_slot ~prefork_genesis_config () =
  let hardfork_slot =
    match (hardfork_slot, prefork_genesis_config) with
    | None, None ->
        None
    | Some hardfork_slot, Some prefork_genesis_config ->
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
        Option.some
        @@ Mina_numbers.Global_slot_since_hard_fork.to_global_slot_since_genesis
             ~current_genesis_global_slot hardfork_slot
    | Some _, None ->
        failwith
          "hardfork slot is present but no prefork genesis config is provided"
    | None, Some _ ->
        [%log info]
          "prefork genesis config is provided with no hardfork slot provided, \
           ignoring" ;
        None
  in
  let%bind accounts, staking_accounts_opt, next_accounts_opt =
    load_config_exn config_file
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
  Async.Writer.save hash_output_file
    ~contents:(Yojson.Safe.to_string (Hash_json.to_yojson hash_json))

let () =
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  Command.run
    (Command.async
       ~summary:
         "Generate the genesis ledger and genesis proof for a given \
          configuration file, or for the compile-time configuration if none is \
          provided"
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
         (* TODO: at later stages replace with a flag to do all
            ledger transformations necessary for the hardfork *)
         and pad_app_state =
           flag "--pad-app-state" no_arg
             ~doc:
               "BOOL whether to pad app_state to max allowed size (default: \
                false)"
         and hardfork_slot =
           flag "--hardfork-slot"
             (optional Cli_lib.Arg_type.hardfork_slot)
             ~doc:
               "INT the scheduled hardfork slot since last hardfork at which \
                vesting parameter update should happen. If absent, don't \
                update the vesting parameters"
         and prefork_genesis_config =
           flag "--prefork-genesis-config" (optional string)
             ~doc:
               "STRING path to prefork genesis confg, should be present if \
                `--hardfork-slot` is set, the program would read the genesis \
                timestamps in the config to calculate the proper hardfork \
                slot."
         in
         main ~constraint_constants ~config_file ~genesis_dir ~hash_output_file
           ~ignore_missing_fields ~pad_app_state ~hardfork_slot
           ~prefork_genesis_config) )
