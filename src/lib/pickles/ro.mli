type bits := bool list

val bits_random_oracle : length:int -> String.t -> bits

val ro : string -> int -> (bits -> 'a) -> unit -> 'a

val tock : unit -> Backend.Tock.Field.t

val tick : unit -> Backend.Tick.Field.t

val scalar_chal :
  unit -> int64 Pickles_types.Vector.vec2 Import.Scalar_challenge.t

val chal : unit -> int64 Pickles_types.Vector.vec2
