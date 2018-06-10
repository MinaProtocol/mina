open Core_kernel
open Async_kernel

module type With_checksum_intf = sig
  type 'a t
  type location = string

  module Controller : sig
    type 'a t
    val create : parent_log:Logger.t -> 'a Bin_prot.Type_class.t -> 'a t
  end

  val load : 'a Controller.t -> location -> ('a, [> `Checksum_no_match | `IO_error of Error.t | `No_exist]) Deferred.Result.t
  val load_with_checksum
    : 'a Controller.t
    -> location
    -> ('a Checked_data.t, [> `Checksum_no_match | `IO_error of Error.t | `No_exist]) Deferred.Result.t

  val store : 'a Controller.t -> location -> 'a -> unit Deferred.t

  val store_with_checksum : 'a Controller.t -> location -> 'a -> Md5.t Deferred.t
end

module Memory : With_checksum_intf = Memory
module Disk : With_checksum_intf = Disk

