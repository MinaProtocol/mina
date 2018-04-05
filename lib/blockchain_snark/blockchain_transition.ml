open Core_kernel
open Async_kernel
open Nanobit_base
open Snark_params

module Digest = Tick.Pedersen.Digest

module Make (T : Transaction_snark.S) = struct
  module System = struct
    module U = Blockchain_state.Make_update(T)
    module State = struct
      include (Blockchain_state : module type of Blockchain_state with module Checked := Blockchain_state.Checked)
      include (U : module type of U with module Checked := U.Checked)
      module Checked = struct
        include Blockchain_state.Checked
        include U.Checked
      end
    end
    module Update = Block
  end

  include Transition_system.Make
      (struct
        module Tick = Digest
        module Tock = Bits.Snarkable.Field(Tock)
      end)
      (struct let hash = Tick.hash_digest end)
      (System)
end
