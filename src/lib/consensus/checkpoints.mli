open Snark_params.Tick
open Coda_base

type t

type var

module Checked : sig
  type t = var

  val cons : State_hash.var -> t -> (t, _) Checked.t

  val if_ : Boolean.var -> then_:t -> else_:t -> (t, _) Checked.t
end

val typ : (Checked.t, t) Typ.t

val empty : t

val cons : State_hash.t -> t -> t

module Stable : sig
  module V1 : sig
    type nonrec t = t
    [@@deriving sexp, bin_io, hash, version, to_yojson, compare, eq]
  end
end

val max_length : int
