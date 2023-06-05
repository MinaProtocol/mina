(* Commitment_lengths *)

(** [create] *)
val create :
     num_chunks:int
  -> of_int:(int -> 'a)
  -> ( 'a Pickles_types.Plonk_types.Columns_vec.t
     , 'a
     , 'a )
     Pickles_types.Plonk_types.Messages.Poly.t
