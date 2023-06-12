(** Implements an interface simulating a {{ https://en.wikipedia.org/wiki/Random_oracle } random oracle } *)

(** Bits alias *)
type bits := bool list

(** [bits_random_orable ~length seed] generates a list of [length] bits using
    the seed [seed]. Blake2s is used *)
val bits_random_oracle : length:int -> String.t -> bits

(** [ro seed length f] generates a sequence of [length] bits using a random
    oracle seeded with [seed] and converts it into a value of type ['a] using the
    function [f] *)
val ro : string -> int -> (bits -> 'a) -> unit -> 'a

(** Random oracle generating elements in the field Tock *)
val tock : unit -> Backend.Tock.Field.t

(** Random oracle generating elements in the field Tick *)
val tick : unit -> Backend.Tick.Field.t

val scalar_chal :
     unit
  -> (Core_kernel.Int64.t, Pickles_types.Nat.N2.n) Pickles_types.Vector.t
     Import.Scalar_challenge.t

val chal :
  unit -> (Core_kernel.Int64.t, Pickles_types.Nat.N2.n) Pickles_types.Vector.t
