open Core
open Async
open Coda_base

type exn += Genesis_state_initialization_error

let retrieve_genesis_state dir_opt ~commit_id_short ~logger ~conf_dir
    ~daemon_conf : (Ledger.t lazy_t * Proof.t * Genesis_constants.t) Deferred.t
    =
  let open Cache_dir in
  let genesis_dir_name =
    Cache_dir.genesis_dir_name ~commit_id_short Genesis_constants.compiled
  in
  let tar_filename = genesis_dir_name ^ ".tar.gz" in
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__
    "Looking for the genesis tar file $filename"
    ~metadata:[("filename", `String tar_filename)] ;
  let s3_bucket_prefix =
    "https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net" ^/ tar_filename
  in
  let extract tar_dir =
    let target_dir = conf_dir ^/ genesis_dir_name in
    match%map
      Monitor.try_with_or_error ~extract_exn:true (fun () ->
          (*Delete any old genesis state*)
          let%bind () =
            File_system.remove_dir (conf_dir ^/ "coda_genesis_*")
          in
          (*Look for the tar and extract*)
          let tar_file = tar_dir ^/ genesis_dir_name ^ ".tar.gz" in
          let%map _result =
            Process.run_exn ~prog:"tar"
              ~args:["-C"; conf_dir; "-xzf"; tar_file]
              ()
          in
          () )
    with
    | Ok () ->
        Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
          "Found genesis tar file at $source and extracted it to $path"
          ~metadata:[("source", `String tar_dir); ("path", `String target_dir)]
    | Error e ->
        Logger.debug ~module_:__MODULE__ ~location:__LOC__ logger
          "Error extracting genesis ledger and proof : $error"
          ~metadata:[("error", `String (Error.to_string_hum e))]
  in
  let retrieve tar_dir =
    Logger.debug ~module_:__MODULE__ ~location:__LOC__ logger
      "Retrieving genesis ledger and genesis proof from $path"
      ~metadata:[("path", `String tar_dir)] ;
    let%bind () = extract tar_dir in
    let extract_target = conf_dir ^/ genesis_dir_name in
    let ledger_dir = extract_target ^/ "ledger" in
    let proof_file = extract_target ^/ "genesis_proof" in
    let constants_file = extract_target ^/ "genesis_constants.json" in
    if
      Core.Sys.file_exists ledger_dir = `Yes
      && Core.Sys.file_exists proof_file = `Yes
      && Core.Sys.file_exists constants_file = `Yes
    then (
      let genesis_ledger =
        let ledger = lazy (Ledger.create ~directory_name:ledger_dir ()) in
        match Or_error.try_with (fun () -> Lazy.force ledger |> ignore) with
        | Ok _ ->
            ledger
        | Error e ->
            Logger.fatal ~module_:__MODULE__ ~location:__LOC__ logger
              "Error loading the genesis ledger from $dir: $error"
              ~metadata:
                [ ("dir", `String ledger_dir)
                ; ("error", `String (Error.to_string_hum e)) ] ;
            raise Genesis_state_initialization_error
      in
      let genesis_constants =
        match
          Result.bind
            ( Result.try_with (fun () -> Yojson.Safe.from_file constants_file)
            |> Result.map_error ~f:Exn.to_string )
            ~f:(fun json -> Genesis_constants.Config_file.of_yojson json)
        with
        | Ok t ->
            Genesis_constants.(of_config_file ~default:compiled t)
        | Error s ->
            Logger.fatal ~module_:__MODULE__ ~location:__LOC__ logger
              "Error loading genesis constants from $file: $error"
              ~metadata:[("dir", `String constants_file); ("error", `String s)] ;
            raise Genesis_state_initialization_error
      in
      let%map base_proof =
        match%map
          Monitor.try_with_or_error ~extract_exn:true (fun () ->
              let%bind r = Reader.open_file proof_file in
              let%map contents =
                Pipe.to_list (Reader.lines r) >>| String.concat
              in
              Sexp.of_string contents |> Proof.Stable.V1.t_of_sexp )
        with
        | Ok base_proof ->
            base_proof
        | Error e ->
            Logger.fatal ~module_:__MODULE__ ~location:__LOC__ logger
              "Error reading the base proof from $file: $error"
              ~metadata:
                [ ("file", `String proof_file)
                ; ("error", `String (Error.to_string_hum e)) ] ;
            raise Genesis_state_initialization_error
      in
      Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
        "Successfully retrieved genesis ledger and genesis proof from $path"
        ~metadata:[("path", `String tar_dir)] ;
      Some (genesis_ledger, base_proof, genesis_constants) )
    else (
      Logger.debug ~module_:__MODULE__ ~location:__LOC__ logger
        "Error retrieving genesis ledger and genesis proof from $path"
        ~metadata:[("path", `String tar_dir)] ;
      Deferred.return None )
  in
  let res_or_fail dir_str = function
    | Some ((ledger, proof, (constants : Genesis_constants.t)) as res) ->
        (*Replace runtime-configurable constants from the dameon, if any*)
        Option.value_map daemon_conf ~default:res ~f:(fun daemon_config_file ->
            let new_constants =
              match
                Result.bind
                  ( Result.try_with (fun () ->
                        Yojson.Safe.from_file daemon_config_file )
                  |> Result.map_error ~f:Exn.to_string )
                  ~f:(fun json ->
                    Genesis_constants.Daemon_config.of_yojson json )
              with
              | Ok t ->
                  Genesis_constants.(of_daemon_config ~default:constants t)
              | Error s ->
                  Logger.fatal ~module_:__MODULE__ ~location:__LOC__ logger
                    "Error loading runtime-configurable constants from $file: \
                     $error"
                    ~metadata:
                      [ ("dir", `String daemon_config_file)
                      ; ("error", `String s) ] ;
                  raise Genesis_state_initialization_error
            in
            (ledger, proof, new_constants) )
    | None ->
        Logger.fatal ~module_:__MODULE__ ~location:__LOC__ logger
          "Could not retrieve genesis ledger and genesis proof from paths \
           $paths"
          ~metadata:[("paths", `String dir_str)] ;
        raise Genesis_state_initialization_error
  in
  match dir_opt with
  | Some dir ->
      let%map res = retrieve dir in
      res_or_fail dir res
  | None -> (
      let directories =
        [ autogen_path
        ; manual_install_path
        ; brew_install_path
        ; Cache_dir.s3_install_path ]
      in
      match%bind
        Deferred.List.fold directories ~init:None ~f:(fun acc dir ->
            if is_some acc then Deferred.return acc else retrieve dir )
      with
      | Some res ->
          Deferred.return res
      | None ->
          (*Check if it's in s3*)
          let local_path = Cache_dir.s3_install_path ^/ tar_filename in
          let%bind () =
            match%map
              Cache_dir.load_from_s3 [s3_bucket_prefix] [local_path] ~logger
            with
            | Ok () ->
                ()
            | Error e ->
                Logger.fatal ~module_:__MODULE__ ~location:__LOC__ logger
                  "Could not curl genesis ledger and genesis proof from $uri: \
                   $error"
                  ~metadata:
                    [ ("uri", `String s3_bucket_prefix)
                    ; ("error", `String (Error.to_string_hum e)) ]
          in
          let%map res = retrieve Cache_dir.s3_install_path in
          res_or_fail
            (String.concat ~sep:"," (s3_bucket_prefix :: directories))
            res )
