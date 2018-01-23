open Core_kernel
open Async_kernel

module type S = sig
  type location

  val load
    : location -> Blockchain.t option Deferred.t

  val persist
    : location
    -> [ `Change_head of Blockchain.t ] Linear_pipe.Reader.t
    -> unit
end

module With_checksum = struct
  open Async

  type 'a t = 
    { checksum : Md5.t
    ; data : 'a 
    }
  [@@deriving bin_io]

  (* TODO: test speed *)
  let md5 data (writer : 'a Bin_prot.Type_class.writer) = 
    let buf = Bigstring.create (writer.size data) in
    ignore (writer.write buf ~pos:0 data);
    Md5.digest_string (Bigstring.to_string buf)

  let wrap data writer : 'a t = { checksum = md5 data writer; data }

  let valid t writer = Md5.((md5 t.data writer) = t.checksum)

  let read_data location data_bin_reader_t data_bin_writer_t =
    match%map Reader.load_bin_prot location (bin_reader_t data_bin_reader_t) with
    | Ok t -> 
      if valid t data_bin_writer_t
      then Ok t.data
      else Or_error.error_string "checksum did not match"
    | Error e -> Error e

  let write_data location data_bin_writer_t data = 
    Writer.save_bin_prot 
      location 
      (bin_writer_t data_bin_writer_t)
      (wrap data data_bin_writer_t)
end

module Filesystem : S with type location = string = struct
  open Core
  open Async

  type location = string

  let load location = 
    match%map With_checksum.read_data location Blockchain.bin_reader_t Blockchain.bin_writer_t with
    | Ok blockchain -> Some blockchain
    | Error e -> (eprintf "%s\n" (Error.to_string_hum e); None)


  let persist location block_stream =
    don't_wait_for begin
      Linear_pipe.iter block_stream ~f:(fun (`Change_head block) ->
        With_checksum.write_data location Blockchain.bin_writer_t block)
    end

end

