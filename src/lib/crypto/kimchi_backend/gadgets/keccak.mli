(* Gagdet for NIST SHA-3 function for output lengths 224/256/384/512 *)
val nist_sha3 :
    (module Snarky_backendless.Snark_intf.Run with type field = 'f) 
    -> int
    -> 'f Snarky_backendless.Cvar.t list
    -> 'f Snarky_backendless.Cvar.t array
    
(* Gadget for Keccak hash function for the parameters used in Ethereum *)
val eth_keccak :
    (module Snarky_backendless.Snark_intf.Run with type field = 'f) 
    -> 'f Snarky_backendless.Cvar.t list
    -> 'f Snarky_backendless.Cvar.t array

