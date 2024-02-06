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

let main ~config_file ~genesis_dir ~proof_level ~hash_output_file () =
  let%bind config =
    match config_file with
    | Some config_file -> (
        let%map config_json =
          Deferred.Or_error.ok_exn
          @@ Genesis_ledger_helper.load_config_json config_file
        in
        match Runtime_config.of_yojson config_json with
        | Ok config ->
            config
        | Error err ->
            failwithf "Could not parse configuration: %s" err () )
    | None ->
        return Runtime_config.default
  in
  let%bind precomputed_values, _ =
    Deferred.Or_error.ok_exn
    @@ Genesis_ledger_helper.init_from_config_file ?genesis_dir
         ~logger:(Logger.create ()) ~proof_level config
  in
  let append_genesis_dir =
    Option.value_map genesis_dir ~default:ident ~f:(^/)
in
  Option.value_map hash_output_file ~default:Deferred.unit ~f:(fun path ->
      let ledger_hash ledger_name_prefix ledger =
        let hash =
          Lazy.force ledger |> Mina_ledger.Ledger.merkle_root
          |> Mina_base.State_hash.to_base58_check
        in
        let%map s3_data_hash =
          Genesis_ledger_helper.(
            Ledger.hash_filename ~ledger_name_prefix hash |> append_genesis_dir |> sha3_hash)
        in
        { Hashes.s3_data_hash; hash }
      in
      let%bind ledger =
        ledger_hash "genesis_ledger"
        @@ Genesis_ledger.Packed.t precomputed_values.genesis_ledger
      in
      let%bind epoch_data =
        Option.value_map ~default:(return None)
          precomputed_values.genesis_epoch_data ~f:(fun data ->
            let%bind staking =
              ledger_hash "epoch_ledger" data.staking.ledger
            in
            let%map next =
              Option.value_map ~default:(return None) data.next
                ~f:(fun { ledger; _ } ->
                  ledger_hash "epoch_ledger" ledger >>| Option.some )
            in
            Some { Hash_json.staking; next } )
      in
      Async.Writer.save path
        ~contents:
          (Yojson.Safe.to_string
             (Hash_json.to_yojson { ledger; epoch_data }) ) )

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
         and proof_level =
           flag "--proof-level"
             (optional
                (Arg_type.create Genesis_constants.Proof_level.of_string) )
             ~doc:"full|check|none"
         and hash_output_file =
           flag "--hash-output-file" (optional string)
             ~doc:
               "PATH path to the file where the hashes of the ledgers are to \
                be saved"
         in
         main ~config_file ~genesis_dir ~proof_level ~hash_output_file) )
