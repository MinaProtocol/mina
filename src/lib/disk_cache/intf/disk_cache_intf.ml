open Core_kernel
open Async_kernel

module type S = sig
  module Data : Binable.S

  type t

  (** Initialize the on-disk cache explicitly before interactions with it take
      place. If disk_meta_location is set, will try to read from metadata at 
      that location, so to reuse disk cache from a previous run. *)
  val initialize :
       string
    -> logger:Logger.t
    -> ?disk_meta_location:string
    -> unit
    -> (t, [> `Initialization_error of Error.t ]) Deferred.Result.t

  type id [@@deriving bin_io]

  (** Put the value to disk, return an identifier that is associated with a special handler in GC. *)
  val put : t -> Data.t -> id

  (** Read from the cache, crashing if the value cannot be found. *)
  val get : t -> id -> Data.t

  (** We created an ID without invoking `put`, trying to test if the ID exist, if so, register GC *)
  val try_get_deserialized : t -> id -> Data.t option
end

module type S_with_count = sig
  include S

  (** Count elements in the cache. *)
  val count : t -> int
end

module type F = functor (Data : Binable.S) -> sig
  include S with module Data := Data
end

module type F_with_count = functor (Data : Binable.S) -> sig
  include S_with_count with module Data := Data
end

module type F_extended = functor (Data : Binable.S) -> sig
  include S_with_count with module Data := Data

  val iteri : t -> f:(int -> Data.t -> [< `Continue ]) -> unit

  val int_of_id : id -> int

  (** Count elements in the cache. *)
  val count : t -> int
end
