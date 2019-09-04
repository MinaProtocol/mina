open Core_kernel
open Async_kernel
open Snark_params
open Coda_state
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
          Tick_backend.Verification_key.dummy
            ~input_size:Transition_system.Step.input_size
      ; wrap=
          Tock_backend.Bowe_gabizon.Verification_key.dummy
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
  open Coda_base

  (* This code here is just munging stuff so that it's in the shape expected
   by [Transition_system.Step.Make]. Ultimately the modules upstream should
   be refactored so they can be passed in directly. *)
  module Step = Transition_system.Step.Make (struct
    let ( ! ) = Tick.Run.run_checked

    module Update = struct
      type t = Snark_transition.var

      module Unchecked = struct
        type t = Snark_transition.value
      end

      let typ = Snark_transition.typ
    end

    module State = struct
      type t = Protocol_state.var

      module Hash = struct
        type t = State_hash.var

        module Unchecked = State_hash

        let is_base h = !(Blockchain_snark_state.Checked.is_base_hash h)

        let to_triples t = !(State_hash.var_to_triples t)

        let typ = State_hash.typ
      end

      module Unchecked = struct
        type t = Protocol_state.value [@@deriving sexp]

        let hash = Protocol_state.hash
      end

      let typ = Protocol_state.typ

      let hash t = !(Blockchain_snark_state.Checked.hash t)

      module U = Blockchain_snark_state.Make_update (T)

      let update s_with_hash u = !(U.Checked.update s_with_hash u)
    end
  end)

  module Keys = struct
    include Keys

    let step_cached =
      let load =
        let open Tick in
        let open Cached.Let_syntax in
        let%map verification =
          Cached.component ~label:"verification" ~f:Keypair.vk
            (module Verification_key)
        and proving =
          Cached.component ~label:"proving" ~f:Keypair.pk (module Proving_key)
        in
        (verification, {proving with value= ()})
      in
      Cached.Spec.create ~load ~name:"blockchain-snark step keys"
        ~autogen_path:Cache_dir.autogen_path
        ~manual_install_path:Cache_dir.manual_install_path
        ~brew_install_path:Cache_dir.brew_install_path
        ~digest_input:(fun x ->
          Md5.to_hex (Tick.R1CS_constraint_system.digest (Lazy.force x)) )
        ~create_env:(Fn.compose Tick.Keypair.generate Lazy.force)
        ~input:(lazy (Step.constraint_system ()))

    let wrap_cached =
      let load =
        let open Tock in
        let open Cached.Let_syntax in
        let%map verification =
          Cached.component ~label:"verification" ~f:Keypair.vk
            (module Verification_key)
        and proving =
          Cached.component ~label:"proving" ~f:Keypair.pk (module Proving_key)
        in
        (verification, {proving with value= ()})
      in
      Cached.Spec.create ~load ~name:"blockchain-snark wrap keys"
        ~autogen_path:Cache_dir.autogen_path
        ~manual_install_path:Cache_dir.manual_install_path
        ~brew_install_path:Cache_dir.brew_install_path
        ~digest_input:(fun x ->
          Md5.to_hex (Tock.R1CS_constraint_system.digest (Lazy.force x)) )
        ~input:(lazy (Transition_system.Wrap.constraint_system ()))
        ~create_env:(fun x -> Tock.Keypair.generate (Lazy.force x))

    let cached () =
      let paths = Fn.compose Cache_dir.possible_paths Filename.basename in
      let%bind step_vk, step_pk = Cached.run step_cached in
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

let constraint_system_digests () =
  let module M = Make (Transaction_snark.Verification.Make (struct
    let keys = Transaction_snark.Keys.Verification.dummy
  end)) in
  let digest = Tick.R1CS_constraint_system.digest in
  let digest' = Tock.R1CS_constraint_system.digest in
  [ ("blockchain-step", digest (M.Step.constraint_system ()))
  ; ("blockchain-wrap", digest' (Transition_system.Wrap.constraint_system ()))
  ]
