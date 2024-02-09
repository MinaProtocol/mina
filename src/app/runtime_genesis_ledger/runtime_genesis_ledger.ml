open Core
open Async
module Ledger = Mina_ledger.Ledger

module Hashes = struct
  type t = { s3_data_hash : string; ledger_hash : string }
  [@@deriving to_yojson]
end

module Hash_json = struct
  type t = { genesis : Hashes.t; staking : Hashes.t; next_staking : Hashes.t }
  [@@deriving to_yojson]
end

let logger = Logger.create ()

let ledger_depth =
  (Lazy.force Precomputed_values.compiled_inputs).constraint_constants
    .ledger_depth

let generate_ledger_tarball ~genesis_dir name
    (ledger_config : Runtime_config.Ledger.t) =
  let accounts =
    match ledger_config.base with
    | Accounts accounts ->
        List.map accounts ~f:(fun account ->
            (None, Runtime_config.Accounts.Single.to_account account) )
    | _ ->
        failwith "genesis ledger config must specify accounts"
  in
  let packed =
    Genesis_ledger_helper.Ledger.packed_genesis_ledger_of_accounts
      ~depth:ledger_depth
      (lazy accounts)
  in
  let ledger = Lazy.force (Genesis_ledger.Packed.t packed) in
  let%bind tar_path =
    Deferred.Or_error.ok_exn
    @@ Genesis_ledger_helper.Ledger.generate_tar ~genesis_dir ~logger
         ~ledger_name_prefix:name ledger
  in
  [%log info] "Generated ledger tar at %s" tar_path ;
  let ledger_hash =
    Mina_base.State_hash.to_base58_check
    @@ Mina_ledger.Ledger.merkle_root ledger
  in
  let%map s3_data_hash = Genesis_ledger_helper.sha3_hash tar_path in
  { Hashes.s3_data_hash; ledger_hash }

let main ~config_file ~genesis_dir ~hash_output_file () =
  let gen = generate_ledger_tarball ~genesis_dir in
  let%bind config =
    let%map config_json =
      Deferred.Or_error.ok_exn
      @@ Genesis_ledger_helper.load_config_json config_file
    in
    match Runtime_config.of_yojson config_json with
    | Ok config ->
        config
    | Error err ->
        failwithf "Could not parse configuration: %s" err ()
  in
  let genesis_ledger_config =
    Option.value_exn ~message:"genesis ledger config is required" config.ledger
  in
  let epoch_data_config =
    Option.value_exn ~message:"epoch data config is required" config.epoch_data
  in
  let staking_ledger_config = epoch_data_config.staking in
  let next_staking_ledger_config =
    Option.value_exn ~message:"next staking ledger config is required"
      epoch_data_config.next
  in
  let%bind genesis = gen "genesis_ledger" genesis_ledger_config in
  let%bind staking = gen "epoch_ledger" staking_ledger_config.ledger in
  let%bind next_staking =
    gen "epoch_ledger" next_staking_ledger_config.ledger
  in
  Async.Writer.save hash_output_file
    ~contents:
      (Yojson.Safe.to_string
         (Hash_json.to_yojson { genesis; staking; next_staking }) )

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
                   saved" )
             (required string)
         and hash_output_file =
           flag "--hash-output-file"
             ~doc:
               "PATH path to the file where the hashes of the ledgers are to \
                be saved"
             (required string)
         in
         main ~config_file ~genesis_dir ~hash_output_file) )
