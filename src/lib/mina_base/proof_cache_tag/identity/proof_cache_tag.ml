open Core_kernel

module Cache = struct

  type t = unit

  let initialize _path = ()

end


type t = Pickles.Proof.Proofs_verified_2.t
[@@deriving compare, equal, sexp, yojson, hash]

let unwrap t _db = Fn.id t 

let generate t _db = Fn.id t

module For_tests = struct 
  
  let random = Cache.initialize

end