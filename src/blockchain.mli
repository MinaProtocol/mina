open Core_kernel
open Async_kernel

type t =
  { block : Block.t
  ; proof : Proof.t
  }
[@@deriving bin_io]

module Update : sig
  type nonrec t =
    | New_block of t
end

val accumulate
  :  init:t
  -> updates:Update.t Linear_pipe.Reader.t
  -> strongest_block:t Linear_pipe.Writer.t
  -> unit

val valid : t -> bool

val genesis : t

module State : sig
  type ('time, 'target, 'digest, 'number) t_ =
    { difficulty_info : ('time * 'target) list
    ; block_hash      : 'digest
    ; number          : 'number
    }

  type t = (Time.t, Target.t, Snark_params.Main.Pedersen.Digest.t, Block.Body.t) t_

  module Snarkable
    (Impl : Snark_intf.S)
    (Time : Impl.Snarkable.Bits.S)
    (Target : Impl.Snarkable.Bits.S)
    (Digest : Impl.Snarkable.Bits.S)
    (Number : Impl.Snarkable.Bits.S) : sig
    open Impl

    type var = (Time.Unpacked.var, Target.Unpacked.var, Digest.Packed.var, Number.Packed.var) t_
    type value = (Time.Unpacked.value, Target.Unpacked.value, Digest.Packed.value, Number.Packed.value) t_

    val spec : (var, value) Var_spec.t
  end
end
