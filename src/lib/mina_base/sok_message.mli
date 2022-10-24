open Core_kernel
open Snark_params
open Step
open Mina_base_import

[@@@warning "-32"]

[%%versioned:
module Stable : sig
  module V1 : sig
    type t =
      { fee : Currency.Fee.Stable.V1.t
      ; prover : Public_key.Compressed.Stable.V1.t
      }
    [@@deriving sexp, yojson, equal, compare]
  end
end]

[@@@warning "+32"]

type t = Stable.Latest.t =
  { fee : Currency.Fee.Stable.V1.t; prover : Public_key.Compressed.Stable.V1.t }
[@@deriving sexp, yojson, equal, compare]

val create : fee:Currency.Fee.t -> prover:Public_key.Compressed.t -> t

module Digest : sig
  type t [@@deriving sexp, equal, yojson, hash, compare]

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving sexp, bin_io, hash, compare, equal, yojson, version]
    end

    module Latest = V1
  end

  module Checked : sig
    type t

    val to_input : t -> Field.Var.t Random_oracle.Input.Chunked.t
  end

  val to_input : t -> Field.t Random_oracle.Input.Chunked.t

  val typ : (Checked.t, t) Typ.t

  val default : t
end

val digest : t -> Digest.t
