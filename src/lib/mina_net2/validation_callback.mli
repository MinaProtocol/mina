open Core
open Async

type validation_result = [ `Accept | `Reject | `Ignore ] [@@deriving equal]

type t

val create : Time_ns.t -> t

val create_without_expiration : unit -> t

val is_expired : t -> bool

val await : t -> validation_result option Deferred.t

val await_exn : t -> validation_result Deferred.t

(** May return a deferred that never resolves, in the case of callbacks without expiration. *)
val await_timeout : t -> unit Deferred.t

val fire_if_not_already_fired : t -> validation_result -> unit

val set_message_type :
  t -> [ `Unknown | `Block | `Snark_work | `Transaction ] -> unit
