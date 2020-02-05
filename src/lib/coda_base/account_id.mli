open Core_kernel
open Signature_lib

[%%versioned:
module Stable : sig
  module V1 : sig
    type t = private Public_key.Compressed.Stable.V1.t * Token_id.Stable.V1.t
    [@@deriving sexp, compare, hash, yojson]
  end
end]

type t = Stable.Latest.t [@@deriving sexp, compare, hash, yojson]

type var = Public_key.Compressed.var * Token_id.var

val typ : (var, t) Snark_params.Tick.Typ.t

val create : Public_key.Compressed.t -> Token_id.t -> t

include Comparable.S with type t := t

include Hashable.S_binable with type t := t

module Checked : sig
  open Snark_params
  open Tick

  val create : Public_key.Compressed.var -> Token_id.var -> var

  val equal : var -> var -> (Boolean.var, _) Checked.t
end
