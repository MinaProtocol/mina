(* Side of rotation *)
type rot_mode = Left | Right

(** 64-bit rotation of rot_bits to the `mode` side
   *  - word of maximum 64 bits to be rotated
   * - rot_bits: number of bits to be rotated
   * - mode: Left or Right
   * Returns rotated word
*)
val rot_64 :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t
  -> int
  -> rot_mode
  -> 'f Snarky_backendless.Cvar.t

(** Boolean Xor of length bits 
 * input1 and input2 are the inputs to the Xor gate
 * length is the number of bits to Xor
 * len_xor is the number of bits of the lookup table (default is 4)
 *)
val bxor :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> ?len_xor:int
  -> 'f Snarky_backendless.Cvar.t
  -> 'f Snarky_backendless.Cvar.t
  -> int
  -> 'f Snarky_backendless.Cvar.t

(** Boolean Xor of 16 bits
   * This is a special case of Xor for 16 bits for Xor lookup table of 4 bits of inputs.
   * Receives two input words to Xor together, of maximum 16 bits each.
   * Returns the Xor of the two words.
*)
val bxor16 :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t
  -> 'f Snarky_backendless.Cvar.t
  -> 'f Snarky_backendless.Cvar.t

(** Boolean Xor of 64 bits
 * This is a special case of Xor for 64 bits for Xor lookup table of 4 bits of inputs.   * Receives two input words to Xor together, of maximum 64 bits each.
 * Returns the Xor of the two words.
*)
val bxor64 :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t
  -> 'f Snarky_backendless.Cvar.t
  -> 'f Snarky_backendless.Cvar.t

(** Boolean And of length bits
   *  input1 and input2 are the two inputs to AND
   *  length is the number of bits to AND
   *  len_xor is the number of bits of the inputs of the Xor lookup table (default is 4)
*)
val band :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> ?len_xor:int
  -> 'f Snarky_backendless.Cvar.t
  -> 'f Snarky_backendless.Cvar.t
  -> int
  -> 'f Snarky_backendless.Cvar.t

(** Boolean And of 64 bits 
 * This is a special case of And for 64 bits for Xor lookup table of 4 bits of inputs.
 * Receives two input words to And together, of maximum 64 bits each.
 * Returns the And of the two words.   
 *)
val band64 :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t
  -> 'f Snarky_backendless.Cvar.t
  -> 'f Snarky_backendless.Cvar.t

(** Boolean Not of length bits for checked length (uses Xor gadgets inside to constrain the length)
    *   - input of word to negate
    *   - length of word to negate
    *   - len_xor is the length of the Xor lookup table to use beneath (default 4)
    * Note that the length needs to be less than the bit length of the field.
    *)
val bnot_checked :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> ?len_xor:int
  -> 'f Snarky_backendless.Cvar.t
  -> int
  -> 'f Snarky_backendless.Cvar.t

(** Negates a word of 64 bits with checked length of 64 bits.
   * This means that the bound in lenght is constrained in the circuit. *)
val bnot64_checked :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t
  -> 'f Snarky_backendless.Cvar.t

(** Boolean Not of length bits for unchecked length (uses Generic subtractions inside) 
 *  - input of word to negate
 *  - length of word to negate
 * (Note that this can negate two words per row, but it inputs need to be a copy of another
 variable with a correct length in order to make sure that the length is correct )   
 * Note that the length needs to be less than the bit length of the field.
 *)
val bnot_unchecked :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t
  -> int
  -> 'f Snarky_backendless.Cvar.t

(** Negates a word of 64 bits, but its length goes unconstrained in the circuit
   (unless it is copied from a checked length value) *)
val bnot64_unchecked :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t
  -> 'f Snarky_backendless.Cvar.t
