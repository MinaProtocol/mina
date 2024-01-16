open Core
open Async
module Ledger = Mina_ledger.Ledger

type t = Ledger.t

module Hash_json = struct
  type epoch_data = { staking_hash : string; next_hash : string option }
  [@@deriving to_yojson]

  type t = { genesis_hash : string; epoch_data : epoch_data option }
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
  Option.value_map hash_output_file ~default:Deferred.unit ~f:(fun path ->
      let ledger_hash ledger =
        Mina_base.State_hash.to_base58_check @@ Mina_ledger.Ledger.merkle_root
        @@ Lazy.force ledger
      in
      let genesis_hash =
        ledger_hash @@ Genesis_ledger.Packed.t precomputed_values.genesis_ledger
      in
      let epoch_data =
        Option.map precomputed_values.genesis_epoch_data ~f:(fun data ->
            { Hash_json.staking_hash = ledger_hash data.staking.ledger
            ; next_hash =
                Option.map data.next ~f:(fun data -> ledger_hash data.ledger)
            } )
      in
      Async.Writer.save path
        ~contents:
          (Yojson.Safe.to_string
             (Hash_json.to_yojson { genesis_hash; epoch_data }) ) )

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
