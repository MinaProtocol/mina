open Core
open Async
open Mina_base
open Signature_lib

module Evaluate = struct
  module Param = struct
    type t =
      { constraint_constants:
          Genesis_constants.Constraint_constants.Stable.Latest.t
      ; starting_slot: int
      ; slots_per_epoch: int }
    [@@deriving bin_io_unversioned]
  end

  module Input = struct
    type t =
      { total_stake: Currency.Amount.Stable.Latest.t
      ; my_stake: Currency.Balance.Stable.Latest.t
      ; seed: Epoch_seed.Stable.Latest.t
      ; delegator: Account.Index.Stable.Latest.t
      ; private_key: Private_key.Stable.Latest.t
      ; basename: string }
    [@@deriving bin_io_unversioned]
  end

  let f {Param.constraint_constants; starting_slot; slots_per_epoch}
      ( {Input.total_stake; my_stake; seed; delegator; private_key; basename= _}
      as input ) =
    let slots =
      List.range ~start:`inclusive ~stop:`exclusive starting_slot
        slots_per_epoch
      |> List.map ~f:Coda_numbers.Global_slot.of_int
    in
    ( input
    , List.filter slots ~f:(fun global_slot ->
          Consensus.Proof_of_stake.Exported.check_vrf ~total_stake ~my_stake
            ~global_slot ~seed ~delegator ~private_key ~constraint_constants )
    )

  module Map_fn = Rpc_parallel.Map_reduce.Make_map_function_with_init (struct
    type state_type = Param.t

    let init = Deferred.return

    module Param = Param
    module Input = Input

    module Output = struct
      type t = Input.t * Coda_numbers.Global_slot.Stable.Latest.t list
      [@@deriving bin_io_unversioned]
    end

    let map p i = f p i |> Deferred.return
  end)
end

module Kp = struct
  type t = Public_key.Compressed.t * Private_key.t * string [@@deriving yojson]
end

let read_keys ~password dir =
  let keys_cache = "decrypted-keys" in
  let%bind keypairs =
    let res = Public_key.Compressed.Table.create () in
    match%bind Sys.file_exists keys_cache with
    | `No | `Unknown ->
        Deferred.return res
    | `Yes ->
        let%map lines = Reader.file_lines keys_cache in
        List.iter lines ~f:(fun line ->
            let pub, priv, s =
              match Kp.of_yojson (Yojson.Safe.from_string line) with
              | Ok x ->
                  x
              | Error e ->
                  failwithf "error on (%s): %s" line e ()
            in
            Hashtbl.set res ~key:pub ~data:(s, priv) ) ;
        res
  in
  let%bind out = Writer.open_file ~append:true keys_cache in
  let%bind files = Sys.ls_dir dir in
  let n = List.length files in
  let finished = ref 0 in
  let%map () =
    Deferred.List.iter files ~how:(`Max_concurrent_jobs 10) ~f:(fun path ->
        match String.chop_suffix path ~suffix:".pub" with
        | None ->
            Deferred.unit
        | Some privkey_path -> (
            let path = dir ^/ privkey_path in
            let%bind pubkey =
              Reader.file_contents (path ^ ".pub")
              >>| String.strip >>| Public_key.Compressed.of_base58_check_exn
            in
            if Hashtbl.mem keypairs pubkey then Deferred.unit
            else
              let%map keypair =
                Secrets.Keypair.read ~privkey_path:path ~password
              in
              match keypair with
              | Error e ->
                  incr finished ;
                  Core.eprintf "error: %s\n%!"
                    (Secrets.Privkey_error.to_string e)
              | Ok kp ->
                  let public_key = Public_key.compress kp.Keypair.public_key in
                  Writer.write_line out
                    (Yojson.Safe.to_string
                       (Kp.to_yojson (public_key, kp.private_key, privkey_path))) ;
                  incr finished ;
                  Core.printf "yay %d/%d\n%!" !finished n ;
                  Hashtbl.set keypairs ~key:public_key
                    ~data:(privkey_path, kp.private_key) ) )
  in
  keypairs

module Output_record = struct
  type t = {basename: string; slots_won: Coda_numbers.Global_slot.t list}
  [@@deriving yojson]
end

