open Core
open Async
open Key_cache
open Async_kernel
include T (Deferred.Or_error)

let on_disk to_string read write prefix =
  let path k = prefix ^/ to_string k in
  let read k =
    let p = path k in
    match%bind Sys.file_exists p with
    | `No | `Unknown ->
        return (Or_error.errorf "file %s does not exist or cannot be read" p)
    | `Yes ->
        read k ~path:p
  in
  let write key v =
    match%bind Sys.is_directory prefix with
    | `No | `Unknown ->
        return
          (Or_error.errorf "directory %s does not exist or cannot be read"
             prefix )
    | `Yes ->
        write key v (path key)
  in
  { read; write }

module Disk_storable = struct
  include Disk_storable (Deferred.Or_error)

  let of_binable (type t) to_string (module B : Binable.S with type t = t) =
    let read _ ~path = Reader.load_bin_prot path B.bin_reader_t in
    let write _ t path =
      Deferred.map
        (Writer.save_bin_prot path B.bin_writer_t t)
        ~f:Or_error.return
    in
    { to_string; read; write }

  let simple to_string read write =
    { to_string
    ; read = (fun k ~path -> read k ~path)
    ; write = (fun v s -> write v s)
    }
end

let read spec { Disk_storable.to_string; read = r; write = w } k =
  Deferred.Or_error.find_map_ok spec ~f:(fun s ->
      let open Deferred.Or_error.Let_syntax in
      match s with
      | Spec.On_disk { directory; should_write } ->
          let%map res = (on_disk to_string r w directory).read k in
          (res, if should_write then `Locally_generated else `Cache_hit)
      | S3 _ ->
          Deferred.Or_error.errorf "Downloading from S3 is disabled" )

let write spec { Disk_storable.to_string; read = r; write = w } k v =
  let%map errs =
    Deferred.List.filter_map spec ~f:(fun s ->
        let res =
          match s with
          | Spec.On_disk { directory; should_write } ->
              if should_write then
                let%bind () = Unix.mkdir ~p:() directory in
                (on_disk to_string r w directory).write k v
              else Deferred.Or_error.return ()
          | S3 { bucket_prefix = _; install_path = _ } ->
              Deferred.Or_error.return ()
        in
        match%map res with Error e -> Some e | Ok () -> None )
  in
  match errs with [] -> Ok () | errs -> Error (Error.of_list errs)
