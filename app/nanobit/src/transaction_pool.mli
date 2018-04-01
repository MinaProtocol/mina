open Core
open Nanobit_base

type t

val create : unit -> t

val add : t -> Transaction.t -> unit

val pop : t -> Transaction.t option

val remove : t -> Transaction.t -> unit
