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

module Step = struct
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
    ; lookup_table_comm : 'opt_comm Plonk_types.Lookup_sorted_minus_1_vec.t
    ; lookup_table_ids : 'opt_comm
    ; runtime_tables_selector : 'opt_comm
    ; lookup_selector_lookup : 'opt_comm
    ; lookup_selector_xor : 'opt_comm
    ; lookup_selector_range_check : 'opt_comm
    ; lookup_selector_ffmul : 'opt_comm
    }
  [@@deriving sexp, equal, compare, hash, yojson, hlist, fields]

  let map
      { sigma_comm
      ; coefficients_comm
      ; generic_comm
      ; psm_comm
      ; complete_add_comm
      ; mul_comm
      ; emul_comm
      ; endomul_scalar_comm
      ; xor_comm
      ; range_check0_comm
      ; range_check1_comm
      ; foreign_field_add_comm
      ; foreign_field_mul_comm
      ; rot_comm
      ; lookup_table_comm
      ; lookup_table_ids
      ; runtime_tables_selector
      ; lookup_selector_lookup
      ; lookup_selector_xor
      ; lookup_selector_range_check
      ; lookup_selector_ffmul
      } ~f ~f_opt =
    { sigma_comm = Vector.map ~f sigma_comm
    ; coefficients_comm = Vector.map ~f coefficients_comm
    ; generic_comm = f generic_comm
    ; psm_comm = f psm_comm
    ; complete_add_comm = f complete_add_comm
    ; mul_comm = f mul_comm
    ; emul_comm = f emul_comm
    ; endomul_scalar_comm = f endomul_scalar_comm
    ; xor_comm = f_opt xor_comm
    ; range_check0_comm = f_opt range_check0_comm
    ; range_check1_comm = f_opt range_check1_comm
    ; foreign_field_add_comm = f_opt foreign_field_add_comm
    ; foreign_field_mul_comm = f_opt foreign_field_mul_comm
    ; rot_comm = f_opt rot_comm
    ; lookup_table_comm = Vector.map ~f:f_opt lookup_table_comm
    ; lookup_table_ids = f_opt lookup_table_ids
    ; runtime_tables_selector = f_opt runtime_tables_selector
    ; lookup_selector_lookup = f_opt lookup_selector_lookup
    ; lookup_selector_xor = f_opt lookup_selector_xor
    ; lookup_selector_range_check = f_opt lookup_selector_range_check
    ; lookup_selector_ffmul = f_opt lookup_selector_ffmul
    }

  let map2 t1 t2 ~f ~f_opt =
    { sigma_comm = Vector.map2 ~f t1.sigma_comm t2.sigma_comm
    ; coefficients_comm =
        Vector.map2 ~f t1.coefficients_comm t2.coefficients_comm
    ; generic_comm = f t1.generic_comm t2.generic_comm
    ; psm_comm = f t1.psm_comm t2.psm_comm
    ; complete_add_comm = f t1.complete_add_comm t2.complete_add_comm
    ; mul_comm = f t1.mul_comm t2.mul_comm
    ; emul_comm = f t1.emul_comm t2.emul_comm
    ; endomul_scalar_comm = f t1.endomul_scalar_comm t2.endomul_scalar_comm
    ; xor_comm = f_opt t1.xor_comm t2.xor_comm
    ; range_check0_comm = f_opt t1.range_check0_comm t2.range_check0_comm
    ; range_check1_comm = f_opt t1.range_check1_comm t2.range_check1_comm
    ; foreign_field_add_comm =
        f_opt t1.foreign_field_add_comm t2.foreign_field_add_comm
    ; foreign_field_mul_comm =
        f_opt t1.foreign_field_mul_comm t2.foreign_field_mul_comm
    ; rot_comm = f_opt t1.rot_comm t2.rot_comm
    ; lookup_table_comm =
        Vector.map2 ~f:f_opt t1.lookup_table_comm t2.lookup_table_comm
    ; lookup_table_ids = f_opt t1.lookup_table_ids t2.lookup_table_ids
    ; runtime_tables_selector =
        f_opt t1.runtime_tables_selector t2.runtime_tables_selector
    ; lookup_selector_lookup =
        f_opt t1.lookup_selector_lookup t2.lookup_selector_lookup
    ; lookup_selector_xor = f_opt t1.lookup_selector_xor t2.lookup_selector_xor
    ; lookup_selector_range_check =
        f_opt t1.lookup_selector_range_check t2.lookup_selector_range_check
    ; lookup_selector_ffmul =
        f_opt t1.lookup_selector_ffmul t2.lookup_selector_ffmul
    }

  let typ g g_opt =
    Snarky_backendless.Typ.of_hlistable
      [ Vector.typ g Plonk_types.Permuts.n
      ; Vector.typ g Plonk_types.Columns.n
      ; g
      ; g
      ; g
      ; g
      ; g
      ; g
      ; g_opt
      ; g_opt
      ; g_opt
      ; g_opt
      ; g_opt
      ; g_opt
      ; Vector.typ g_opt Plonk_types.Lookup_sorted_minus_1.n
      ; g_opt
      ; g_opt
      ; g_opt
      ; g_opt
      ; g_opt
      ; g_opt
      ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  let forget_optional_commitments
      { sigma_comm
      ; coefficients_comm
      ; generic_comm
      ; psm_comm
      ; complete_add_comm
      ; mul_comm
      ; emul_comm
      ; endomul_scalar_comm
      ; xor_comm = _
      ; range_check0_comm = _
      ; range_check1_comm = _
      ; foreign_field_add_comm = _
      ; foreign_field_mul_comm = _
      ; rot_comm = _
      ; lookup_table_comm = _
      ; lookup_table_ids = _
      ; runtime_tables_selector = _
      ; lookup_selector_lookup = _
      ; lookup_selector_xor = _
      ; lookup_selector_range_check = _
      ; lookup_selector_ffmul = _
      } : _ Stable.Latest.t =
    { sigma_comm
    ; coefficients_comm
    ; generic_comm
    ; psm_comm
    ; complete_add_comm
    ; mul_comm
    ; emul_comm
    ; endomul_scalar_comm
    }
end
