open Core_kernel
open Nanobit_base
open Snark_params
open Tick

type ('time, 'target, 'digest, 'ledger_hash, 'strength) t_ =
  { previous_time : 'time
  ; target        : 'target
  ; block_hash    : 'digest
  ; ledger_hash   : 'ledger_hash
  ; strength      : 'strength
  }

type t =
  ( Block_time.t
  , Target.t
  , Pedersen.Digest.t
  , Ledger_hash.t
  , Strength.t
  ) t_
[@@deriving sexp]

module Stable : sig
  module V1 : sig
    type nonrec ('a, 'b, 'c, 'd, 'e) t_ = ('a, 'b, 'c, 'd, 'e) t_ =
      { previous_time : 'a
      ; target        : 'b
      ; block_hash    : 'c
      ; ledger_hash   : 'd
      ; strength      : 'e
      }
    [@@deriving bin_io, sexp]

    type nonrec t =
      ( Block_time.Stable.V1.t
      , Target.Stable.V1.t
      , Pedersen.Digest.t
      , Ledger_hash.Stable.V1.t
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
      , Ledger_hash.var
      , Strength.Unpacked.var
      ) t_
    and type value =
      ( Block_time.Unpacked.value
      , Target.Unpacked.value
      , Pedersen.Digest.Unpacked.value
      , Ledger_hash.t
      , Strength.Unpacked.value
      ) t_

val hash : value -> Pedersen.Digest.t

val negative_one : value
val zero : value
val zero_hash : Pedersen.Digest.t
val compute_target : Block_time.t -> Target.t -> Block_time.t -> Target.t

module Make_update (T : Transaction_snark.S) : sig
  val update_exn : value -> Block.t -> value

  module Checked : sig
    val update : var -> Block.var -> (var * [ `Success of Boolean.var ], _) Checked.t
  end
end

module Checked : sig
  val hash : var -> (Pedersen.Digest.Packed.var, _) Checked.t
  val is_base_hash : Pedersen.Digest.Packed.var -> (Boolean.var, _) Checked.t
end

