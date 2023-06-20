(** Gagdet for NIST SHA-3 function for output lengths 224/256/384/512 
 * Input:
 * - int representing the output length of the hash function (224|256|384|512)
 * - List of Cvars representing the input to the hash function where each of them is a byte 
 * Output:
 * - Array of `int` Cvars representing the output of the hash function where each of them is a byte
 *)
val nist_sha3 :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> int
  -> 'f Snarky_backendless.Cvar.t list
  -> 'f Snarky_backendless.Cvar.t array

(** Gadget for Keccak hash function for the parameters used in Ethereum 
 * Input:
 * - List of Cvars representing the input to the hash function where each of them is a byte 
 * Output: 
 * - Array of 256 Cvars representing the output of the hash function where each of them is a byte 
 *)
val eth_keccak :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t list
  -> 'f Snarky_backendless.Cvar.t array
