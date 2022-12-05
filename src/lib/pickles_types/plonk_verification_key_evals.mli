(* Undocumented *)

module Stable : sig
  module V2 : sig
    type 'comm t =
      { sigma_comm : 'comm Plonk_types.Permuts_vec.Stable.V1.t
      ; coefficients_comm : 'comm Plonk_types.Columns_vec.Stable.V1.t
      ; generic_comm : 'comm
      ; psm_comm : 'comm
      ; complete_add_comm : 'comm
      ; mul_comm : 'comm
      ; emul_comm : 'comm
      ; endomul_scalar_comm : 'comm
      }

    include Sigs.Full.S1 with type 'a t := 'a t
  end

  module Latest = V2
end

type 'comm t = 'comm Stable.Latest.t =
  { sigma_comm : 'comm Plonk_types.Permuts_vec.t
  ; coefficients_comm : 'comm Plonk_types.Columns_vec.t
  ; generic_comm : 'comm
  ; psm_comm : 'comm
  ; complete_add_comm : 'comm
  ; mul_comm : 'comm
  ; emul_comm : 'comm
  ; endomul_scalar_comm : 'comm
  }
[@@deriving sexp, equal, compare, hash, yojson, hlist]

val typ :
     ('a, 'b, 'c) Snarky_backendless.Typ.t
  -> ('a t, 'b t, 'c) Snarky_backendless.Typ.t

(** [map t ~f] applies [f] to all elements of type ['a] within record [t] and
    returns the result. In particular, [f] is applied to the elements of
    {!sigma_comm} and {!coefficients_comm}. *)
val map : 'a t -> f:('a -> 'b) -> 'b t

(** [map2] *)
val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t
