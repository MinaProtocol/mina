open! Stdune

type t =
  | String of string
  | Dir of Path.t
  | Path of Path.t

val to_sexp : t Sexp.Encoder.t

val to_string : t -> dir:Path.t -> string

val to_path : ?error_loc:Loc.t -> t -> dir:Path.t -> Path.t

module L : sig
  val strings : string list -> t list

  (** [compare_vals ~dir a b] is a more efficient version of:

      {[
        List.compare ~compare:String.compare
          (to_string ~dir a)
          (to_string ~dir b)
      ]}
  *)
  val compare_vals : dir:Path.t -> t list -> t list -> Ordering.t

  val paths : Path.t list -> t list

  val deps_only : t list -> Path.t list

  val dirs : Path.t list -> t list

  val concat : t list -> dir:Path.t -> string

  val to_strings : t list -> dir:Path.t -> string list
end
