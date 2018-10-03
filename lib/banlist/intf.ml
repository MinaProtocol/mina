open Async_kernel

module type S = sig
  type t

  type host

  val record : t -> host -> Offense.t -> unit

  val compute_score : Offense.t -> int

  val punishment : t -> Offense.t list -> Punishment.t option

  val ban : t -> host -> Punishment.t -> unit

  val unban : t -> host -> unit

  val lookup :
       t
    -> host
    -> [`Normal | `Punished of Punishment.t | `Suspicious of Offense.t list]

  val close : t -> unit Deferred.t
end
