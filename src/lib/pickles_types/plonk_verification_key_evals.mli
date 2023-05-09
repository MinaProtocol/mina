(* Undocumented *)

module Stable : sig
  module V2 : sig
    type 'comm t =
      { sigma_comms : 'comm array Plonk_types.Permuts_vec.Stable.V1.t
      ; coefficients_comms : 'comm array Plonk_types.Columns_vec.Stable.V1.t
      ; generic_comms : 'comm array
      ; psm_comms : 'comm array
      ; complete_add_comms : 'comm array
      ; mul_comms : 'comm array
      ; emul_comms : 'comm array
      ; endomul_scalar_comms : 'comm array
      }

    include Sigs.Full.S1 with type 'a t := 'a t
  end

  module Latest = V2
end

type 'comm t = 'comm Stable.Latest.t =
  { sigma_comms : 'comm array Plonk_types.Permuts_vec.t
  ; coefficients_comms : 'comm array Plonk_types.Columns_vec.t
  ; generic_comms : 'comm array
  ; psm_comms : 'comm array
  ; complete_add_comms : 'comm array
  ; mul_comms : 'comm array
  ; emul_comms : 'comm array
  ; endomul_scalar_comms : 'comm array
  }
[@@deriving sexp, equal, compare, hash, yojson, hlist]

val typ :
     length:int
  -> ('a, 'b, 'c) Snarky_backendless.Typ.t
  -> ('a t, 'b t, 'c) Snarky_backendless.Typ.t

(** [map t ~f] applies [f] to all elements of type ['a] within record [t] and
    returns the result. In particular, [f] is applied to the elements of
    {!sigma_comms} and {!coefficients_comms}. *)
val map : 'a t -> f:('a -> 'b) -> 'b t

(** [map2] *)
val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t
