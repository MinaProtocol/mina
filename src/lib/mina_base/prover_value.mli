open Snark_params.Step

type 'a t

val get : 'a t -> 'a

val create : (unit -> 'a) -> 'a t

val map : 'a t -> f:('a -> 'b) -> 'b t

val if_ : Boolean.var -> then_:'a t -> else_:'a t -> 'a t

val typ : unit -> ('a t, 'a) Typ.t
