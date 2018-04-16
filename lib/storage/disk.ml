open Core
open Async

module Location = String
type location = Location.t

include Checked_data

module Controller = struct
  type nonrec 'a t =
    { log : Logger.t
    ; tc : 'a Bin_prot.Type_class.t
    }
  let create ~parent_log tc =
    { log = Logger.child parent_log "storage.with_checksum.memory"
    ; tc
    }
end

let load (c : 'a Controller.t) location =
  match%map Reader.load_bin_prot location (bin_reader_t c.tc.reader) with
  | Ok t ->
    if valid c.tc t
    then Ok t.data
    else Error `Checksum_no_match
  | Error e -> Error (`IO_error e)

let store (c : 'a Controller.t) location data = 
  Writer.save_bin_prot
    location
    (bin_writer_t c.tc.writer)
    (wrap c.tc data)

