(** This module represents user defined bindings of the form (:foo bar). These
    are used in the dependency specification language for example *)

open Stdune

type 'a one =
  | Unnamed of 'a
  | Named of string * 'a list

type 'a t = 'a one list

val map : 'a t -> f:('a -> 'b) -> 'b t

val find : 'a t -> string -> 'a list option

val fold : 'a t -> f:('a one -> 'acc -> 'acc) -> init:'acc -> 'acc

val empty : 'a t

val to_list : 'a t -> 'a list

val singleton : 'a -> 'a t

val to_sexp : 'a Sexp.Encoder.t -> 'a t Sexp.Encoder.t

val decode : 'a Dune_lang.Decoder.t -> 'a t Dune_lang.Decoder.t

val encode : 'a Dune_lang.Encoder.t -> 'a t -> Dune_lang.t
