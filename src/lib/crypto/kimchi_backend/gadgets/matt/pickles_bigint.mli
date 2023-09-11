module B = Bigint

module Make (Impl : Snarky_backendless.Snark_intf.Run) : sig
  open Impl
  module Bigint = B

  type t = Bigint.t

  type as_limbs

  val to_limbs : t -> as_limbs

  module Circuit : sig
    type t

    val add_unsafe : modulus:as_limbs -> sign:bool -> t -> t -> t

    val range_check : t -> unit
  end

  val typ : (Circuit.t, t) Typ.t
end
