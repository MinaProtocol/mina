open Core_kernel
module H_list = Snarky_backendless.H_list

[%%versioned
module Stable = struct
  module V2 = struct
    type 'comms t =
      { sigma_comms : 'comms Plonk_types.Permuts_vec.Stable.V1.t
      ; coefficients_comms : 'comms Plonk_types.Columns_vec.Stable.V1.t
      ; generic_comms : 'comms
      ; psm_comms : 'comms
      ; complete_add_comms : 'comms
      ; mul_comms : 'comms
      ; emul_comms : 'comms
      ; endomul_scalar_comms : 'comms
      }
    [@@deriving sexp, equal, compare, hash, yojson, hlist, fields]
    (* TODO: Remove unused annotations *)
  end
end]

(* Internal map function *)
let map
    { sigma_comms
    ; coefficients_comms
    ; generic_comms
    ; psm_comms
    ; complete_add_comms
    ; mul_comms
    ; emul_comms
    ; endomul_scalar_comms
    } ~f =
  { sigma_comms = Vector.map ~f sigma_comms
  ; coefficients_comms = Vector.map ~f coefficients_comms
  ; generic_comms = f generic_comms
  ; psm_comms = f psm_comms
  ; complete_add_comms = f complete_add_comms
  ; mul_comms = f mul_comms
  ; emul_comms = f emul_comms
  ; endomul_scalar_comms = f endomul_scalar_comms
  }

let map2 t1 t2 ~f =
  { sigma_comms = Vector.map2 ~f t1.sigma_comms t2.sigma_comms
  ; coefficients_comms =
      Vector.map2 ~f t1.coefficients_comms t2.coefficients_comms
  ; generic_comms = f t1.generic_comms t2.generic_comms
  ; psm_comms = f t1.psm_comms t2.psm_comms
  ; complete_add_comms = f t1.complete_add_comms t2.complete_add_comms
  ; mul_comms = f t1.mul_comms t2.mul_comms
  ; emul_comms = f t1.emul_comms t2.emul_comms
  ; endomul_scalar_comms = f t1.endomul_scalar_comms t2.endomul_scalar_comms
  }

let dummy g =
  { sigma_comms = Vector.init Plonk_types.Permuts.n ~f:(fun _ -> g)
  ; coefficients_comms = Vector.init Plonk_types.Columns.n ~f:(fun _ -> g)
  ; generic_comms = g
  ; psm_comms = g
  ; complete_add_comms = g
  ; mul_comms = g
  ; emul_comms = g
  ; endomul_scalar_comms = g
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

let chunk = map ~f:(fun x -> [| x |])

module Chunked = struct
  type nonrec 'a t = 'a array t

  let map a ~f = map ~f:(Array.map ~f) a

  let map2 t1 t2 ~f = map2 ~f:(Array.map2_exn ~f) t1 t2

  let typ ~length g = typ (Snarky_backendless.Typ.array ~length g)

  let dummy g = chunk (dummy g)
end
