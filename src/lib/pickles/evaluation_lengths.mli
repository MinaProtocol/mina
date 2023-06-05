(* Evaluation lengths *)

type 'a t := 'a Pickles_types.Plonk_types.Evals.t

val create : num_chunks:int -> of_int:(int -> 'a) -> 'a t
