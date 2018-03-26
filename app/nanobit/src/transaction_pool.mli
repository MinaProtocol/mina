open Core
open Nanobit_base

type t

val empty : t

val add : t -> Transaction.t -> t

val pop : t -> (Transaction.t * t) option
