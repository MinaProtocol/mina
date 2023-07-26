type bits := bool list

val bits_random_oracle : length:int -> String.t -> bits

val ro : string -> int -> (bits -> 'a) -> unit -> 'a

val tock : unit -> Backend.Tock.Field.t

val tick : unit -> Backend.Tick.Field.t

val scalar_chal :
     unit
  -> (Core_kernel.Int64.t, Pickles_types.Nat.N2.n) Pickles_types.Vector.t
     Import.Scalar_challenge.t

val chal :
  unit -> (Core_kernel.Int64.t, Pickles_types.Nat.N2.n) Pickles_types.Vector.t
