(* Evaluation lengths *)

(** [create] *)
val create : of_int:(int -> 'a) -> 'a Pickles_types.Plonk_types.Evals.t

(** [constants] *)
val constants : int Pickles_types.Plonk_types.Evals.t
