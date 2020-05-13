open Core
open Async

let autogen_path = Filename.temp_dir_name ^/ "coda_cache_dir"

let s3_install_path = "/tmp/s3_cache_dir"

let manual_install_path = "/var/lib/coda"

let genesis_dir_name
    ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    ~(genesis_constants : Genesis_constants.t) ~proof_level =
  let digest =
    (*include all the time constants that would affect the genesis
    ledger and the proof*)
    let str =
      ( List.map
          [ Coda_compile_config.curve_size
          ; Coda_compile_config.ledger_depth
          ; Option.value ~default:0 genesis_constants.num_accounts
          ; constraint_constants.c
          ; genesis_constants.protocol.k ]
          ~f:Int.to_string
      |> String.concat ~sep:"" )
      ^ Genesis_constants.Proof_level.to_string proof_level
      ^ Coda_compile_config.genesis_ledger
    in
    Blake2.digest_string str |> Blake2.to_hex
  in
  let digest_short =
    let len = 16 in
    if String.length digest - len <= 0 then digest
    else String.sub digest ~pos:0 ~len
  in
  "coda_genesis" ^ "_" ^ Coda_version.commit_id_short ^ "_" ^ digest_short

let brew_install_path =
  match
    let p = Core.Unix.open_process_in "brew --prefix 2>/dev/null" in
    let r = In_channel.input_lines p in
    (r, Core.Unix.close_process_in p)
  with
  | brew :: _, Ok () ->
      brew ^ "/var/coda"
  | _ ->
      "/usr/local/var/coda"

let env_path =
  match Sys.getenv "CODA_KEYS_PATH" with
  | Some path ->
      path
  | None ->
      manual_install_path

let possible_paths base =
  List.map [env_path; brew_install_path; s3_install_path; autogen_path]
    ~f:(fun d -> d ^/ base)

let load_from_s3 s3_bucket_prefix s3_install_path ~logger =
  Deferred.map ~f:Result.join
  @@ Monitor.try_with (fun () ->
         let each_uri (uri_string, file_path) =
           let open Deferred.Let_syntax in
           let%map result =
             Process.run_exn ~prog:"curl"
               ~args:["-o"; file_path; uri_string]
               ()
           in
           Logger.debug ~module_:__MODULE__ ~location:__LOC__ logger
             "Curl finished"
             ~metadata:
               [ ("url", `String uri_string)
               ; ("local_file_path", `String file_path)
               ; ("result", `String result) ] ;
           Result.return ()
         in
         Deferred.List.map ~f:each_uri
           (List.zip_exn s3_bucket_prefix s3_install_path)
         |> Deferred.map ~f:Result.all_unit )
  |> Deferred.Result.map_error ~f:Error.of_exn
