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

let load_ledger
    ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    (accounts : Runtime_config.Accounts.t) =
  let accounts =
    List.map accounts ~f:(fun account ->
        (None, Runtime_config.Accounts.Single.to_account account) )
  in
  let packed =
    Genesis_ledger_helper.Ledger.packed_genesis_ledger_of_accounts
      ~depth:constraint_constants.ledger_depth
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
    generate_ledger_tarball ~ledger_name_prefix:"epoch_ledger" ~genesis_dir
      next_ledger
  in
  { Hash_json.ledger = ledger_hashes; epoch_data = { staking; next } }

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

let main ~config_file ~genesis_dir ~hash_output_file () =
  let%bind config =
    Runtime_config.Config_loader.load_config_exn ~config_file ()
  in
  let accounts, staking_accounts_opt, next_accounts_opt =
    let ledger = config.ledger in
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
  in
  let constraint_constants = config.constraint_config.constraint_constants in
  let ledger = load_ledger ~constraint_constants accounts in
  let staking_ledger : Ledger.t =
    Option.value_map ~default:ledger
      ~f:(load_ledger ~constraint_constants)
      staking_accounts_opt
  in
  let next_ledger =
    Option.value_map ~default:staking_ledger
      ~f:(load_ledger ~constraint_constants)
      next_accounts_opt
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
         let%map config_file = Cli_lib.Flag.conf_file
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
