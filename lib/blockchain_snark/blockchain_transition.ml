open Core_kernel
open Async_kernel
open Nanobit_base.Snark_params
module Digest = Tick.Pedersen.Digest

module Keys = struct
  module Per_curve_location = struct
    module T = struct
      type t = {step: string; wrap: string} [@@deriving sexp]
    end

    include T
    include Sexpable.To_stringable (T)
  end

  module Proving = struct
    module Location = Per_curve_location

    let checksum ~step ~wrap =
      Md5.digest_string
        ("Blockchain_transition_proving" ^ Md5.to_hex step ^ Md5.to_hex wrap)

    type t = {step: Tick.Proving_key.t; wrap: Tock.Proving_key.t}

    let dummy =
      {step= Dummy_values.Tick.proving_key; wrap= Dummy_values.Tock.proving_key}

    let load ({step; wrap}: Location.t) =
      let open Storage.Disk in
      let parent_log = Logger.create () in
      let tick_controller =
        Controller.create ~parent_log Tick.Proving_key.bin_t
      in
      let tock_controller =
        Controller.create ~parent_log Tock.Proving_key.bin_t
      in
      let open Async in
      let load c p =
        match%map load_with_checksum c p with
        | Ok x -> x
        | Error e -> failwithf "Transaction_snark: load failed on %s" p ()
      in
      let%map step = load tick_controller step
      and wrap = load tock_controller wrap in
      let t = {step= step.data; wrap= wrap.data} in
      (t, checksum ~step:step.checksum ~wrap:wrap.checksum)
  end

  module Verification = struct
    module Location = Per_curve_location

    let checksum ~step ~wrap =
      Md5.digest_string
        ( "Blockchain_transition_verification" ^ Md5.to_hex step
        ^ Md5.to_hex wrap )

    type t = {step: Tick.Verification_key.t; wrap: Tock.Verification_key.t}

    let dummy =
      { step= Dummy_values.Tick.verification_key
      ; wrap= Dummy_values.Tock.verification_key }

    let load ({step; wrap}: Location.t) =
      let open Storage.Disk in
      let parent_log = Logger.create () in
      let tick_controller =
        Controller.create ~parent_log Tick.Verification_key.bin_t
      in
      let tock_controller =
        Controller.create ~parent_log Tock.Verification_key.bin_t
      in
      let open Async in
      let load c p =
        match%map load_with_checksum c p with
        | Ok x -> x
        | Error e -> failwithf "Transaction_snark: load failed on %s" p ()
      in
      let%map step = load tick_controller step
      and wrap = load tock_controller wrap in
      let t = {step= step.data; wrap= wrap.data} in
      (t, checksum ~step:step.checksum ~wrap:wrap.checksum)
  end

  type t = {proving: Proving.t; verification: Verification.t}

  let dummy = {proving= Proving.dummy; verification= Verification.dummy}

  module Checksum = struct
    type t = {proving: Md5.t; verification: Md5.t}
  end

  module Location = struct
    module T = struct
      type t =
        {proving: Proving.Location.t; verification: Verification.Location.t}
      [@@deriving sexp]
    end

    include T
    include Sexpable.To_stringable (T)
  end

  let load ({proving; verification}: Location.t) =
    let open Storage.Disk in
    let%map proving, proving_checksum = Proving.load proving
    and verification, verification_checksum = Verification.load verification in
    ( {proving; verification}
    , {Checksum.proving= proving_checksum; verification= verification_checksum}
    )
end

module Make (T : Transaction_snark.Verification.S) = struct
  module System = struct
    module U = Blockchain_state.Make_update (T)

    module State = struct
      include (
        Blockchain_state :
          module type of Blockchain_state
          with module Checked := Blockchain_state.Checked )

      include (U : module type of U with module Checked := U.Checked)

      module Checked = struct
        include Blockchain_state.Checked
        include U.Checked
      end
    end

    module Update = Nanobit_base.Block
  end

  open Nanobit_base

  include Transition_system.Make (struct
              module Tick = Digest
              module Tock = Bits.Snarkable.Field (Tock)
            end)
            (struct
              let hash bs =
                Tick.digest_bits ~init:Hash_prefix.transition_system_snark bs
            end)
            (System)

  module Keys = struct
    include Keys

    let step_cached =
      let load =
        let open Tick in
        let open Cached.Let_syntax in
        let%map verification =
          Cached.component ~label:"verification" ~f:Keypair.vk
            Verification_key.bin_t
        and proving =
          Cached.component ~label:"proving" ~f:Keypair.pk Proving_key.bin_t
        in
        (verification, proving)
      in
      Cached.Spec.create ~load ~directory:Cache_dir.cache_dir
        ~digest_input:
          (Fn.compose Md5.to_hex Tick.R1CS_constraint_system.digest)
        ~create_env:Tick.R1CS_constraint_system.generate_keypair
        ~input:
          (Tick.constraint_system ~exposing:(Step_base.input ()) Step_base.main)

    let cached () =
      let%bind step_vk, step_pk = Cached.run step_cached in
      let module Wrap = Wrap_base (struct
        let verification_key = step_vk.value
      end) in
      let wrap_cached =
        let load =
          let open Tock in
          let open Cached.Let_syntax in
          let%map verification =
            Cached.component ~label:"verification" ~f:Keypair.vk
              Verification_key.bin_t
          and proving =
            Cached.component ~label:"proving" ~f:Keypair.pk Proving_key.bin_t
          in
          (verification, proving)
        in
        Cached.Spec.create ~load ~directory:Cache_dir.cache_dir
          ~digest_input:
            (Fn.compose Md5.to_hex Tock.R1CS_constraint_system.digest)
          ~create_env:Tock.R1CS_constraint_system.generate_keypair
          ~input:(Tock.constraint_system ~exposing:(Wrap.input ()) Wrap.main)
      in
      let%map wrap_vk, wrap_pk = Cached.run wrap_cached in
      let location : Location.t =
        { proving= {step= step_pk.path; wrap= wrap_pk.path}
        ; verification= {step= step_vk.path; wrap= wrap_vk.path} }
      in
      let checksum : Checksum.t =
        { proving=
            Proving.checksum ~step:step_pk.checksum ~wrap:wrap_pk.checksum
        ; verification=
            Verification.checksum ~step:step_vk.checksum ~wrap:wrap_vk.checksum
        }
      in
      let t =
        { proving= {step= step_pk.value; wrap= wrap_pk.value}
        ; verification= {step= step_vk.value; wrap= wrap_vk.value} }
      in
      (location, t, checksum)
  end
end
