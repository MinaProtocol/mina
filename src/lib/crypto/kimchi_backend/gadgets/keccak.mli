(* Gadget for SHA-3 hash function with output length of 224 bits *)
val sha3_224 :
(module Snarky_backendless.Snark_intf.Run with type field = 'f) 
-> 'f Snarky_backendless.Cvar.t list
-> 'f Snarky_backendless.Cvar.t array


(* Gadget for SHA-3 hash function with output length of 256 bits *)
val sha3_256 :
    (module Snarky_backendless.Snark_intf.Run with type field = 'f) 
    -> 'f Snarky_backendless.Cvar.t list
    -> 'f Snarky_backendless.Cvar.t array

(* Gadget for SHA-3 hash function with output length of 384 bits *)
val sha3_384 :
(module Snarky_backendless.Snark_intf.Run with type field = 'f) 
-> 'f Snarky_backendless.Cvar.t list
-> 'f Snarky_backendless.Cvar.t array

(* Gadget for SHA-3 hash function with output length of 512 bits *)
val sha3_512 :
    (module Snarky_backendless.Snark_intf.Run with type field = 'f) 
    -> 'f Snarky_backendless.Cvar.t list
    -> 'f Snarky_backendless.Cvar.t array

(* Gadget for Keccak hash function for the parameters used in Ethereum *)
val ethereum_hash :
    (module Snarky_backendless.Snark_intf.Run with type field = 'f) 
    -> 'f Snarky_backendless.Cvar.t list
    -> 'f Snarky_backendless.Cvar.t array
