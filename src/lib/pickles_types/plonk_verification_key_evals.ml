open Core_kernel
module H_list = Snarky_backendless.H_list

module Optional_columns = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t =
        { range_check0 : 'a
        ; range_check1 : 'a
        ; foreign_field_add : 'a
        ; foreign_field_mul : 'a
        ; xor : 'a
        ; rot : 'a
        ; lookup_gate : 'a
        ; runtime_tables : 'a
        }
      [@@deriving sexp, compare, yojson, hlist, hash, equal, fields]
    end
  end]

  let init v =
    { range_check0 = v
    ; range_check1 = v
    ; foreign_field_mul = v
    ; foreign_field_add = v
    ; xor = v
    ; rot = v
    ; lookup_gate = v
    ; runtime_tables = v
    }

  let map ~f
      { range_check0
      ; range_check1
      ; foreign_field_add
      ; foreign_field_mul
      ; xor
      ; rot
      ; lookup_gate
      ; runtime_tables
      } =
    { range_check0 = f range_check0
    ; range_check1 = f range_check1
    ; foreign_field_add = f foreign_field_add
    ; foreign_field_mul = f foreign_field_mul
    ; xor = f xor
    ; rot = f rot
    ; lookup_gate = f lookup_gate
    ; runtime_tables = f runtime_tables
    }

  let map2 ~f c1 c2 =
    { range_check0 = f c1.range_check0 c2.range_check0
    ; range_check1 = f c1.range_check1 c2.range_check1
    ; foreign_field_add = f c1.foreign_field_add c2.foreign_field_add
    ; foreign_field_mul = f c1.foreign_field_mul c2.foreign_field_mul
    ; xor = f c1.xor c2.xor
    ; rot = f c1.rot c2.rot
    ; lookup_gate = f c1.lookup_gate c2.lookup_gate
    ; runtime_tables = f c1.runtime_tables c2.runtime_tables
    }

  let to_list
      { range_check0
      ; range_check1
      ; foreign_field_add
      ; foreign_field_mul
      ; xor
      ; rot
      ; lookup_gate
      ; runtime_tables
      } =
    [ range_check0
    ; range_check1
    ; foreign_field_add
    ; foreign_field_mul
    ; xor
    ; rot
    ; lookup_gate
    ; runtime_tables
    ]

  (* TODO?: Should we expand feature flags to match the fields of [t] *)
  let typ (type f fp)
      (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
      (fp : (fp, _) Impl.Typ.t) ~dummy (options : Plonk_types.Features.options)
      =
    let opt_typ flag = Opt.typ Impl.Boolean.typ flag fp ~dummy in

    Snarky_backendless.Typ.of_hlistable
      [ opt_typ options.range_check0
      ; opt_typ options.range_check1
      ; opt_typ options.foreign_field_add
      ; opt_typ options.foreign_field_mul
      ; opt_typ options.xor
      ; opt_typ options.rot
      ; opt_typ options.lookup
      ; opt_typ options.runtime_tables
      ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

module Repr = struct
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
end

module Poly = struct
  type ('comm, 'comm_opt) t =
    { sigma_comm : 'comm Plonk_types.Permuts_vec.t
    ; coefficients_comm : 'comm Plonk_types.Columns_vec.t
    ; generic_comm : 'comm
    ; psm_comm : 'comm
    ; complete_add_comm : 'comm
    ; mul_comm : 'comm
    ; emul_comm : 'comm
    ; endomul_scalar_comm : 'comm
    ; optional_columns_comm : 'comm_opt Optional_columns.t
    }
  [@@deriving sexp, equal, compare, hash, yojson, hlist, fields]
end

include Poly

[%%versioned_binable
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    module T = struct
      type 'comm t = ('comm, 'comm option) Poly.t
      [@@deriving sexp, equal, compare, hash, yojson]
    end

    include (Poly : module type of Poly with type ('a, 'b) t := ('a, 'b) Poly.t)

    include T

    let to_repr
        ({ sigma_comm
         ; coefficients_comm
         ; generic_comm
         ; psm_comm
         ; complete_add_comm
         ; mul_comm
         ; emul_comm
         ; endomul_scalar_comm
         ; optional_columns_comm = _optional_columns_comm
         } :
          _ t ) : _ Repr.t =
      (* TODO: Should we assert that the optional columns commitments are all
         None here?
      *)
      { sigma_comm
      ; coefficients_comm
      ; generic_comm
      ; psm_comm
      ; complete_add_comm
      ; mul_comm
      ; emul_comm
      ; endomul_scalar_comm
      }

    let of_repr
        ({ sigma_comm
         ; coefficients_comm
         ; generic_comm
         ; psm_comm
         ; complete_add_comm
         ; mul_comm
         ; emul_comm
         ; endomul_scalar_comm
         } :
          _ Repr.t ) : _ t =
      { sigma_comm
      ; coefficients_comm
      ; generic_comm
      ; psm_comm
      ; complete_add_comm
      ; mul_comm
      ; emul_comm
      ; endomul_scalar_comm
      ; optional_columns_comm = Optional_columns.init None
      }

    include
      Binable.Of_binable1
        (Repr.Stable.V2)
        (struct
          type nonrec 'a t = 'a t

          let to_binable r = to_repr r

          let of_binable r = of_repr r
        end)
  end
end]

type ('a, 'bool) in_circuit = ('a, ('a, 'bool) Opt.t) t

type 'a out_circuit = ('a, 'a Option.t) t

let map
    { sigma_comm
    ; coefficients_comm
    ; generic_comm
    ; psm_comm
    ; complete_add_comm
    ; mul_comm
    ; emul_comm
    ; endomul_scalar_comm
    ; optional_columns_comm
    } ~f ~f_opt =
  { sigma_comm = Vector.map ~f sigma_comm
  ; coefficients_comm = Vector.map ~f coefficients_comm
  ; generic_comm = f generic_comm
  ; psm_comm = f psm_comm
  ; complete_add_comm = f complete_add_comm
  ; mul_comm = f mul_comm
  ; emul_comm = f emul_comm
  ; endomul_scalar_comm = f endomul_scalar_comm
  ; optional_columns_comm = Optional_columns.map ~f:f_opt optional_columns_comm
  }

let in_of_out comms = map ~f:Fn.id ~f_opt:Opt.of_option comms

let out_of_in comms = map ~f:Fn.id ~f_opt:Opt.to_option_unsafe comms

let in_circuit_map comms ~f = map comms ~f ~f_opt:(Opt.map ~f)

let out_circuit_map comms ~f = map comms ~f ~f_opt:(Option.map ~f)

let map2 t1 t2 ~f ~f_opt =
  { sigma_comm = Vector.map2 ~f t1.sigma_comm t2.sigma_comm
  ; coefficients_comm = Vector.map2 ~f t1.coefficients_comm t2.coefficients_comm
  ; generic_comm = f t1.generic_comm t2.generic_comm
  ; psm_comm = f t1.psm_comm t2.psm_comm
  ; complete_add_comm = f t1.complete_add_comm t2.complete_add_comm
  ; mul_comm = f t1.mul_comm t2.mul_comm
  ; emul_comm = f t1.emul_comm t2.emul_comm
  ; endomul_scalar_comm = f t1.endomul_scalar_comm t2.endomul_scalar_comm
  ; optional_columns_comm =
      Optional_columns.map2 ~f:f_opt t1.optional_columns_comm
        t2.optional_columns_comm
  }

let to_kimchi_verification_evals t =
  { Kimchi_types.VerifierIndex.sigma_comm = Vector.to_array t.sigma_comm
  ; coefficients_comm = Vector.to_array t.coefficients_comm
  ; generic_comm = t.generic_comm
  ; mul_comm = t.mul_comm
  ; psm_comm = t.psm_comm
  ; emul_comm = t.emul_comm
  ; complete_add_comm = t.complete_add_comm
  ; endomul_scalar_comm = t.endomul_scalar_comm
  ; xor_comm = t.optional_columns_comm.xor
  ; range_check0_comm = t.optional_columns_comm.range_check0
  ; range_check1_comm = t.optional_columns_comm.range_check1
  ; foreign_field_add_comm = t.optional_columns_comm.foreign_field_add
  ; foreign_field_mul_comm = t.optional_columns_comm.foreign_field_mul
  ; rot_comm = t.optional_columns_comm.rot
  ; lookup_gate_comm = t.optional_columns_comm.lookup_gate
  ; runtime_tables_comm = t.optional_columns_comm.runtime_tables
  }

let opt_typ (type f)
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = f) ~dummy
    (options : Plonk_types.Features.options) g =
  Snarky_backendless.Typ.of_hlistable
    [ Vector.typ g Plonk_types.Permuts.n
    ; Vector.typ g Plonk_types.Columns.n
    ; g
    ; g
    ; g
    ; g
    ; g
    ; g
    ; Optional_columns.typ (module Impl) ~dummy g options
    ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist

let typ = opt_typ
