open Core

exception Invalid of (string * Yojson.t) list

module Error : sig
  type t

  val wrap_exn : Yojson.t -> exn -> t
  val wrap_core_error : Yojson.t -> Error.t -> t
  val to_exn : t list -> exn
  val to_string : t -> string
end

module Validation : sig
  include Monad.S2 with type ('a, 'e) t = ('a, 'e list) Result.t

  val fail : 'e -> ('a, 'e) t
  val map_m : f:('a -> ('b, 'e) t) -> 'a list -> ('b list, 'e) t
  val (>>=?) : ('a option, 'e) t -> ('a -> ('b, 'e) t) -> ('b option, 'e) t
end

type 'a validation = ('a, Error.t) Validation.t

module Expect : sig
  val bool : [< Yojson.t ] -> bool validation
  val int : [< Yojson.t] -> int validation
  val int64 : [< Yojson.t ] -> int64 validation
  val float : [< Yojson.t ] -> float validation
  val string : [< Yojson.t ] -> string validation
  val list : [< Yojson.t ] -> Yojson.t list validation
  val obj : [< Yojson.t ] -> (string * Yojson.t)  list validation
  val enum : variants:(string * 'a) list -> Yojson.t -> 'a validation
  val option : ([> Yojson.t ] -> 'a validation) -> [< Yojson.t ] -> 'a option validation
end

val get : string -> Yojson.t -> Yojson.t validation
val get_opt : string -> Yojson.t -> Yojson.t option validation
val index : int -> Yojson.t -> Yojson.t validation
val assert_no_excess_keys : keys:string list -> Yojson.t -> unit validation

(* For Yojson derivers. *)
module UInt : sig
  type t = Unsigned.UInt.t

  val of_yojson : [< Yojson.Safe.t ] -> (t, string) Ppx_deriving_yojson_runtime.Result.result
  val to_yojson : t -> [> Yojson.Safe.t ]
end

module UInt64 : sig
  type t = Unsigned.UInt64.t

  val of_yojson : [< Yojson.Safe.t ] -> (t, string) Ppx_deriving_yojson_runtime.Result.result
  val to_yojson : t -> [> Yojson.Safe.t ]
end
