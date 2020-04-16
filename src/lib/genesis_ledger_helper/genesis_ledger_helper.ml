(* genesis_ledger_helper.ml *)

(* for consensus nodes, read download ledger, proof, and constants from file, or
     download from S3
   for nonconsensus nodes, download genesis proof and constants (not ledger)
     from S3 (not from file)
*)

[%%import
"/src/config.mlh"]

[%%ifdef
consensus_mechanism]

open Core
open Async

[%%else]

open Core_kernel
open Async_kernel
module Coda_base = Coda_base_nonconsensus
module Cache_dir = Cache_dir_nonconsensus.Cache_dir

[%%endif]

open Coda_base

type exn += Genesis_state_initialization_error

let s3_root = "https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net/"

let proof_filename_root = "genesis_proof"

[%%ifdef
consensus_mechanism]

let constants_filename_root = "genesis_constants.json"

let retrieve_genesis_state dir_opt ~logger ~conf_dir ~daemon_conf :
    (Ledger.t lazy_t * Proof.t * Genesis_constants.t) Deferred.t =
  let open Cache_dir in
  let genesis_dir_name =
    Cache_dir.genesis_dir_name Genesis_constants.compiled
  in
  let tar_filename = genesis_dir_name ^ ".tar.gz" in
  let proof_filename = proof_filename_root ^ "." ^ genesis_dir_name in
  let constants_filename = constants_filename_root ^ "." ^ genesis_dir_name in
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__
    "Looking for the genesis ledger $ledger, proof $proof, and constants \
     $constants files"
    ~metadata:
      [ ("ledger", `String tar_filename)
      ; ("proof", `String proof_filename)
      ; ("constants", `String constants_filename) ] ;
  let s3_bucket_prefix = s3_root ^ tar_filename in
  let copy_file ~filename ~tar_dir ~extract_target =
    let source_file = tar_dir ^/ filename ^ "." ^ genesis_dir_name in
    let target_file = extract_target ^/ filename in
    match%map
      Monitor.try_with_or_error (fun () ->
          let%map _result =
            Process.run_exn ~prog:"cp" ~args:[source_file; target_file] ()
          in
          () )
    with
    | Ok () ->
        Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
          "Found $source_file and copied it to $target_file"
          ~metadata:
            [ ("source_file", `String source_file)
            ; ("target_file", `String target_file) ]
    | Error e ->
        Logger.debug ~module_:__MODULE__ ~location:__LOC__ logger
          "Error copying genesis $filename: $error"
          ~metadata:
            [ ("filename", `String filename)
            ; ("error", `String (Error.to_string_hum e)) ]
  in
  let extract_tar_file ~tar_dir ~extract_target =
    match%map
      Monitor.try_with_or_error ~extract_exn:true (fun () ->
          (* Delete any old genesis state *)
          let%bind () =
            File_system.remove_dir (conf_dir ^/ "coda_genesis_*")
          in
          (* Look for the tar and extract *)
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
          "Found genesis ledger tar file at $source and extracted it to $path"
          ~metadata:
            [("source", `String tar_dir); ("path", `String extract_target)]
    | Error e ->
        Logger.debug ~module_:__MODULE__ ~location:__LOC__ logger
          "Error extracting genesis ledger: $error"
          ~metadata:[("error", `String (Error.to_string_hum e))]
  in
  let retrieve_genesis_data tar_dir =
    Logger.debug ~module_:__MODULE__ ~location:__LOC__ logger
      "Retrieving genesis ledger, proof, and constants from $path"
      ~metadata:[("path", `String tar_dir)] ;
    let ledger_subdir = "ledger" in
    let extract_target = conf_dir ^/ genesis_dir_name in
    let%bind () = extract_tar_file ~tar_dir ~extract_target in
    let%bind () =
      copy_file ~filename:proof_filename_root ~tar_dir ~extract_target
    in
    let%bind () =
      copy_file ~filename:constants_filename_root ~tar_dir ~extract_target
    in
    let ledger_dir = extract_target ^/ ledger_subdir in
    let proof_file = extract_target ^/ proof_filename_root in
    let constants_file = extract_target ^/ constants_filename_root in
    if
      Core.Sys.(
        file_exists ledger_dir = `Yes
        && file_exists proof_file = `Yes
        && file_exists constants_file = `Yes)
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
      Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
        "Successfully retrieved genesis ledger from $path"
        ~metadata:[("path", `String tar_dir)] ;
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
              Sexp.of_string contents |> Proof.t_of_sexp )
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
        "Successfully retrieved genesis ledger, proof, and constants from $path"
        ~metadata:[("path", `String tar_dir)] ;
      Some (genesis_ledger, base_proof, genesis_constants) )
    else (
      Logger.debug ~module_:__MODULE__ ~location:__LOC__ logger
        "Did not find genesis ledger, proof, and constants at $path"
        ~metadata:[("path", `String tar_dir)] ;
      Deferred.return None )
  in
  let res_or_fail dir_str = function
    | Some ((ledger, proof, constants) as res) ->
        (* Replace runtime-configurable constants from the daemon, if any *)
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
          "Could not retrieve genesis ledger, genesis proof, and genesis \
           constants from paths $paths"
          ~metadata:[("paths", `String dir_str)] ;
        raise Genesis_state_initialization_error
  in
  match dir_opt with
  | Some dir ->
      let%map genesis_state_opt = retrieve_genesis_data dir in
      res_or_fail dir genesis_state_opt
  | None -> (
      let directories =
        [ autogen_path
        ; manual_install_path
        ; brew_install_path
        ; Cache_dir.s3_install_path ]
      in
      match%bind
        Deferred.List.fold directories ~init:None ~f:(fun acc dir ->
            if is_some acc then Deferred.return acc
            else retrieve_genesis_data dir )
      with
      | Some res ->
          Deferred.return res
      | None ->
          (* Check if genesis data is in s3 *)
          let tgz_local_path = Cache_dir.s3_install_path ^/ tar_filename in
          let proof_local_path = Cache_dir.s3_install_path ^/ proof_filename in
          let constants_local_path =
            Cache_dir.s3_install_path ^/ constants_filename
          in
          let%bind () =
            match%map
              Cache_dir.load_from_s3 [s3_bucket_prefix]
                [tgz_local_path; proof_local_path; constants_local_path]
                ~logger
            with
            | Ok () ->
                ()
            | Error e ->
                Logger.fatal ~module_:__MODULE__ ~location:__LOC__ logger
                  "Could not download genesis ledger, proof, and constants \
                   from $uri: $error"
                  ~metadata:
                    [ ("uri", `String s3_bucket_prefix)
                    ; ("error", `String (Error.to_string_hum e)) ]
          in
          let%map res = retrieve_genesis_data Cache_dir.s3_install_path in
          res_or_fail
            (String.concat ~sep:"," (s3_bucket_prefix :: directories))
            res )

[%%else]

let retrieve_genesis_proof ~logger : Proof.t Deferred.t =
  (* genesis_dir.ml is generated by building runtime_genesis_ledger, then
     running the script genesis_dir_for_nonconsensus.py
  *)
  let proof_filename = proof_filename_root ^ "." ^ Genesis_dir.genesis_dir in
  (* download genesis proof from s3 *)
  let proof_uri = s3_root ^ "/" ^ proof_filename in
  let%map proof =
    match%map Cache_dir.load_from_s3_to_strings [proof_uri] ~logger with
    | Ok [proof] ->
        proof
    | Ok _ ->
        (* we sent one URI, we expect one result *)
        failwith "Expected single result when downloading genesis proof"
    | Error e ->
        (* exn from Monitor.try_with *)
        Logger.fatal ~module_:__MODULE__ ~location:__LOC__ logger
          "Error when downloading genesis proof from $uri: $error"
          ~metadata:
            [("uri", `String proof_uri); ("error", `String (Exn.to_string e))] ;
        raise Genesis_state_initialization_error
  in
  proof |> Sexp.of_string |> Proof.t_of_sexp

[%%endif]
