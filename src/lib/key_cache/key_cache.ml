open Core
open Async

module Spec = struct
  type t =
    | On_disk of {directory: string; should_write: bool}
    | S3 of {bucket_prefix: string; install_path: string}
end

type ('a, 'b) t =
  { write: 'a -> 'b -> unit Deferred.Or_error.t
  ; read: 'a -> 'b Deferred.Or_error.t }

let map_input : ('a, 'b) t -> f:('x -> 'a) -> ('x, 'b) t =
 fun {write; read} ~f ->
  {read= (fun x -> read (f x)); write= (fun x y -> write (f x) y)}

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
             prefix)
    | `Yes ->
        write v (path key)
  in
  {read; write}

let s3 to_string read ~bucket_prefix ~install_path =
  let read k =
    let label = to_string k in
    let uri_string = bucket_prefix ^/ label in
    let file_path = install_path ^/ label in
    let open Deferred.Or_error.Let_syntax in
    let%bind result =
      let open Deferred.Let_syntax in
      match%map Process.run ~prog:"curl" ~args:["--fail"; "-o"; file_path; uri_string] () with
      | Ok "" -> Or_error.error_string "Key not found"
      | t -> t
    in
    Logger.debug ~module_:__MODULE__ ~location:__LOC__ (Logger.create ())
      "Curl finished"
      ~metadata:
        [ ("url", `String uri_string)
        ; ("local_file_path", `String file_path)
        ; ("result", `String result) ] ;
    read k ~path:file_path
  in
  let write _ _ = Deferred.Or_error.return () in
  {read; write}

module Disk_storable = struct
  type ('k, 'v) t =
    { to_string: 'k -> string
    ; read: 'k -> path:string -> 'v Deferred.Or_error.t
    ; write: 'v -> string -> unit Deferred.Or_error.t }

  let of_binable (type t) to_string (module B : Binable.S with type t = t) =
    let read _ ~path = Reader.load_bin_prot path B.bin_reader_t in
    let write t path =
      Deferred.map
        (Writer.save_bin_prot path B.bin_writer_t t)
        ~f:Or_error.return
    in
    {to_string; read; write}

  let simple to_string read write =
    { to_string
    ; read= (fun k ~path -> Deferred.Or_error.return (read k ~path))
    ; write= (fun v s -> Deferred.Or_error.return (write v s)) }
end

let read spec {Disk_storable.to_string; read= r; write= w} k =
  let errs = ref [] in
  match%map
    Deferred.List.find_mapi spec ~f:(fun i s ->
        let res =
          match s with
          | Spec.On_disk {directory; _} ->
              (on_disk to_string r w directory).read k
          | S3 {bucket_prefix; install_path} ->
              (s3 to_string r ~bucket_prefix ~install_path).read k
        in
        match%map res with
        | Error e ->
            errs := e :: !errs ;
            None
        | Ok x ->
            Some (i, x) )
  with
  | Some (i, x) ->
      Ok (x, if i = 0 then `Cache_hit else `Locally_generated)
  | None ->
      Error (Error.of_list !errs)

let write spec {Disk_storable.to_string; read= r; write= w} k v =
  let%map errs =
    Deferred.List.filter_map spec ~f:(fun s ->
        let res =
          match s with
          | Spec.On_disk {directory; should_write} ->
              if should_write then (
                Core.printf "write on disk %s %b\n%!" directory should_write ;
                let%bind () = Unix.mkdir ~p:() directory in
                Core.printf "made dir %s\n%!" directory ;
                (on_disk to_string r w directory).write k v )
              else Deferred.Or_error.return ()
          | S3 {bucket_prefix=_; install_path=_} ->
            Deferred.Or_error.return ()
        in
        match%map res with Error e -> Some e | Ok () -> None )
  in
  match errs with [] -> Ok () | errs -> Error (Error.of_list errs)
