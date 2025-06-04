(** This module provides functions to keep track of the evaluations of the
    different polynomials involved in the polynomial IOP scheme.

    Refer to the {{ https://eprint.iacr.org/2019/953.pdf } PlonK paper } for a
    basic understanding of the different polynomials involved in a proof.
*)

(** Versioned types for the evaluations. It is parametrized by the field the
    evaluations happen in.

    For the different versions, refer to the module
    {!module:Pickles_types.Plonk_types.Evals}. When a new custom gate is added, the
    corresponding selectors must be added.

    As for the return type of {!Commitment_lengths.create}, an encoding of the
    vector size is provided at the type level.
 *)
type 'a t := 'a Pickles_types.Plonk_types.Evals.t

(** [default] is a value of type [int t].

    Its field values are set to [1] when they are non-optional, contains only
    [1]-values when they are containers (like {!type:Pickles_types.Vector.t})
    and are set to {!Option.None} when optional. *)
val default : int t
