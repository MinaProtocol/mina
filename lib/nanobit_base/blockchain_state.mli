open Core_kernel
open Snark_params
open Tick

type ('time, 'target, 'digest, 'number, 'strength) t_ =
  { previous_time : 'time
  ; target        : 'target
  ; block_hash    : 'digest
  ; number        : 'number
  ; strength      : 'strength
  }

type t =
  ( Block_time.t
  , Target.t
  , Pedersen.Digest.t
  , Block.Body.t
  , Strength.t
  ) t_
[@@deriving sexp]

module Stable : sig
  module V1 : sig
    type nonrec ('a, 'b, 'c, 'd, 'e) t_ = ('a, 'b, 'c, 'd, 'e) t_ =
      { previous_time : 'a
      ; target        : 'b
      ; block_hash    : 'c
      ; number        : 'd
      ; strength      : 'e
      }
    [@@deriving bin_io, sexp]

    type nonrec t =
      ( Block_time.Stable.V1.t
      , Target.Stable.V1.t
      , Pedersen.Digest.t
      , Block.Body.Stable.V1.t
      , Strength.Stable.V1.t
      ) t_
    [@@deriving bin_io, sexp]
  end
end

include Snarkable.S
  with
    type var =
      ( Block_time.Unpacked.var
      , Target.Unpacked.var
      , Pedersen.Digest.Unpacked.var
      , Block.Body.Unpacked.var
      , Strength.Unpacked.var
      ) t_
    and type value =
      ( Block_time.Unpacked.value
      , Target.Unpacked.value
      , Pedersen.Digest.Unpacked.value
      , Block.Body.Unpacked.value
      , Strength.Unpacked.value
      ) t_

val update_exn : value -> Block.t -> value

val hash : value -> Pedersen.Digest.t

val negative_one : value
val zero : value
val zero_hash : Pedersen.Digest.t

module Checked : sig
  val hash : var -> (Pedersen.Digest.Packed.var, _) Checked.t
  val is_base_hash : Pedersen.Digest.Packed.var -> (Boolean.var, _) Checked.t

  val update : var -> Block.var -> (var * [ `Success of Boolean.var ], _) Checked.t
end

val compute_target : Block_time.t -> Target.t -> Block_time.t -> Target.t

