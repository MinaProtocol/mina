open Core_kernel
open Async_kernel
open Snark_params

module Digest = Tick.Pedersen.Digest

module System = struct
  module State = Blockchain_state
  module Update = Block.Packed
end

include Transition_system.Make
    (struct
      module Tick = Digest
      module Tock = Bits.Snarkable.Field(Tock)
    end)
    (struct let hash = Tick.hash_digest end)
    (System)

