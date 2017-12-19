open Core_kernel
open Async_kernel

module type S = sig
  type location

  val load
    : location -> Block.t option Deferred.t

  val persist 
    : location
    -> [ `Change_head of Block.t ] Pipe.Reader.t
    -> unit
end

module Filesystem : S = struct
  open Core
  open Async

  type location = string

  let load location = 
    match%map Reader.load_bin_prot location Block.bin_reader_t with
    | Ok block -> Some block
    | Error _e -> None

  let persist location block_stream = 
    don't_wait_for begin
      Pipe.iter_without_pushback block_stream ~f:(fun (`Change_head block) ->
        don't_wait_for begin
          Writer.save_bin_prot location Block.bin_writer_t block
        end)
    end

end

