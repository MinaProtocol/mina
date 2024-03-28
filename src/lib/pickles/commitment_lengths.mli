(* Commitment_lengths *)

(** [create] *)
val create :
     of_int:(int -> 'a)
  -> ( 'a Pickles_types.Plonk_types.Columns_vec.t
     , 'a
     , 'a )
     Pickles_types.Plonk_types.Messages.Poly.t
