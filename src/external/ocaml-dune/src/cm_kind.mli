open Stdune

type t = Cmi | Cmo | Cmx

val all : t list

val ext : t -> string
val source : t -> Ml_kind.t

val to_sexp : t Sexp.Encoder.t

module Dict : sig
  type cm_kind = t

  type 'a t =
    { cmi : 'a
    ; cmo : 'a
    ; cmx : 'a
    }

  val get : 'a t -> cm_kind -> 'a

  val of_func : (cm_kind:cm_kind -> 'a) -> 'a t

  val make_all : 'a -> 'a t
end with type cm_kind := t
