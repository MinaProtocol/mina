open Core
open Async

module State : sig
  type t

  val create : unit -> t Deferred.t
end

val perform : State.t -> Work.Spec.t -> Work.Result.t Or_error.t

val command : Command.t
