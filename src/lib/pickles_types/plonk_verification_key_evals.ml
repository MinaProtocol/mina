open Core_kernel
module H_list = Snarky_backendless.H_list

[%%versioned
module Stable = struct
  module V1 = struct
    type ('comm) t =
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
      ; emul3_comm: 'comm }
    [@@deriving sexp, eq, compare, hash, yojson, hlist, fields]
  end
end]

    let map 
      { sigma_comm_0 
      ; sigma_comm_1 
      ; sigma_comm_2 
      ; ql_comm      
      ; qr_comm      
      ; qo_comm      
      ; qm_comm      
      ; qc_comm      
      ; rcm_comm_0   
      ; rcm_comm_1   
      ; rcm_comm_2   
      ; psm_comm     
      ; add_comm     
      ; mul1_comm    
      ; mul2_comm    
      ; emul1_comm   
      ; emul2_comm   
      ; emul3_comm   
      } ~f =
      { sigma_comm_0 = f sigma_comm_0 
      ; sigma_comm_1 = f sigma_comm_1 
      ; sigma_comm_2 = f sigma_comm_2 
      ; ql_comm      = f ql_comm      
      ; qr_comm      = f qr_comm      
      ; qo_comm      = f qo_comm      
      ; qm_comm      = f qm_comm      
      ; qc_comm      = f qc_comm      
      ; rcm_comm_0   = f rcm_comm_0   
      ; rcm_comm_1   = f rcm_comm_1   
      ; rcm_comm_2   = f rcm_comm_2   
      ; psm_comm     = f psm_comm     
      ; add_comm     = f add_comm     
      ; mul1_comm    = f mul1_comm    
      ; mul2_comm    = f mul2_comm    
      ; emul1_comm   = f emul1_comm   
      ; emul2_comm   = f emul2_comm   
      ; emul3_comm   = f emul3_comm   
      }


let typ g =
  Snarky_backendless.Typ.of_hlistable
    [g; g; g; g; g; g; g; g; g; g; g; g; g; g; g; g; g; g]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist
