(** Commitment lengths *)

type t =
  ( int Pickles_types.Plonk_types.Columns_vec.t
  , int
  , int )
  Pickles_types.Plonk_types.Messages.Poly.t

(** [of_length len] creates a commitment length [len]

    [len] typically represents the number of chunks.

    @raise Invalid_argument if [len] <= 0
*)
val of_length : int -> t

(** Default commitment length with hard-coded length of [1]. *)
val one : t
