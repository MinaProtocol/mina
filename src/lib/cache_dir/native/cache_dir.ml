open Core
open Async

let autogen_path = Filename.temp_dir_name ^/ "coda_cache_dir"

let gs_install_path = "/tmp/s3_cache_dir"

let gs_ledger_bucket_prefix = "mina-genesis-ledgers"

let manual_install_path = "/var/lib/coda"

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

let cache =
  let dir d w = Key_cache.Spec.On_disk { directory = d; should_write = w } in
  [ dir manual_install_path false
  ; dir brew_install_path false
  ; dir gs_install_path false
  ; dir autogen_path true
  ; Key_cache.Spec.S3
      { bucket_prefix = gs_ledger_bucket_prefix
      ; install_path = gs_install_path
      }
  ]

let env_path =
  match Sys.getenv "MINA_KEYS_PATH" with
  | Some path ->
      path
  | None ->
      manual_install_path

let possible_paths base =
  List.map
    [ env_path
    ; brew_install_path
    ; gs_install_path
    ; autogen_path
    ; manual_install_path
    ] ~f:(fun d -> d ^/ base)

let load_from_gs gs_install_path ~gs_bucket_prefix ~gs_object_name ~logger =
  let%bind () = Unix.mkdir ~p:() (Filename.dirname gs_install_path) in
  Deferred.map ~f:Result.join
  @@ Monitor.try_with ~here:[%here] (fun () ->
         let each_uri (uri_string, file_path) =
           let open Deferred.Let_syntax in
           [%log trace] "Downloading file from Google Storage"
             ~metadata:
               [ ("url", `String uri_string)
               ; ("local_file_path", `String file_path)
               ] ;
           let%map _result =
             Process.run ~prog:"gsutil"
               ~args:[ "-m"; "cp"; uri_string; file_path ]
               ()
           in
           [%log trace] "Download finished"
             ~metadata:
               [ ("url", `String uri_string)
               ; ("local_file_path", `String file_path)
               ] ;
           Result.return ()
         in
         each_uri
           ( sprintf "gs://%s/%s" gs_bucket_prefix gs_object_name
           , gs_install_path ) )
  |> Deferred.Result.map_error ~f:Error.of_exn
