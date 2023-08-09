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

module Step : sig
  type ('comm, 'opt_comm) t =
    { sigma_comm : 'comm Plonk_types.Permuts_vec.t
    ; coefficients_comm : 'comm Plonk_types.Columns_vec.t
    ; generic_comm : 'comm
    ; psm_comm : 'comm
    ; complete_add_comm : 'comm
    ; mul_comm : 'comm
    ; emul_comm : 'comm
    ; endomul_scalar_comm : 'comm
    ; xor_comm : 'opt_comm
    ; range_check0_comm : 'opt_comm
    ; range_check1_comm : 'opt_comm
    ; foreign_field_add_comm : 'opt_comm
    ; foreign_field_mul_comm : 'opt_comm
    ; rot_comm : 'opt_comm
    }
  [@@deriving sexp, equal, compare, hash, yojson, hlist]

  val typ :
       ('comm_var, 'comm_value, 'c) Snarky_backendless.Typ.t
    -> ('opt_comm_var, 'opt_comm_value, 'c) Snarky_backendless.Typ.t
    -> ( ('comm_var, 'opt_comm_var) t
       , ('comm_value, 'opt_comm_value) t
       , 'c )
       Snarky_backendless.Typ.t

  val map :
       ('comm1, 'opt_comm1) t
    -> f:('comm1 -> 'comm2)
    -> f_opt:('opt_comm1 -> 'opt_comm2)
    -> ('comm2, 'opt_comm2) t

  val map2 :
       ('comm1, 'opt_comm1) t
    -> ('comm2, 'opt_comm2) t
    -> f:('comm1 -> 'comm2 -> 'comm3)
    -> f_opt:('opt_comm1 -> 'opt_comm2 -> 'opt_comm3)
    -> ('comm3, 'opt_comm3) t

  val forget_optional_commitments :
    ('comm, 'opt_comm) t -> 'comm Stable.Latest.t
end
