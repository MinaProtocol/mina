open Core
open Async
module Location = String

type location = Location.t [@@deriving sexp]

include Checked_data

module Controller = struct
  type nonrec 'a t = {log: Logger.t; tc: 'a Bin_prot.Type_class.t}

  let create ~parent_log tc =
    {log= Logger.child parent_log "storage.with_checksum.memory"; tc}
end

let load_with_checksum (c : 'a Controller.t) location =
  match%bind Sys.file_exists location with
  | `Yes -> (
      match%map
        Reader.load_bin_prot
          ~max_len:(1000 * 1024 * 1024)
          location (bin_reader_t c.tc.reader)
      with
      | Ok t -> if valid c.tc t then Ok t else Error `Checksum_no_match
      | Error e -> Error (`IO_error e) )
  | `No | `Unknown -> return (Error `No_exist)

let load c location =
  Deferred.Result.map (load_with_checksum c location) ~f:(fun t -> t.data)

let atomic_write (c : 'a Controller.t) location data =
  let temp_location = location ^ ".temp" in
  let t = wrap c.tc data in
  let%bind () =
    Writer.save_bin_prot temp_location (bin_writer_t c.tc.writer) t
  in
  let%map () = Sys.rename temp_location location in
  t

let store_with_checksum (c : 'a Controller.t) location data =
  atomic_write c location data >>| fun t -> t.checksum

let store c location data = atomic_write c location data |> Deferred.ignore
