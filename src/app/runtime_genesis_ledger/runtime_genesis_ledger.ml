open Core
open Async
module Ledger = Mina_ledger.Ledger

type t = Ledger.t

module Hashes = struct
  type t = { s3_data_hash : string; hash : string } [@@deriving to_yojson]
end

module Hash_json = struct
  type epoch_data = { staking : Hashes.t; next : Hashes.t option }
  [@@deriving to_yojson]

  type t = { ledger : Hashes.t; epoch_data : epoch_data option }
  [@@deriving to_yojson]
end

let ledger_hash ~genesis_dir ledger_name_prefix ledger =
  let append_genesis_dir =
    Option.value_map genesis_dir ~default:ident ~f:( ^/ )
  in
  let hash =
    Lazy.force ledger |> Mina_ledger.Ledger.merkle_root
    |> Mina_base.State_hash.to_base58_check
  in
  let%map s3_data_hash =
    Genesis_ledger_helper.(
      Ledger.hash_filename ~ledger_name_prefix hash
      |> append_genesis_dir |> sha3_hash)
  in
  { Hashes.s3_data_hash; hash }

let mk_epoch_data_json ~genesis_dir (data : Consensus.Genesis_epoch_data.tt) =
  let%bind staking =
    ledger_hash ~genesis_dir "epoch_ledger" data.staking.ledger
  in
  let%map next =
    Option.value_map ~default:(return None) data.next ~f:(fun { ledger; _ } ->
        ledger_hash ~genesis_dir "epoch_ledger" ledger >>| Option.some )
  in
  Some { Hash_json.staking; next }

let generate_hash_json ~genesis_dir (precomputed_values : Precomputed_values.t)
    =
  let%bind ledger =
    ledger_hash ~genesis_dir "genesis_ledger"
    @@ Genesis_ledger.Packed.t precomputed_values.genesis_ledger
  in
  let%map epoch_data =
    Option.value_map ~default:(return None)
      precomputed_values.genesis_epoch_data
      ~f:(mk_epoch_data_json ~genesis_dir)
  in
  { Hash_json.ledger; epoch_data }

let load_config_exn config_file =
  let%map config_json =
    Deferred.Or_error.ok_exn
    @@ Genesis_ledger_helper.load_config_json config_file
  in
  Runtime_config.of_yojson config_json
  |> Result.map_error ~f:(fun err ->
         Failure ("Could not parse configuration: " ^ err) )
  |> Result.ok_exn

let main ~config_file ~genesis_dir ~hash_output_file () =
  let%bind config =
    Option.value_map
      ~default:(return Runtime_config.default)
      ~f:load_config_exn config_file
  in
  let%bind precomputed_values, _ =
    Deferred.Or_error.ok_exn
    @@ Genesis_ledger_helper.init_from_config_file ~create_name_symlink:false
         ?genesis_dir ~logger:(Logger.create ()) ~proof_level:None config
  in
  Option.value_map hash_output_file ~default:Deferred.unit ~f:(fun path ->
      let%bind hash_json = generate_hash_json ~genesis_dir precomputed_values in
      Async.Writer.save path
        ~contents:(Yojson.Safe.to_string (Hash_json.to_yojson hash_json)) )

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
             (optional string)
         and genesis_dir =
           flag "--genesis-dir"
             ~doc:
               (sprintf
                  "Dir where the genesis ledger and genesis proof is to be \
                   saved (default: %s)"
                  Cache_dir.autogen_path )
             (optional string)
         and hash_output_file =
           flag "--hash-output-file" (optional string)
             ~doc:
               "PATH path to the file where the hashes of the ledgers are to \
                be saved"
         in
         main ~config_file ~genesis_dir ~hash_output_file) )
