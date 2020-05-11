open Core_kernel
open Async_kernel
open Snark_params
open Snark_bits
open Coda_state
open Fold_lib
open Bitstring_lib
module Digest = Tick.Pedersen.Digest
module Storage = Storage.List.Make (Storage.Disk)

module Keys = struct
  module Per_curve_location = struct
    module T = struct
      type t = {step: Storage.location; wrap: Storage.location}
      [@@deriving sexp]
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
      { step= Dummy_values.Tick.Groth16.proving_key
      ; wrap= Dummy_values.Tock.Bowe_gabizon18.proving_key }

    let load ({step; wrap} : Location.t) =
      let open Storage in
      let logger = Logger.create () in
      let tick_controller =
        Controller.create ~logger (module Tick.Proving_key)
      in
      let tock_controller =
        Controller.create ~logger (module Tock.Proving_key)
      in
      let open Async in
      let load c p =
        match%map load_with_checksum c p with
        | Ok x ->
            x
        | Error e ->
            failwithf
              !"Blockchain_snark: load failed on %{sexp:Storage.location}: \
                %{sexp:[`Checksum_no_match|`No_exist|`IO_error of Error.t]}"
              p e ()
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
      { step=
          Tick_backend.Verification_key.get_dummy
            ~input_size:Coda_base.Transition_system.step_input_size
      ; wrap=
          Tock_backend.Bowe_gabizon.Verification_key.get_dummy
            ~input_size:Wrap_input.size }

    let load ({step; wrap} : Location.t) =
      let open Storage in
      let logger = Logger.create () in
      let tick_controller =
        Controller.create ~logger (module Tick.Verification_key)
      in
      let tock_controller =
        Controller.create ~logger (module Tock.Verification_key)
      in
      let open Async in
      let load c p =
        match%map load_with_checksum c p with
        | Ok x ->
            x
        | Error _e ->
            failwithf
              !"Blockchain_snark: load failed on %{sexp:Storage.location}"
              p ()
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

  let load ({proving; verification} : Location.t) =
    let%map proving, proving_checksum = Proving.load proving
    and verification, verification_checksum = Verification.load verification in
    ( {proving; verification}
    , {Checksum.proving= proving_checksum; verification= verification_checksum}
    )
end

