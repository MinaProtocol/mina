(* cache_dir.ml *)

[%%import
"/src/config.mlh"]

[%%if
ocaml_backend = "native"]

(* these load-from-disk paths are available to consensus code, and to
   nonconsensus code when compiling to native code
*)

let autogen_path = Core_kernel.Filename.temp_dir_name ^ "/coda_cache_dir"

let s3_install_path = "/tmp/s3_cache_dir"

let manual_install_path = "/var/lib/coda"

let brew_install_path =
  lazy
    ( match
        let p = Core.Unix.open_process_in "brew --prefix 2>/dev/null" in
        let r = Core.In_channel.input_lines p in
        (r, Core.Unix.close_process_in p)
      with
    | brew :: _, Ok () ->
        brew ^ "/var/coda"
    | _ ->
        "/usr/local/var/coda" )

[%%endif]

[%%ifdef
consensus_mechanism]

open Core
open Async

let genesis_dir_name (genesis_constants : Genesis_constants.t) =
  let digest =
    (*include all the time constants that would affect the genesis
    ledger and the proof*)
    let str =
      ( List.map
          [ Coda_compile_config.curve_size
          ; Coda_compile_config.ledger_depth
          ; Coda_compile_config.fake_accounts_target
          ; Coda_compile_config.c
          ; genesis_constants.protocol.k ]
          ~f:Int.to_string
      |> String.concat ~sep:"" )
      ^ Coda_compile_config.proof_level ^ Coda_compile_config.genesis_ledger
    in
    Blake2.digest_string str |> Blake2.to_hex
  in
  let digest_short =
    let len = 16 in
    if String.length digest - len <= 0 then digest
    else String.sub digest ~pos:0 ~len
  in
  "coda_genesis" ^ "_" ^ Coda_version.commit_id_short ^ "_" ^ digest_short

let env_path =
  match Sys.getenv "CODA_KEYS_PATH" with
  | Some path ->
      path
  | None ->
      manual_install_path

let possible_paths base =
  List.map
    [env_path; Lazy.force brew_install_path; s3_install_path; autogen_path]
    ~f:(fun d -> d ^/ base)

let load_from_s3 s3_bucket_prefixes s3_install_paths ~logger =
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
         Deferred.List.map
           (List.zip_exn s3_bucket_prefixes s3_install_paths)
           ~f:each_uri
         |> Deferred.map ~f:Result.all_unit )
  |> Deferred.Result.map_error ~f:Error.of_exn

[%%else]

[%%if
ocaml_backend = "native"]

(* nonconsensus native code; use curl, but as a stepping-stone to Javascript,
   don't use file system
*)
let load_from_s3_to_strings s3_bucket_prefixes ~logger =
  let open Core in
  let open Async in
  Monitor.try_with (fun () ->
      let open Deferred.Let_syntax in
      let each_uri uri_string =
        let%map result = Process.run_exn ~prog:"curl" ~args:[uri_string] () in
        Logger.debug ~module_:__MODULE__ ~location:__LOC__ logger
          "Curl finished"
          ~metadata:[("url", `String uri_string); ("result", `String result)] ;
        result
      in
      Deferred.List.map s3_bucket_prefixes ~f:each_uri )

[%%elif
ocaml_backend = "js_of_ocaml"]

[%%error
"load_from_s3_to_strings: not yet implemented for Javascript"]

[%%else]

[%%error
"Unsupported OCaml backend"]

[%%endif]

[%%endif]
