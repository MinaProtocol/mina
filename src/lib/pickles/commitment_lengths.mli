(* Commitment_lengths *)

(** [create ~num_chunks] generate a commitment length tailored to [num_chunks] *)
val create :
     num_chunks:int
  -> ( int Pickles_types.Plonk_types.Columns_vec.t
     , int
     , int )
     Pickles_types.Plonk_types.Messages.Poly.t
