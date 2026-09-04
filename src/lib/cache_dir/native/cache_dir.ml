open Core
open Async

let autogen_path = Filename.temp_dir_name ^/ "coda_cache_dir"

let s3_install_path = Filename.temp_dir_name ^/ "s3_cache_dir"

let s3_keys_bucket_prefix =
  Option.value
    (Sys.getenv "MINA_LEDGER_S3_BUCKET")
    ~default:"https://s3-us-west-2.amazonaws.com/snark-keys-ro.o1test.net"

let manual_install_path = "/var/lib/coda"

(* Homebrew's prefix on Intel and on Apple Silicon. Both are listed
   unconditionally rather than asking [brew --prefix]: these are read-only
   lookup paths and a nonexistent one is simply skipped, whereas the query
   costs a subprocess at module initialization on every platform, Linux
   included. *)
let brew_install_paths = [ "/usr/local/var/coda"; "/opt/homebrew/var/coda" ]

let cache =
  let dir d w = Key_cache.Spec.On_disk { directory = d; should_write = w } in
  ( [ dir manual_install_path false ]
  @ List.map brew_install_paths ~f:(fun d -> dir d false) )
  @ [ dir s3_install_path false
    ; dir autogen_path true
    ; Key_cache.Spec.S3
        { bucket_prefix = s3_keys_bucket_prefix
        ; install_path = s3_install_path
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
    ( (env_path :: brew_install_paths)
    @ [ s3_install_path; autogen_path; manual_install_path ] )
    ~f:(fun d -> d ^/ base)

let load_from_s3 s3_bucket_prefix s3_install_path ~logger =
  let%bind () = Unix.mkdir ~p:() (Filename.dirname s3_install_path) in
  Deferred.map ~f:Result.join
  @@ Monitor.try_with ~here:[%here] (fun () ->
      let each_uri (uri_string, file_path) =
        let open Deferred.Let_syntax in
        [%log trace] "Downloading file from S3: $url to $local_file_path"
          ~metadata:
            [ ("url", `String uri_string)
            ; ("local_file_path", `String file_path)
            ] ;
        let%map _result =
          Process.run_exn ~prog:"curl"
            ~args:
              [ "--fail"
              ; "--silent"
              ; "--show-error"
              ; "-o"
              ; file_path
              ; uri_string
              ]
            ()
        in
        [%log trace] "Download finished"
          ~metadata:
            [ ("url", `String uri_string)
            ; ("local_file_path", `String file_path)
            ] ;
        Result.return ()
      in
      each_uri (s3_bucket_prefix, s3_install_path) )
  |> Deferred.Result.map_error ~f:Error.of_exn
