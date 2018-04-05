open Core_kernel
open Async_kernel
open Nanobit_base
open Snark_params

module Digest = Tick.Pedersen.Digest

module Make (T : Transaction_snark.S) = struct
  module System = struct
    module U = Blockchain_state.Make_update(T)
    module State = struct
      type var = Blockchain_state.var
      type value = Blockchain_state.value
      let typ = Blockchain_state.typ
      let hash = Blockchain_state.hash
      let update_exn = U.update_exn
      module Checked = struct
        include Blockchain_state.Checked
        let update = U.update_var
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
