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

let ledger_depth =
  (Lazy.force Precomputed_values.compiled_inputs).constraint_constants
    .ledger_depth

let logger = Logger.create ()

let load_ledger (accounts : Runtime_config.Accounts.t) =
  let accounts =
    List.map accounts ~f:(fun account ->
        (None, Runtime_config.Accounts.Single.to_account account) )
  in
  let packed =
    Genesis_ledger_helper.Ledger.packed_genesis_ledger_of_accounts
      ~depth:ledger_depth
      (lazy accounts)
  in
  Lazy.force (Genesis_ledger.Packed.t packed)

let generate_ledger_tarball ~genesis_dir ~ledger_name_prefix ledger =
  let%bind tar_path =
    Deferred.Or_error.ok_exn
    @@ Genesis_ledger_helper.Ledger.generate_tar ~genesis_dir ~logger
         ~ledger_name_prefix ledger
  in
  [%log info] "Generated ledger tar at %s" tar_path ;
  let hash =
    Mina_base.State_hash.to_base58_check
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

let accounts_of_ledger = function
  | { Runtime_config.Ledger.base = Accounts accounts; _ } ->
      Some accounts
  | _ ->
      None

let extract_accounts_exn = function
  | { Runtime_config.Ledger.base = Accounts accounts
    ; num_accounts = None
    ; balances = []
    ; add_genesis_winner = Some false
    ; _
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

let main ~config_file ~genesis_dir ~hash_output_file () =
  let%bind accounts, staking_accounts_opt, next_accounts_opt =
    load_config_exn config_file
  in
  let ledger = load_ledger accounts in
  let staking_ledger =
    Option.value_map ~default:ledger ~f:load_ledger staking_accounts_opt
  in
  let next_ledger =
    Option.value_map ~default:staking_ledger ~f:load_ledger next_accounts_opt
  in
  let%bind hash_json =
    generate_hash_json ~genesis_dir ledger staking_ledger next_ledger
  in
  Async.Writer.save hash_output_file
    ~contents:(Yojson.Safe.to_string (Hash_json.to_yojson hash_json))

let () =
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
         in
         main ~config_file ~genesis_dir ~hash_output_file) )
