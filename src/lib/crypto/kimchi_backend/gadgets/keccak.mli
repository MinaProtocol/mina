module Circuit := Kimchi_pasta_snarky_backend.Step_impl

(* Endianness type *)
type endianness = Big | Little

(** Gagdet for NIST SHA-3 function for output lengths 224/256/384/512
 * Input:
 * - Endianness of the input (default is Big). 
 * - Endianness of the output (default is Big).
 * - Flag to enable input byte checks (default is false). Outputs are always constrained.
 * - int representing the output length of the hash function (224|256|384|512)
 * - Arbitrary length list of Cvars representing the input to the hash function where each of them is a byte 
 * Output:
 * - List of `int` Cvars representing the output of the hash function where each of them is a byte
 *)
val nist_sha3 :
     ?inp_endian:endianness
  -> ?out_endian:endianness
  -> ?byte_checks:bool
  -> int
  -> Circuit.Field.t list
  -> Circuit.Field.t list

(** Gadget for Keccak hash function for the parameters used in Ethereum 
 * Input:
 * - Endianness of the input (default is Big). 
 * - Endianness of the output (default is Big).
 * - Flag to enable input byte checks (default is false). Outputs are always constrained.
 * - Arbitrary length list of Cvars representing the input to the hash function where each of them is a byte 
 * Output: 
 * - List of 256 Cvars representing the output of the hash function where each of them is a byte 
 *)
val ethereum :
     ?inp_endian:endianness
  -> ?out_endian:endianness
  -> ?byte_checks:bool
  -> Circuit.Field.t list
  -> Circuit.Field.t list

(*** Gagdet for pre-NIST SHA-3 function for output lengths 224/256/384/512.
 * Note that when calling with output length 256 this is equivalent to the ethereum function 
 * Input:
 * - Endianness of the input (default is Big). 
 * - Endianness of the output (default is Big).
 * - Flag to enable input byte checks (default is false). Outputs are always constrained.
 * - int representing the output length of the hash function (224|256|384|512)
 * - Arbitrary length list of Cvars Cvars representing the input to the hash function where each of them is a byte 
 * Output:
 * - List of `int` Cvars representing the output of the hash function where each of them is a byte
 *)
val pre_nist :
     ?inp_endian:endianness
  -> ?out_endian:endianness
  -> ?byte_checks:bool
  -> int
  -> Circuit.Field.t list
  -> Circuit.Field.t list
