open Core
open Snark_params
open Tick
open Fold_lib
open Tuple_lib

type t [@@deriving sexp, bin_io, eq, compare, hash, yojson]

type var = Boolean.var list

val var_to_triples : var -> Boolean.var Triple.t list

val typ : (var, t) Typ.t

val fold : t -> bool Triple.t Fold.t

val length_in_triples : int

val var_of_t : t -> var

val dummy : t

val max_size_in_bytes : int

val create_exn : string -> t
