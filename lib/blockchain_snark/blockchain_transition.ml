open Core_kernel
open Async_kernel
open Nanobit_base.Snark_params

module Digest = Tick.Pedersen.Digest

module Keys = struct
  type t =
    { step : Tick.Keypair.t
    ; wrap : Tock.Keypair.t
    }

  module Location = struct
    module T = struct
      type t =
        { step : string
        ; wrap : string
        }
      [@@deriving sexp]
    end
    include T
    include Sexpable.To_stringable(T)
  end

  let checksum ~step ~wrap =
    Md5.digest_string
      ("Blockchain_transition"
        ^ Md5.to_hex step ^ Md5.to_hex wrap)

  let load ({ step; wrap } : Location.t) =
    let open Storage.Disk in
    let parent_log = Logger.create () in
    let tick_controller =
      Controller.create ~parent_log Tick.Keypair.bin_t
    in
    let tock_controller =
      Controller.create ~parent_log Tock.Keypair.bin_t
    in
    let open Async in
    let load c p =
      match%map load_with_checksum c p with
      | Ok x -> x
      | Error e -> failwithf "Transaction_snark: load failed on %s" p ()
    in
    let%map step = load tick_controller step
    and wrap = load tock_controller wrap
    in
    let t =
      { step = step.data
      ; wrap = wrap.data
      }
    in
    (t, checksum ~step:step.checksum ~wrap:wrap.checksum)
end

module Make (T : Transaction_snark.Verification.S) = struct
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
    module Update = Nanobit_base.Block
  end

  open Nanobit_base

  include Transition_system.Make
      (struct
        module Tick = Digest
        module Tock = Bits.Snarkable.Field(Tock)
      end)
      (struct let hash bs = Tick.digest_bits ~init:Hash_prefix.transition_system_snark bs end)
      (System)

  module Keys = struct
    include Keys

    let cached () =
      let open Async in
      let%bind step =
        Cached.create
          ~directory:Cache_dir.cache_dir
          ~bin_t:Tick.Keypair.bin_t
          ~digest_input:(Fn.compose Md5.to_hex Tick.R1CS_constraint_system.digest)
          Tick.R1CS_constraint_system.generate_keypair
          (Tick.constraint_system ~exposing:(Step_base.input ()) Step_base.main)
      in
      let module Wrap = Wrap_base(struct let verification_key = Tick.Keypair.vk step.value end) in
      let%map wrap =
        Cached.create
          ~directory:Cache_dir.cache_dir
          ~bin_t:Tock.Keypair.bin_t
          ~digest_input:(Fn.compose Md5.to_hex Tock.R1CS_constraint_system.digest)
          Tock.R1CS_constraint_system.generate_keypair
          (Tock.constraint_system ~exposing:(Wrap.input ()) Wrap.main)
      in
      let location : Location.t =
        { step = step.path
        ; wrap = wrap.path
        }
      in
      (location, { Keys.step=step.value; wrap=wrap.value }, checksum ~step:step.checksum ~wrap:wrap.checksum)
  end
end
