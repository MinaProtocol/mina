open Snark_params
open Tuple_lib
open Tick

type 'f t_ = ('f, 'f Triple.t) Verifier.Verification_key.Compressed.t_

type t = Field.Var.t t_

module Unchecked : sig
  type t = Field.t t_

  val of_backend_vk : Tock.Verification_key.t -> t
end

open Run

val to_bits :
  unpack_field:('f -> length:int -> 'bool list) -> 'f t_ -> 'bool list

val typ : (t, Unchecked.t) Typ.t
