open Snark_params.Tick

type t

val (+)      : t -> t -> t
val (-)      : t -> t -> t
val ( * )    : t -> t -> (t, _) Checked.t
val constant : Field.t -> t

val (<) : t -> t -> (Boolean.var, _) Checked.t

val to_var : t -> Cvar.t

val of_bits : Boolean.var list -> t
val to_bits : t -> (Boolean.var list, _) Checked.t

val clamp_to_n_bits : t -> int -> (t, _) Checked.t
