(** This module provides functions to keep track of the number of commitments
    the proving system requires for each type of polynomials.

    Refer to the {{ https://eprint.iacr.org/2019/953.pdf } PlonK paper } for a basic
    understanding of the different polynomials involved in a proof.
*)

(** [create ~of_int] returns a tuple of naturals [(length_w, length_z, length_t)]
    encoding at the type level the number of polynomials we must commit to.
    - [length_w] is the number of wires. It must be in line with
      {Plonk_types.Commons}.
    - [length_z] is the permutation polynomial
    - [length_t] is the quotient polynomial

    Encoding the size at the type level allows to check at compile time the
    length of vectors, and avoid runtime checks.
*)
val create :
     of_int:(int -> 'a)
  -> ( 'a Pickles_types.Plonk_types.Columns_vec.t
     , 'a
     , 'a )
     Pickles_types.Plonk_types.Messages.Poly.t
