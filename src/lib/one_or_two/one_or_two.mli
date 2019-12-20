(** Simple container of one of two values of a given type. *)
open Core

open Async

module Stable : sig
  module V1 : sig
    type 'a t = 'a Intfs.t
    [@@deriving bin_io, compare, equal, hash, sexp, version, yojson]
  end

  module Latest = V1
end

type 'a t = 'a Intfs.t [@@deriving compare, equal, hash, sexp, yojson]

val length : 'a t -> int

val to_list : 'a t -> 'a list

val group_sequence : 'a Sequence.t -> 'a t Sequence.t

val group_list : 'a list -> 'a t list

val zip : 'a t -> 'b t -> ('a * 'b) t Or_error.t

val zip_exn : 'a t -> 'b t -> ('a * 'b) t

val map : 'a t -> f:('a -> 'b) -> 'b t

val iter : 'a t -> f:('a -> unit) -> unit

val fold : 'a t -> init:'accum -> f:('accum -> 'a -> 'accum) -> 'accum

val fold_until :
     init:'b
  -> f:('b -> 'a -> ('b, 'final) Continue_or_stop.t)
  -> finish:('b -> 'final)
  -> 'a t
  -> 'final

module Deferred_result :
  Intfs.Monadic2 with type ('a, 'e) m := ('a, 'e) Result.t Deferred.t

module Deferred : Intfs.Monadic with type 'a m := 'a Deferred.t

module Option : Intfs.Monadic with type 'a m := 'a option

module Or_error : Intfs.Monadic with type 'a m := 'a Or_error.t

val gen : 'a Quickcheck.Generator.t -> 'a t Quickcheck.Generator.t
