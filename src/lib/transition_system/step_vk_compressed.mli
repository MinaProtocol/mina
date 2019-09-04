open Snark_params
open Tuple_lib

type 'f t_ = ('f, 'f Double.t) Tock.Verifier.Verification_key.Compressed.t_

type t = Tick.Boolean.var list t_

val to_scalars : 'a list t_ -> 'a Bitstring_lib.Bitstring.Lsb_first.t list

module Unchecked : sig
  type t = Tock.Field.t t_

  val of_backend_vk : Tick.Verification_key.t -> t
end

val to_bits :
  unpack_field:('f -> length:int -> 'bool list) -> 'f t_ -> 'bool list

val typ : (t, Unchecked.t) Tick.Typ.t
