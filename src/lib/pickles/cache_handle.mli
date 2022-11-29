(* Cache handle *)

type t = Dirty.t lazy_t

(** [generate_or_load hdl] is an alias for [Lazy.force]. *)
val generate_or_load : t -> Dirty.t

(** [(+)] is semantically equivalent to {!Dirty.(+)}. *)
val ( + ) : t -> t -> t
