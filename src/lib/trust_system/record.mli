open Core

type t [@@deriving bin_io]

module type S = sig
  val init : unit -> t

  val ban : t -> t

  val disable_bans : unit -> unit

  val get_bans_disabled : unit -> bool

  val add_trust : t -> float -> t

  val to_peer_status : t -> Peer_status.t
end

val decay_rate : float

module Make (Now : sig
  val now : unit -> Time.t
end) : S