let main ~starting_slot ~num_workers ~out_dir ~keys_dir ~password ~config_path
    =
  let logger = Logger.create () in
  let%bind config =
    let%map config_jsons =
      let config_files = [(config_path, `Must_exist)] in
      let config_files_paths =
        List.map config_files ~f:(fun (config_file, _) -> `String config_file)
      in
      [%log info] "Reading configuration files $config_files"
        ~metadata:[("config_files", `List config_files_paths)] ;
      Deferred.List.filter_map config_files
        ~f:(fun (config_file, handle_missing) ->
          match%bind Genesis_ledger_helper.load_config_json config_file with
          | Ok config_json ->
              let%map config_json =
                Genesis_ledger_helper.upgrade_old_config ~logger config_file
                  config_json
              in
              Some (config_file, config_json)
          | Error err -> (
            match handle_missing with
            | `Must_exist ->
                Mina_user_error.raisef ~where:"reading configuration file"
                  "The configuration file %s could not be read:\n%s"
                  config_file (Error.to_string_hum err)
            | `May_be_missing ->
                [%log warn]
                  "Could not read configuration from $config_file: $error"
                  ~metadata:
                    [ ("config_file", `String config_file)
                    ; ("error", Error_json.error_to_yojson err) ] ;
                return None ) )
    in
    List.fold ~init:Runtime_config.default config_jsons
      ~f:(fun config (config_file, config_json) ->
        match Runtime_config.of_yojson config_json with
        | Ok loaded_config ->
            Runtime_config.combine config loaded_config
        | Error err ->
            [%log fatal]
              "Could not parse configuration from $config_file: $error"
              ~metadata:
                [ ("config_file", `String config_file)
                ; ("config_json", config_json)
                ; ("error", `String err) ] ;
            failwithf "Could not parse configuration file: %s" err () )
  in
  let%bind precomputed_values =
    match%map
      Genesis_ledger_helper.init_from_config_file ?genesis_dir:None
        ~logger:(Logger.null ()) ~may_generate:false ~proof_level:(Some Check)
        config
    with
    | Ok (precomputed_values, _) ->
        precomputed_values
    | Error err ->
        let logger = Logger.create () in
        [%log fatal] "Failed initializing with configuration $config: $error"
          ~metadata:
            [ ("config", Runtime_config.to_yojson config)
            ; ("error", Error_json.error_to_yojson err) ] ;
        Error.raise err
  in
  let par_config =
    Rpc_parallel.Map_reduce.Config.create ~local:num_workers
      ~redirect_stderr:`Dev_null ~redirect_stdout:`Dev_null ()
  in
  let%bind (private_keys
             : (string * Private_key.t) Public_key.Compressed.Table.t) =
    read_keys keys_dir ~password
  in
  let ledger =
    Lazy.force (Precomputed_values.genesis_ledger precomputed_values)
  in
  let param =
    { Evaluate.Param.constraint_constants=
        precomputed_values.constraint_constants
    ; slots_per_epoch=
        Unsigned.UInt32.to_int
          precomputed_values.consensus_constants.slots_per_epoch }
  in
  let inputs =
    let r = ref [] in
    let genesis = Precomputed_values.genesis_state precomputed_values in
    let epoch_data =
      Coda_state.Protocol_state.consensus_state genesis
      |> Consensus.Data.Consensus_state.staking_epoch_data
    in
    Ledger.iteri ledger ~f:(fun i a ->
        match Hashtbl.find private_keys a.public_key with
        | None ->
            ()
        | Some (basename, private_key) ->
            let input =
              { Evaluate.Input.total_stake= epoch_data.ledger.total_currency
              ; my_stake= a.balance
              ; seed= epoch_data.seed
              ; delegator= i
              ; basename
              ; private_key }
            in
            r := input :: !r ) ;
    Core.printf "inputs: %d\n%!" (List.length !r) ;
    Pipe.of_list !r
  in
  let%bind output_reader =
    Rpc_parallel.Map_reduce.map par_config inputs
      ~m:(module Evaluate.Map_fn)
      ~param
  in
  let%bind results = Writer.open_file ~append:true (out_dir ^/ "results") in
  Pipe.iter output_reader ~f:(fun (input, slots) ->
      Writer.write_line results
        (Yojson.Safe.to_string
           (Output_record.to_yojson {basename= input.basename; slots_won= slots})) ;
      if List.is_empty slots then Deferred.unit
      else
        let%bind _ =
          ksprintf Sys.command "cp %s %s"
            (keys_dir ^/ input.basename)
            (out_dir ^/ input.basename)
        in
        let%map _ =
          ksprintf Sys.command "cp %s %s"
            (keys_dir ^/ input.basename ^ ".pub")
            (out_dir ^/ input.basename ^ ".pub")
        in
        () )

let () =
  Command.async
    ~summary:
      "find the keys in a genesis ledger that win some slot in the first epoch"
    Command.Let_syntax.(
      let%map_open num_workers =
        flag_optional_with_default_doc ~doc:"Number of worker processes"
          "num-workers" int Int.sexp_of_t ~default:6
      and keys_dir =
        flag "keys-dir" (required string)
          ~doc:"directory of private-key/public-key pairs"
      and config_path =
        flag "config-file" (required string) ~doc:"Genesis config file"
      and password =
        flag "-provide-password"
          ~doc:"will try the default password if not provided" no_arg
      and out_dir = flag "-out-dir" ~doc:"output directory" (required string)
      and starting_slot =
        flag "-starting-slot" ~doc:"slot to start checking at"
          (optional_with_default 0 int)
      in
      fun () ->
        let open Async in
        let%bind password =
          if password then
            Secrets.Password.read_hidden_line "Password: "
              ~error_help_message:"error"
          else Deferred.return (Bytes.of_string "naughty blue worm")
        in
        main ~num_workers ~keys_dir ~out_dir ~starting_slot
          ~password:(Lazy.return (Deferred.return password))
          ~config_path)
  |> Rpc_parallel.start_app
