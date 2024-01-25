open Core_kernel
module H_list = Snarky_backendless.H_list

[%%versioned
module Stable = struct
  module V2 = struct
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
    [@@deriving sexp, equal, compare, hash, yojson, hlist, fields]
    (* TODO: Remove unused annotations *)
  end
end]

(* TODO: Remove unused functions *)

let map
    { sigma_comm
    ; coefficients_comm
    ; generic_comm
    ; psm_comm
    ; complete_add_comm
    ; mul_comm
    ; emul_comm
    ; endomul_scalar_comm
    } ~f =
  { sigma_comm = Vector.map ~f sigma_comm
  ; coefficients_comm = Vector.map ~f coefficients_comm
  ; generic_comm = f generic_comm
  ; psm_comm = f psm_comm
  ; complete_add_comm = f complete_add_comm
  ; mul_comm = f mul_comm
  ; emul_comm = f emul_comm
  ; endomul_scalar_comm = f endomul_scalar_comm
  }

let map2 t1 t2 ~f =
  { sigma_comm = Vector.map2 ~f t1.sigma_comm t2.sigma_comm
  ; coefficients_comm = Vector.map2 ~f t1.coefficients_comm t2.coefficients_comm
  ; generic_comm = f t1.generic_comm t2.generic_comm
  ; psm_comm = f t1.psm_comm t2.psm_comm
  ; complete_add_comm = f t1.complete_add_comm t2.complete_add_comm
  ; mul_comm = f t1.mul_comm t2.mul_comm
  ; emul_comm = f t1.emul_comm t2.emul_comm
  ; endomul_scalar_comm = f t1.endomul_scalar_comm t2.endomul_scalar_comm
  }

let typ g =
  Snarky_backendless.Typ.of_hlistable
    [ Vector.typ g Plonk_types.Permuts.n
    ; Vector.typ g Plonk_types.Columns.n
    ; g
    ; g
    ; g
    ; g
    ; g
    ; g
    ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist
