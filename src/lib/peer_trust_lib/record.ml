open Core

module type S = sig
  type t

  val init : unit -> t

  val add_trust : t -> float -> t

  val to_simple : t -> [`Unbanned of float | `Banned of float * Time.t]
end

(* Trust is conceptually multiplied by this factor every second. This value is
   such that trust halves in 24 hours. =~ 0.999992 *)
let decay_rate = 0.5 ** (1. /. (60. *. 60. *. 24.))

let stub () = failwith "stub"

(** Module handling the data associated with a peer's trust.
    @param Now get the current time. Functored for mocking.
*)
module Make (Now : sig
  val now : unit -> Time.t
end) : S = struct
  type t = unit

  (** Create a new blank trust record. *)
  let init = stub

  (** Add some trust, subtract by passing a negative number. *)
  let add_trust _ _ = stub ()

  (** Convert the internal type to the externally visible one. *)
  let to_simple = stub
end
