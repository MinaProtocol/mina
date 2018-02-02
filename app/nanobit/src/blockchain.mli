open Core_kernel
open Async_kernel
open Nanobit_base
open Snark_params

module State : sig
  open Tick

  type ('time, 'target, 'digest, 'number, 'strength) t_ =
    { difficulty_info : ('time * 'target) list
    ; block_hash      : 'digest
    ; number          : 'number
    ; strength        : 'strength
    }
  [@@deriving bin_io]

  type t =
    ( Block_time.t
    , Target.t
    , Pedersen.Digest.t
    , Block.Body.t
    , Strength.t
    ) t_

  include Snarkable.S
    with
      type var =
        ( Block_time.Unpacked.var
        , Target.Unpacked.var
        , Pedersen.Digest.Packed.var
        , Block.Body.Packed.var
        , Strength.Packed.var
        ) t_
      and type value =
        ( Block_time.Unpacked.value
        , Target.Unpacked.value
        , Pedersen.Digest.Packed.value
        , Block.Body.Packed.value
        , Strength.Packed.value
        ) t_

  val update_exn : value -> Block.t -> value

  val hash : value -> Pedersen.Digest.t

  val negative_one : value
  val zero : value
  val zero_hash : Pedersen.Digest.t

  module Checked : sig
    val hash : var -> (Pedersen.Digest.Packed.var, _) Checked.t
    val is_base_hash : Pedersen.Digest.Packed.var -> (Boolean.var, _) Checked.t

    val update : var -> Block.Packed.var -> (var * [ `Success of Boolean.var ], _) Checked.t
  end

  val compute_target : t -> Target.t
end

type t =
  { state : State.t
  ; proof : Proof.t
  }
[@@deriving bin_io]

module Update : sig
  type nonrec t =
    | New_chain of t
end

val accumulate
  :  init:t
  -> updates:Update.t Linear_pipe.Reader.t
  -> strongest_chain:t Linear_pipe.Writer.t
  -> unit

val valid : t -> bool

(*
val genesis : t

val extend_exn : t -> Block.t -> t *)

