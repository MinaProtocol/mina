open Core

type t

module type S = sig
  val init : unit -> t

  val add_trust : t -> float -> t

  val to_simple : t -> [`Unbanned of float | `Banned of float * Time.t]
end

val decay_rate : float

module Make (Now : sig
  val now : unit -> Time.t
end) : S
