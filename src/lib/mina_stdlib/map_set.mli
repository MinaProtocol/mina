module Make (Key : Comparable.S) (Set : Generic_set.S0) : sig
  type t = Set.t Key.Map.t [@@deriving equal]

  val remove_exn : t -> Key.t -> Set.el -> t

  val insert : t -> Key.t -> Set.el -> t
end

module Make_with_sexp_of
    (Key : Comparable.S) (Set : sig
      include Generic_set.S0

      val sexp_of_t : t -> Sexp.t
    end) : sig
  include module type of Make (Key) (Set)

  val sexp_of_t : t -> Sexp.t
end
