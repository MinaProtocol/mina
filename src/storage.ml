open Core_kernel
open Async_kernel

module type S = sig
  type location

  val load
    : location -> Blockchain.t option Deferred.t

  val persist
    : location
    -> [ `Change_head of Blockchain.t ] Pipe.Reader.t
    -> unit
end

module Filesystem : S with type location = string = struct
  open Core
  open Async

  type location = string

  let load location =
    match%map Reader.load_bin_prot location Blockchain.bin_reader_t with
    | Ok block -> Some block
    | Error _e -> None

  let persist location block_stream =
    don't_wait_for begin
      Pipe.iter_without_pushback block_stream ~f:(fun (`Change_head block) ->
        don't_wait_for begin
          Writer.save_bin_prot location Blockchain.bin_writer_t block
        end)
    end

end