module Make (T : Transaction_snark.Verification.S) = struct
  module System = struct
    module U = Blockchain_snark_state.Make_update (T)
    module Update = Snark_transition

    module State = struct
      include Protocol_state

      include (
        Blockchain_snark_state :
          module type of Blockchain_snark_state
          with module Checked := Blockchain_snark_state.Checked )

      include (U : module type of U with module Checked := U.Checked)

      module Hash = struct
        include Coda_base.State_hash

        let var_to_field = var_to_hash_packed
      end

      module Body_hash = struct
        include Coda_base.State_body_hash

        let var_to_field = var_to_hash_packed
      end

      module Checked = struct
        include Blockchain_snark_state.Checked
        include U.Checked
      end
    end
  end

  open Coda_base

  include Transition_system.Make (struct
              module Tick = struct
                let size_in_bits = Tick.Field.size_in_bits

                module Packed = struct
                  type value = Tick.Pedersen.Digest.t

                  type var = Tick.Pedersen.Checked.Digest.var

                  let typ = Tick.Pedersen.Checked.Digest.typ

                  let size_in_bits = size_in_bits
                end

                module Unpacked = struct
                  type value = Tick.Pedersen.Checked.Digest.Unpacked.t

                  type var = Tick.Pedersen.Checked.Digest.Unpacked.var

                  let typ : (var, value) Tick.Typ.t =
                    Tick.Pedersen.Checked.Digest.Unpacked.typ

                  let var_to_bits (x : var) =
                    Bitstring_lib.Bitstring.Lsb_first.of_list
                      (x :> Tick.Boolean.var list)

                  let var_of_bits = Fn.id

                  let var_to_triples xs =
                    let open Fold in
                    to_list
                      (group3 ~default:Tick.Boolean.false_
                         (of_list (var_to_bits xs :> Tick.Boolean.var list)))

                  let var_of_value =
                    Tick.Pedersen.Checked.Digest.Unpacked.constant

                  let size_in_bits = size_in_bits
                end

                let project_value =
                  Fn.compose Tick.Field.project Bitstring.Lsb_first.to_list

                let project_var = Tick.Pedersen.Checked.Digest.Unpacked.project

                let unpack_value =
                  Fn.compose Bitstring.Lsb_first.of_list Tick.Field.unpack

                let choose_preimage_var =
                  Tick.Pedersen.Checked.Digest.choose_preimage
              end

              module Tock = Bits.Snarkable.Field (Tock)
            end)
            (System)

  module Keys = struct
    include Keys

    let step_cached =
      let load =
        let open Tick in
        let open Cached.Let_syntax in
        let%map verification =
          Cached.component ~label:"step_verification" ~f:Keypair.vk
            (module Verification_key)
        and proving =
          Cached.component ~label:"step_proving" ~f:Keypair.pk
            (module Proving_key)
        in
        (verification, {proving with value= ()})
      in
      Cached.Spec.create ~load ~name:"blockchain-snark step keys"
        ~autogen_path:Cache_dir.autogen_path
        ~manual_install_path:Cache_dir.manual_install_path
        ~brew_install_path:Cache_dir.brew_install_path
        ~s3_install_path:Cache_dir.s3_install_path
        ~digest_input:
          (Fn.compose Md5.to_hex Tick.R1CS_constraint_system.digest)
        ~create_env:Tick.Keypair.generate
        ~input:
          (Tick.constraint_system ~exposing:(Step_base.input ())
             (Step_base.main ~logger:(Logger.null ())
                ~proof_level:Genesis_constants.Proof_level.compiled
                ~ledger_depth:Genesis_constants.ledger_depth))

    let cached () =
      let open Cached.Deferred_with_track_generated.Let_syntax in
      let paths = Fn.compose Cache_dir.possible_paths Filename.basename in
      let%bind step_vk, step_pk = Cached.run step_cached in
      let module Wrap = Wrap_base (struct
        let verification_key = step_vk.value
      end) in
      let wrap_cached =
        let load =
          let open Tock in
          let open Cached.Let_syntax in
          let%map verification =
            Cached.component ~label:"wrap_verification" ~f:Keypair.vk
              (module Verification_key)
          and proving =
            Cached.component ~label:"wrap_proving" ~f:Keypair.pk
              (module Proving_key)
          in
          (verification, {proving with value= ()})
        in
        Cached.Spec.create ~load ~name:"blockchain-snark wrap keys"
          ~autogen_path:Cache_dir.autogen_path
          ~manual_install_path:Cache_dir.manual_install_path
          ~brew_install_path:Cache_dir.brew_install_path
          ~s3_install_path:Cache_dir.s3_install_path
          ~digest_input:(fun x ->
            Md5.to_hex (Tock.R1CS_constraint_system.digest (Lazy.force x)) )
          ~input:(lazy (Tock.constraint_system ~exposing:Wrap.input Wrap.main))
          ~create_env:(fun x -> Tock.Keypair.generate (Lazy.force x))
      in
      let%map wrap_vk, wrap_pk = Cached.run wrap_cached in
      let location : Location.t =
        { proving= {step= paths step_pk.path; wrap= paths wrap_pk.path}
        ; verification= {step= paths step_vk.path; wrap= paths wrap_vk.path} }
      in
      let checksum : Checksum.t =
        { proving=
            Proving.checksum ~step:step_pk.checksum ~wrap:wrap_pk.checksum
        ; verification=
            Verification.checksum ~step:step_vk.checksum ~wrap:wrap_vk.checksum
        }
      in
      let t : Verification.t = {step= step_vk.value; wrap= wrap_vk.value} in
      (location, t, checksum)
  end
end

let instance_hash wrap_vk =
  let open Coda_base in
  let init =
    Random_oracle.update ~state:Hash_prefix.transition_system_snark
      Snark_params.Tick.Verifier.(
        let vk = vk_of_backend_vk wrap_vk in
        let g1 = Tick.Inner_curve.to_affine_exn in
        let g2 = Tick.Pairing.G2.Unchecked.to_affine_exn in
        Verification_key.to_field_elements
          { vk with
            query_base= g1 vk.query_base
          ; query= List.map ~f:g1 vk.query
          ; delta= g2 vk.delta })
  in
  stage (fun state ->
      Random_oracle.hash ~init [|(Protocol_state.hash state :> Tick.Field.t)|]
  )

let constraint_system_digests () =
  let module M = Make (Transaction_snark.Verification.Make (struct
    let keys = Transaction_snark.Keys.Verification.dummy
  end)) in
  let module W = M.Wrap_base (struct
    let verification_key = Keys.Verification.dummy.step
  end) in
  let digest = Tick.R1CS_constraint_system.digest in
  let digest' = Tock.R1CS_constraint_system.digest in
  [ ( "blockchain-step"
    , digest
        M.Step_base.(
          Tick.constraint_system ~exposing:(input ())
            (main ~logger:(Logger.null ())
               ~proof_level:Genesis_constants.Proof_level.compiled
               ~ledger_depth:Genesis_constants.ledger_depth)) )
  ; ("blockchain-wrap", digest' W.(Tock.constraint_system ~exposing:input main))
  ]
