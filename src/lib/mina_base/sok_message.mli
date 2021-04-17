open Core
open Snark_params
open Tick
open Import

[%%versioned:
module Stable : sig
  module V1 : sig
    type t =
      {fee: Currency.Fee.Stable.V1.t; prover: Public_key.Compressed.Stable.V1.t}
    [@@deriving sexp, yojson, eq, compare]
  end
end]

val create : fee:Currency.Fee.t -> prover:Public_key.Compressed.t -> t

module Digest : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t [@@deriving sexp, hash, compare, eq, yojson]
    end
  end]

  module Checked : sig
    type t

    val to_input : t -> (_, Boolean.var) Random_oracle.Input.t
  end

  val to_input : t -> (_, bool) Random_oracle.Input.t

  val typ : (Checked.t, t) Typ.t

  val default : t
end

val digest : t -> Digest.t
