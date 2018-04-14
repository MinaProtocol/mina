open Core_kernel
open Async_kernel
open Nanobit_base
open Blockchain_snark

module type S = sig
  type location

  val load
    : location 
    -> Logger.t
    -> Blockchain.t option Deferred.t

  val persist
    : location
    -> [ `Change_head of Blockchain.t ] Linear_pipe.Reader.t
    -> unit
end

module Make (Store : Storage.With_checksum_intf) = struct
  open Core
  open Async

  type location = string

  let controller parent_log =
    let open Blockchain.Stable.V1 in
    Store.Controller.create
      ~parent_log
      { Bin_prot.Type_class.writer = bin_writer_t
      ; reader = bin_reader_t
      ; shape = bin_shape_t
      }

  let load location parent_log = 
    let log = Logger.child parent_log "storage" in
    match%map Store.load (controller parent_log) location with
    | Ok blockchain -> Some blockchain
    | Error (`IO_error e) ->
        Logger.error log "IO_error %s" (Error.to_string_hum e); None
    | Error (`No_exist) ->
        Logger.error log "blockchain doesn't exist"; None
    | Error (`Checksum_no_match) ->
        Logger.error log "checksum doesn't match, maybe tampering"; None

  let persist location block_stream =
    don't_wait_for begin
      Linear_pipe.iter block_stream ~f:(fun (`Change_head block) ->
        Store.store (controller (Logger.create ())) location block)
    end
end

module Filesystem : S with type location = string = Make(Storage.Disk)

