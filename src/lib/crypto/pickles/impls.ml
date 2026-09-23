open Pickles_types
open Core_kernel
open Import
open Backend
module Wrap_impl = Kimchi_pasta_snarky_backend.Wrap_impl

module Step = struct
  module Impl = Kimchi_pasta_snarky_backend.Step_impl
  include Impl
  module Verification_key = Tick.Verification_key
  module Proving_key = Tick.Proving_key

  module Keypair = struct
    type t = { pk : Proving_key.t; vk : Verification_key.t } [@@deriving fields]

    let create = Fields.create

    let generate ?(lazy_mode = false) ~prev_challenges cs =
      let open Tick.Keypair in
      let keypair = create ~lazy_mode ~prev_challenges cs in
      { pk = pk keypair; vk = vk keypair }
  end

  module Other_field = struct
    (* Tick.Field.t = p < q = Tock.Field.t *)

    module Constant = Tock.Field

    type t = (* Low bits, high bit *)
      Field.t * Boolean.var

    let typ_unchecked : (t, Constant.t) Typ.t =
      Typ.transport
        (Typ.tuple2 Field.typ Boolean.typ)
        ~there:(fun x ->
          match Tock.Field.to_bits x with
          | [] ->
              assert false
          | low :: high ->
              (Field.Constant.project high, low) )
        ~back:(fun (high, low) ->
          let high = Field.Constant.unpack high in
          Tock.Field.of_bits (low :: high) )

    let check t =
      let (Typ typ_unchecked) = typ_unchecked in
      typ_unchecked.check t

    let typ : _ Impl.Typ.t = typ_unchecked
  end

  module Digest = Digest.Make (Impl)
  module Challenge = Challenge.Make (Impl)

  type unfinalized_proof =
    ( Challenge.Constant.t
    , Challenge.Constant.t Scalar_challenge.t
    , Tock.Field.t Shifted_value.Type2.t
    , ( Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
      , Tock.Rounds.n )
      Vector.t
    , Digest.Constant.t
    , bool )
    Types.Step.Proof_state.Per_proof.In_circuit.t

  type 'proofs_verified statement =
    ( (unfinalized_proof, 'proofs_verified) Pickles_types.Vector.t
    , Import.Types.Digest.Constant.t
    , (Import.Types.Digest.Constant.t, 'proofs_verified) Pickles_types.Vector.t
    )
    Import.Types.Step.Statement.t

  type unfinalized_proof_var =
    ( Field.t
    , Field.t Scalar_challenge.t
    , Other_field.t Shifted_value.Type2.t
    , ( Field.t Scalar_challenge.t Bulletproof_challenge.t
      , Tock.Rounds.n )
      Pickles_types.Vector.t
    , Field.t
    , Boolean.var )
    Types.Step.Proof_state.Per_proof.In_circuit.t

  type 'proofs_verified statement_var =
    ( (unfinalized_proof_var, 'proofs_verified) Pickles_types.Vector.t
    , Impl.Field.t
    , (Impl.Field.t, 'proofs_verified) Pickles_types.Vector.t )
    Import.Types.Step.Statement.t

  let input ~proofs_verified =
    let open Types.Step.Statement in
    let spec = spec proofs_verified Tock.Rounds.n in
    let (T (typ, f, f_inv)) =
      Spec.packed_typ
        (T
           ( Shifted_value.Type2.typ Other_field.typ_unchecked
           , (fun (Shifted_value.Type2.Shifted_value x as t) ->
               Impl.run_checked (Other_field.check x) ;
               t )
           , Fn.id ) )
        spec
    in
    let typ = Typ.transport typ ~there:to_data ~back:of_data in
    Spec.Step_etyp.T (typ, (fun x -> of_data (f x)), fun x -> f_inv (to_data x))

  module Async_promise = Async_generic (Promise)
end

module Wrap = struct
  module Impl = Kimchi_pasta_snarky_backend.Wrap_impl
  include Impl
  module Challenge = Challenge.Make (Impl)
  module Digest = Digest.Make (Impl)
  module Wrap_field = Tock.Field
  module Step_field = Tick.Field
  module Verification_key = Tock.Verification_key
  module Proving_key = Tock.Proving_key

  module Keypair = struct
    type t = { pk : Proving_key.t; vk : Verification_key.t } [@@deriving fields]

    let create = Fields.create

    let generate ?(lazy_mode = false) ~prev_challenges cs =
      let open Tock.Keypair in
      let keypair = create ~lazy_mode ~prev_challenges cs in
      { pk = pk keypair; vk = vk keypair }
  end

  module Other_field = struct
    module Constant = Tick.Field
    open Impl

    type t = Field.t

    let typ_unchecked, check =
      (* Tick -> Tock *)
      let (Typ t0 as typ_unchecked) =
        Typ.transport Field.typ
          ~there:(Fn.compose Tock.Field.of_bits Tick.Field.to_bits)
          ~back:(Fn.compose Tick.Field.of_bits Tock.Field.to_bits)
      in
      (typ_unchecked, t0.check)

    let typ : _ Impl.Typ.t = typ_unchecked
  end

  let input
      ~feature_flags:
        ({ Plonk_types.Features.Full.uses_lookups; _ } as feature_flags) () =
    let feature_flags = Plonk_types.Features.of_full feature_flags in
    (* Zero values for lookup arguments when lookups are inactive or at circuit
       boundaries. These dummy values are used by the spec system to pad optional
       lookup data.

       - Type1 shifted values are used because the Wrap circuit's scalar field
         (Tick/Vesta) fits within its native field (Tock/Pallas), so no
         high-bit separation is needed (unlike Type2 which splits into
         (high_bits, low_bit) for larger scalar fields). *)
    let lookup =
      { Types.Wrap.Lookup_parameters.use = uses_lookups
      ; zero =
          { value =
              { challenge = Limb_vector.Challenge.Constant.zero
              ; scalar =
                  Shifted_value.Type1.Shifted_value Other_field.Constant.zero
              }
          ; var =
              { challenge = Impl.Field.zero
              ; scalar = Shifted_value.Type1.Shifted_value Impl.Field.zero
              }
          }
      }
    in
    let fp : (Impl.Field.t, Other_field.Constant.t) Typ.t =
      Other_field.typ_unchecked
    in
    let open Types.Wrap.Statement in
    let (T (typ, f, f_inv)) =
      Spec.wrap_packed_typ
        (T
           ( Shifted_value.Type1.wrap_typ fp
           , (fun (Shifted_value x as t) ->
               Impl.run_checked (Other_field.check x) ;
               t )
           , Fn.id ) )
        (In_circuit.spec (module Impl) lookup feature_flags)
    in
    let typ =
      Typ.transport typ
        ~there:(In_circuit.to_data ~option_map:Option.map)
        ~back:(In_circuit.of_data ~option_map:Option.map)
    in
    Spec.Wrap_etyp.T
      ( typ
      , (fun x -> In_circuit.of_data ~option_map:Opt.map (f x))
      , fun x -> f_inv (In_circuit.to_data ~option_map:Opt.map x) )
end
