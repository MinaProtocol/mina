open Core
open Key_cache
include T (Or_error)

let on_disk to_string read write prefix =
  let path k = prefix ^/ to_string k in
  let read k =
    let p = path k in
    match Sys.file_exists p with
    | `No | `Unknown ->
        Or_error.errorf "file %s does not exist or cannot be read" p
    | `Yes ->
        read k ~path:p
  in
  let write key v =
    match Sys.is_directory prefix with
    | `No | `Unknown ->
        Or_error.errorf "directory %s does not exist or cannot be read" prefix
    | `Yes ->
        write key v (path key)
  in
  { read; write }

let s3 to_string read ~bucket_prefix ~install_path =
  let read k =
    let logger = Logger.create () in
    let label = to_string k in
    let uri_string = bucket_prefix ^/ label in
    let file_path = install_path ^/ label in
    let open Or_error.Let_syntax in
    [%log trace] "Downloading key to key cache"
      ~metadata:
        [ ("url", `String uri_string); ("local_file_path", `String file_path) ] ;
    let%bind () =
      Result.map_error
        (ksprintf Unix.system
           "curl --fail --silent --show-error -o \"%s\" \"%s\"" file_path
           uri_string ) ~f:(function
        | `Exit_non_zero _ as e ->
            Error.of_string (Unix.Exit.to_string_hum (Error e))
        | `Signal s ->
            Error.createf "died after receiving %s (signal number %d)"
              (Signal.to_string s) (Signal.to_system_int s) )
      |> Result.map_error ~f:(fun err ->
             [%log trace] "Could not download key to key cache"
               ~metadata:
                 [ ("url", `String uri_string)
                 ; ("local_file_path", `String file_path)
                 ] ;
             err )
    in
    [%log trace] "Downloaded key to key cache"
      ~metadata:
        [ ("url", `String uri_string); ("local_file_path", `String file_path) ] ;
    read k ~path:file_path
  in
  let write _ _ = Or_error.return () in
  { read; write }

module Disk_storable = struct
  include Disk_storable (Or_error)

  let of_binable to_string m =
    (* TODO: Make more efficient *)
    let read _ ~path =
      Or_error.try_with (fun () ->
          Binable.of_string m (In_channel.read_all path) )
    in
    let write _k t path =
      Or_error.try_with (fun () ->
          Out_channel.write_all path ~data:(Binable.to_string m t) )
    in
    { to_string; read; write }

  let simple to_string read write =
    { to_string
    ; read = (fun k ~path -> read k ~path)
    ; write = (fun k v s -> write k v s)
    }
end

let read spec { Disk_storable.to_string; read = r; write = w } k =
  Or_error.find_map_ok spec ~f:(fun s ->
      let res, cache_hit =
        match s with
        | Spec.On_disk { directory; should_write } ->
            ( (on_disk to_string r w directory).read k
            , if should_write then `Locally_generated else `Cache_hit )
        | S3 _ when not (may_download ()) ->
            (Or_error.errorf "Downloading from S3 is disabled", `Cache_hit)
        | S3 { bucket_prefix; install_path } ->
            Unix.mkdir_p install_path ;
            ((s3 to_string r ~bucket_prefix ~install_path).read k, `Cache_hit)
      in
      let%map.Or_error res = res in
      (res, cache_hit) )

let write spec { Disk_storable.to_string; read = r; write = w } k v =
  let errs =
    List.filter_map spec ~f:(fun s ->
        let res =
          match s with
          | Spec.On_disk { directory; should_write } ->
              if should_write then (
                Unix.mkdir_p directory ;
                (on_disk to_string r w directory).write k v )
              else Or_error.return ()
          | S3 { bucket_prefix = _; install_path = _ } ->
              Or_error.return ()
        in
        match res with Error e -> Some e | Ok () -> None )
  in
  match errs with [] -> Ok () | errs -> Error (Error.of_list errs)
