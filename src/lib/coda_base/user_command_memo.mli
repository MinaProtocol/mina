open Core
open Snark_params
open Tick
open Fold_lib
open Tuple_lib

type t [@@deriving sexp, bin_io, eq, compare, hash, yojson]

module Checked : sig
  type unchecked = t

  type t = private Boolean.var array

  val to_triples : t -> Boolean.var Triple.t list

  val constant : unchecked -> t
end

val typ : (Checked.t, t) Typ.t

val fold : t -> bool Triple.t Fold.t

val length_in_triples : int

val dummy : t

val max_size_in_bytes : int

val create_exn : string -> t
