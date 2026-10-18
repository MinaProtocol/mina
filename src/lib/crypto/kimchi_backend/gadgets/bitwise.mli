module Circuit := Kimchi_pasta_snarky_backend.Step_impl

(** Side of rotation. *)
type rot_mode = Left | Right

(** 64-bit rotation of [rot_bits] to the [mode] side.

    @param check64 whether to check the input word is at most 64 bits
                   (default is false)
    @param word word of maximum 64 bits to be rotated
    @param bits number of bits to be rotated
    @param mode Left or Right
    @return rotated word *)
val rot64 :
     ?check64:bool (* false *)
  -> Circuit.Field.t
  -> int
  -> rot_mode
  -> Circuit.Field.t

(** 64-bit bitwise logical shift of bits to the left side.

    @param check64 whether to check the input word is at most 64 bits
                   (default is false)
    @param word word of maximum 64 bits to be shifted
    @param bits number of bits to be shifted
    @return left shifted word (with 0s at the least significant positions) *)
val lsl64 :
  ?check64:bool (* false *) -> Circuit.Field.t -> int -> Circuit.Field.t

(** 64-bit bitwise logical shift of bits to the right side.

    @param check64 whether to check the input word is at most 64 bits
                   (default is false)
    @param word word of maximum 64 bits to be shifted
    @param bits number of bits to be shifted
    @return right shifted word (with 0s at the most significant positions) *)
val lsr64 :
  ?check64:bool (* false *) -> Circuit.Field.t -> int -> Circuit.Field.t

(** Boolean XOR of [length] bits.

    @param len_xor number of bits of the lookup table (default is 4)
    @param input1 first input to the XOR gate
    @param input2 second input to the XOR gate
    @param length number of bits to XOR
    @return XOR of input1 and input2 *)
val bxor :
  ?len_xor:int -> Circuit.Field.t -> Circuit.Field.t -> int -> Circuit.Field.t

(** Boolean XOR of 16 bits. This is a special case of XOR for 16 bits using a
    4-bit lookup table. Receives two input words of maximum 16 bits each.
    Returns the XOR of the two words. *)
val bxor16 : Circuit.Field.t -> Circuit.Field.t -> Circuit.Field.t

(** Boolean XOR of 64 bits. This is a special case of XOR for 64 bits using a
    4-bit lookup table. Receives two input words of maximum 64 bits each.
    Returns the XOR of the two words. *)
val bxor64 : Circuit.Field.t -> Circuit.Field.t -> Circuit.Field.t

(** Boolean AND of [length] bits.

    @param len_xor number of bits of the XOR lookup table (default is 4)
    @param input1 first input to AND
    @param input2 second input to AND
    @param length number of bits to AND
    @return AND of input1 and input2 *)
val band :
  ?len_xor:int -> Circuit.Field.t -> Circuit.Field.t -> int -> Circuit.Field.t

(** Boolean AND of 64 bits. This is a special case of AND for 64 bits using a
    4-bit XOR lookup table. Receives two input words of maximum 64 bits each.
    Returns the AND of the two words. *)
val band64 : Circuit.Field.t -> Circuit.Field.t -> Circuit.Field.t

(** Boolean NOT of [length] bits with checked length (uses XOR gadgets inside
    to constrain the length).

    Note: the length must be less than the bit length of the field.

    @param len_xor length of the XOR lookup table to use (default 4)
    @param input word to negate
    @param length number of bits
    @return negated word *)
val bnot_checked : ?len_xor:int -> Circuit.Field.t -> int -> Circuit.Field.t

(** Negates a word of 64 bits with checked length of 64 bits. This means that
    the bound in length is constrained in the circuit. *)
val bnot64_checked : Circuit.Field.t -> Circuit.Field.t

(** Boolean NOT of [length] bits with unchecked length (uses Generic
    subtractions inside).

    Note: this can negate two words per row, but inputs need to be a copy of
    another variable with a correct length in order to ensure the length is
    correct. The length must be less than the bit length of the field.

    @param input word to negate
    @param length number of bits
    @return negated word *)
val bnot_unchecked : Circuit.Field.t -> int -> Circuit.Field.t

(** Negates a word of 64 bits, but its length goes unconstrained in the circuit
    (unless it is copied from a checked length value). *)
val bnot64_unchecked : Circuit.Field.t -> Circuit.Field.t
