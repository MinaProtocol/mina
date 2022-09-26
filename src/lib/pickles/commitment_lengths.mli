(* Commitment_lengths *)

type 'a t :=
  ( ( 'a
    , Pickles_types.Nat.z Pickles_types.Plonk_types.Columns.plus_n )
    Pickles_types.Vector.t
  , 'a
  , 'a )
  Pickles_types.Plonk_types.Messages.Poly.t

(** Constant [commitment_lengths] used throughout the code *)
val commitment_lengths : int t

(** *)
val create : of_int:(int -> 'a) -> 'a t
