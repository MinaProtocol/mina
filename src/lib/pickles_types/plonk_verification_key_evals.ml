open Core_kernel
module H_list = Snarky_backendless.H_list

[%%versioned
module Stable = struct
  module V1 = struct
    type ('comm, 'fp) t =
      { sigma_comm_0: 'comm
      ; sigma_comm_1: 'comm
      ; sigma_comm_2: 'comm
      ; ql_comm: 'comm
      ; qr_comm: 'comm
      ; qo_comm: 'comm
      ; qm_comm: 'comm
      ; qc_comm: 'comm
      ; rcm_comm_0: 'comm
      ; rcm_comm_1: 'comm
      ; rcm_comm_2: 'comm
      ; psm_comm: 'comm
      ; add_comm: 'comm
      ; mul1_comm: 'comm
      ; mul2_comm: 'comm
      ; emul1_comm: 'comm
      ; emul2_comm: 'comm
      ; emul3_comm: 'comm
      ; r: 'fp
      ; o: 'fp }
    [@@deriving sexp, eq, compare, hash, yojson, hlist, fields]
  end
end]

let typ g f =
  Snarky_backendless.Typ.of_hlistable
    [g; g; g; g; g; g; g; g; g; g; g; g; g; g; g; g; g; g; f; f]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist
