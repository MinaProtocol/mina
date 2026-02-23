(** Utilities for dealing with "multimaps" or mapsets. *)

open Core_kernel

(* TODO consider using a lighter interface than Comparable.S *)
module Make (Key : Comparable.S) (Set : Generic_set.S0) = struct
  type t = Set.t Key.Map.t [@@deriving equal]

  (** Remove an element from a mapset. *)
  let remove_exn : t -> Key.t -> Set.el -> t =
   fun map k v ->
    let newset = Map.find_exn map k |> Fn.flip Set.remove v in
    if Set.is_empty newset then Map.remove map k
    else Map.set map ~key:k ~data:newset

  (* Add an element to a mapset. *)
  let insert : t -> Key.t -> Set.el -> t =
   fun map k v ->
    Map.change map k ~f:(fun set_opt ->
        match set_opt with
        | None ->
            Some (Set.singleton v)
        | Some set ->
            Some (Set.add set v) )
end

module Make_with_sexp_of
    (Key : Comparable.S) (Set : sig
      include Generic_set.S0

      val sexp_of_t : t -> Sexp.t
    end) =
struct
  include Make (Key) (Set)

  let sexp_of_t = [%sexp_of: Set.t Key.Map.t]
end
