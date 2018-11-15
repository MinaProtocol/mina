open Stdune

type t = Impl | Intf

val all : t list

val pp : t Fmt.t

(** "" or "i" *)
val suffix : t -> string

val to_string : t -> string

val flag : t -> _ Arg_spec.t
val ppx_driver_flag : t -> _ Arg_spec.t

module Dict : sig
  type kind = t

  type 'a t =
    { impl : 'a
    ; intf : 'a
    }

  val get : 'a t -> kind -> 'a

  val of_func : (ml_kind:kind -> 'a) -> 'a t

  val make_both : 'a -> 'a t

  val map : 'a t -> f:('a -> 'b) -> 'b t
end with type kind := t
