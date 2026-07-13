(** Wrap-side proof types.

    Extracted from [Composition_types.Wrap], holding the
    [Proof_state], [Lookup_parameters], [Messages_for_next_step_proof]
    aliases and [Statement] modules used by the wrap circuit. *)

open Pickles_types
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
module Bulletproof_challenge = Bulletproof_challenge
module Branch_data = Branch_data
module Digest_ = Digest
module Spec = Spec
open Core_kernel
module Digest = Digest_
module Step_impl = Kimchi_pasta_snarky_backend.Step_impl
module Wrap_impl = Kimchi_pasta_snarky_backend.Wrap_impl

module Proof_state = struct
  (** Wire-format polymorphic skeleton. Concrete records below name
      it explicitly via {!Poly} rather than [include]ing it. *)
  module Poly = Wire.Wrap.Proof_state

  (** This module contains structures which contain the scalar-field elements that
      are required to finalize the verification of a proof that is partially verified inside
      a circuit.

      Each verifier circuit starts by verifying the parts of a proof involving group operations.
      At the end, there is a sequence of scalar-field computations it must perform. Instead of
      performing them directly, it exposes the values needed for those computations as a part of
      its own public-input, so that the next circuit can do them (since it will use the other curve on the cycle,
      and hence can efficiently perform computations in that scalar field). *)
  module Deferred_values = Wrap_deferred_values

  (** The component of the proof accumulation state that is only computed on by the
      "wrapping" proof system, and that can be handled opaquely by any "step" circuits. *)
  module Messages_for_next_wrap_proof = Messages_for_next.Wrap_proof

  (** Wire-form (out-of-circuit) instantiation of {!t}. {!to_stable}
      / {!of_stable} bridge to the polymorphic [Poly.Stable.V1.t]. *)
  module Constant = struct
    type ('plonk, 'fp) t =
      { deferred_values : ('plonk, 'fp) Deferred_values.Constant.t
      ; sponge_digest_before_evaluations : Digest.Constant.t
      ; messages_for_next_wrap_proof : Digest.Constant.t
      }

    let to_stable
        ({ deferred_values
         ; sponge_digest_before_evaluations
         ; messages_for_next_wrap_proof
         } :
          ('plonk, 'fp) t ) :
        ( 'plonk
        , Limb_vector.Challenge.Constant.t Scalar_challenge.t
        , 'fp
        , Digest.Constant.t
        , Digest.Constant.t
        , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
            Bulletproof_challenge.t
          , Backend.Tick.Rounds.n )
          Vector.t
        , Branch_data.t )
        Poly.Stable.V1.t =
      { deferred_values =
          Deferred_values.Constant.to_deferred_values deferred_values
      ; sponge_digest_before_evaluations
      ; messages_for_next_wrap_proof
      }

    let of_stable
        ({ deferred_values
         ; sponge_digest_before_evaluations
         ; messages_for_next_wrap_proof
         } :
          ( 'plonk
          , Limb_vector.Challenge.Constant.t Scalar_challenge.t
          , 'fp
          , Digest.Constant.t
          , Digest.Constant.t
          , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
              Bulletproof_challenge.t
            , Backend.Tick.Rounds.n )
            Vector.t
          , Branch_data.t )
          Poly.Stable.V1.t ) : ('plonk, 'fp) t =
      { deferred_values =
          Deferred_values.Constant.of_deferred_values deferred_values
      ; sponge_digest_before_evaluations
      ; messages_for_next_wrap_proof
      }
  end

  (** Step-circuit (Tick) instantiation of {!t}. Fresh record. *)
  module Step = struct
    type ('plonk, 'fp) t =
      { deferred_values : ('plonk, 'fp) Deferred_values.Step.t
      ; sponge_digest_before_evaluations : Step_impl.Field.t
      ; messages_for_next_wrap_proof : Step_impl.Field.t
      }

    let to_stable
        ({ deferred_values
         ; sponge_digest_before_evaluations
         ; messages_for_next_wrap_proof
         } :
          ('plonk, 'fp) t ) :
        ( 'plonk
        , Step_impl.Field.t Scalar_challenge.t
        , 'fp
        , Step_impl.Field.t
        , Step_impl.Field.t
        , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
          , Backend.Tick.Rounds.n )
          Vector.t
        , Branch_data.Checked.Step.t )
        Poly.Stable.V1.t =
      { deferred_values =
          Deferred_values.Step.to_deferred_values deferred_values
      ; sponge_digest_before_evaluations
      ; messages_for_next_wrap_proof
      }

    let of_stable
        ({ deferred_values
         ; sponge_digest_before_evaluations
         ; messages_for_next_wrap_proof
         } :
          ( 'plonk
          , Step_impl.Field.t Scalar_challenge.t
          , 'fp
          , Step_impl.Field.t
          , Step_impl.Field.t
          , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
            , Backend.Tick.Rounds.n )
            Vector.t
          , Branch_data.Checked.Step.t )
          Poly.Stable.V1.t ) : ('plonk, 'fp) t =
      { deferred_values =
          Deferred_values.Step.of_deferred_values deferred_values
      ; sponge_digest_before_evaluations
      ; messages_for_next_wrap_proof
      }
  end

  (** Wrap-circuit (Tock) instantiation of {!t}. Fresh record. *)
  module Wrap = struct
    type ('plonk, 'fp) t =
      { deferred_values : ('plonk, 'fp) Deferred_values.Wrap.t
      ; sponge_digest_before_evaluations : Wrap_impl.Field.t
      ; messages_for_next_wrap_proof : Wrap_impl.Field.t
      }

    let to_stable
        ({ deferred_values
         ; sponge_digest_before_evaluations
         ; messages_for_next_wrap_proof
         } :
          ('plonk, 'fp) t ) :
        ( 'plonk
        , Wrap_impl.Field.t Scalar_challenge.t
        , 'fp
        , Wrap_impl.Field.t
        , Wrap_impl.Field.t
        , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
          , Backend.Tick.Rounds.n )
          Vector.t
        , Wrap_impl.Field.t )
        Poly.Stable.V1.t =
      { deferred_values =
          Deferred_values.Wrap.to_deferred_values deferred_values
      ; sponge_digest_before_evaluations
      ; messages_for_next_wrap_proof
      }

    let of_stable
        ({ deferred_values
         ; sponge_digest_before_evaluations
         ; messages_for_next_wrap_proof
         } :
          ( 'plonk
          , Wrap_impl.Field.t Scalar_challenge.t
          , 'fp
          , Wrap_impl.Field.t
          , Wrap_impl.Field.t
          , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
            , Backend.Tick.Rounds.n )
            Vector.t
          , Wrap_impl.Field.t )
          Poly.Stable.V1.t ) : ('plonk, 'fp) t =
      { deferred_values =
          Deferred_values.Wrap.of_deferred_values deferred_values
      ; sponge_digest_before_evaluations
      ; messages_for_next_wrap_proof
      }
  end

  module Minimal = struct
    (** Wire-format polymorphic skeleton for the [Minimal] form. *)
    module Poly = Wire.Wrap.Proof_state.Minimal
  end

  (** [In_circuit] holds the per-proof-witness view of a proof
      state. The [messages_for_next_wrap_proof] slot is [unit]
      here because the per-proof witness records its [mfn_wrap]
      separately at the outer [Statement] level; the same proof
      state appears as a [Step.t] / [Constant.t] inside a
      [Per_proof_witness.t]. *)
  module In_circuit = struct
    (** Step-circuit (Tick) instantiation of {!t}. Used by the
        var-side of [Per_proof_witness.t]. *)
    module Step = struct
      type t =
        ( ( Step_impl.Field.t
          , Step_impl.Field.t Scalar_challenge.t
          , Step_impl.Field.t Shifted_value.Type1.t
          , ( Step_impl.Field.t Shifted_value.Type1.t
            , Step_impl.Boolean.var )
            Opt.t
          , (Step_impl.Field.t Scalar_challenge.t, Step_impl.Boolean.var) Opt.t
          , Step_impl.Boolean.var )
          Deferred_values.Plonk.In_circuit.t
        , Step_impl.Field.t Scalar_challenge.t
        , Step_impl.Field.t Shifted_value.Type1.t
        , unit
        , Step_impl.Field.t
        , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
          , Backend.Tick.Rounds.n )
          Vector.t
        , Branch_data.Checked.Step.t )
        Poly.Stable.Latest.t

      let typ ~dummy_scalar_challenge ~challenge ~scalar_challenge
          ~feature_flags fp messages_for_next_wrap_proof digest index =
        Step_impl.Typ.of_hlistable
          [ Deferred_values.In_circuit.typ ~dummy_scalar_challenge ~challenge
              ~scalar_challenge ~feature_flags fp index
          ; digest
          ; messages_for_next_wrap_proof
          ]
          ~var_to_hlist:Poly.Stable.Latest.to_hlist
          ~var_of_hlist:Poly.Stable.Latest.of_hlist
          ~value_to_hlist:Poly.Stable.Latest.to_hlist
          ~value_of_hlist:Poly.Stable.Latest.of_hlist
    end

    (** Out-of-circuit ("constant") instantiation of {!t}. Used by
        the value-side of [Per_proof_witness.Constant.t]. *)
    module Constant = struct
      type t =
        ( ( Limb_vector.Challenge.Constant.t
          , Limb_vector.Challenge.Constant.t Scalar_challenge.t
          , Backend.Tick.Field.t Shifted_value.Type1.t
          , Backend.Tick.Field.t Shifted_value.Type1.t option
          , Limb_vector.Challenge.Constant.t Scalar_challenge.t option
          , bool )
          Deferred_values.Plonk.In_circuit.t
        , Limb_vector.Challenge.Constant.t Scalar_challenge.t
        , Backend.Tick.Field.t Shifted_value.Type1.t
        , unit
        , Digest.Constant.t
        , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
            Bulletproof_challenge.t
          , Backend.Tick.Rounds.n )
          Vector.t
        , Branch_data.t )
        Poly.Stable.Latest.t
    end
  end

  let to_minimal
      ({ deferred_values
       ; sponge_digest_before_evaluations
       ; messages_for_next_wrap_proof
       } :
        _ Poly.t ) ~to_option : _ Minimal.Poly.t =
    { deferred_values = Deferred_values.to_minimal ~to_option deferred_values
    ; sponge_digest_before_evaluations
    ; messages_for_next_wrap_proof
    }
end

(** The component of the proof accumulation state that is only computed on by the
    "stepping" proof system, and that can be handled opaquely by any "wrap" circuits. *)
module Messages_for_next_step_proof = Messages_for_next.Step_proof

module Lookup_parameters = struct
  (* Values needed for computing lookup parts of the verifier circuit. *)
  type ('chal, 'chal_var, 'fp, 'fp_var) t =
    { zero : ('chal, 'chal_var, 'fp, 'fp_var) Zero_values.t; use : Opt.Flag.t }

  let opt_spec { zero = { value; var }; use } =
    Spec.T.Opt
      { inner = Struct [ Scalar Challenge ]
      ; flag = use
      ; dummy1 =
          [ Kimchi_backend_common.Scalar_challenge.create value.challenge ]
      ; dummy2 = [ Kimchi_backend_common.Scalar_challenge.create var.challenge ]
      }
end

(** This is the full statement for "wrap" proofs which contains
    - the application-level statement (app_state)
    - data needed to perform the final verification of the proof, which correspond
      to parts of incompletely verified proofs.
*)
module Statement = struct
  (** Wire-format polymorphic skeleton. Concrete records below name
      it explicitly via {!Poly} rather than [include]ing it. *)
  module Poly = Wire.Wrap.Statement

  (** Wire-form (out-of-circuit) instantiation of {!t}. {!to_stable}
      / {!of_stable} bridge to the polymorphic [Poly.Stable.V1.t]. *)

  module In_circuit = struct
    (** Out-of-circuit ("constant") instantiation of the in-circuit
        statement: a fresh concrete record that pins every parameter
        of the polymorphic skeleton except for the two
        messages-for-next-{wrap,step}-proof slots. Those carry
        proof-structure type variables that genuinely flow in from
        outside [Composition_types].

        The [proof_state] field still uses the wire-shaped polymorphic
        record (with its concrete params inlined) rather than a
        dedicated fresh record. The Plonk slot here is the
        [Constant_opt]-shape ([Opt.t] for lookup), which is the form
        that arrives via [Wrap_plonk_iop.In_circuit.Constant_opt.to_in_circuit]
        — distinct from the [option]-shape that
        [Wrap_proof_state.In_circuit.Constant.t] uses for
        per-proof-witness purposes. *)
    type ('messages_for_next_wrap_proof, 'messages_for_next_step_proof) t =
      { proof_state :
          ( ( Limb_vector.Challenge.Constant.t
            , Limb_vector.Challenge.Constant.t Scalar_challenge.t
            , Backend.Tick.Field.t Shifted_value.Type1.t
            , (Backend.Tick.Field.t Shifted_value.Type1.t, bool) Opt.t
            , (Limb_vector.Challenge.Constant.t Scalar_challenge.t, bool) Opt.t
            , bool )
            Proof_state.Deferred_values.Plonk.In_circuit.t
          , Limb_vector.Challenge.Constant.t Scalar_challenge.t
          , Backend.Tick.Field.t Shifted_value.Type1.t
          , 'messages_for_next_wrap_proof
          , Digest.Constant.t
          , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
              Bulletproof_challenge.t
            , Backend.Tick.Rounds.n )
            Vector.t
          , Branch_data.t )
          Wire.Wrap.Proof_state.Stable.V1.t
      ; messages_for_next_step_proof : 'messages_for_next_step_proof
      }

    (** Concrete instantiation with hashed [Digest.Constant.t] in
        every messages-for-next-* slot. This is the form that the
        Spec / [to_data] / [of_data] machinery below expects, and
        the form that [Constant.to_data] / [Step.to_data] /
        [Wrap.to_data] bridge [Statement.{Constant,Step,Wrap}.t]
        values to. *)
    module Hashed = struct
      type nonrec t = (Digest.Constant.t, Digest.Constant.t) t
    end

    (** Concrete instantiation with the unhashed
        [Reduced_messages_for_next.{Wrap,Step}.t] structures inlined
        — the shape consumed by [tweak_statement] / [wrap.ml]'s
        [next_statement]. The four type parameters match the
        proof-structure type variables those consumers thread
        through. *)
    module Unhashed = struct
      type nonrec ( 'max_proofs_verified
                  , 'app_state
                  , 'actual_proofs_verified
                  , 'bp_chal_length )
                  t =
        ( 'max_proofs_verified Reduced_messages_for_next.Wrap.t
        , ( 'app_state
          , 'actual_proofs_verified
          , 'bp_chal_length )
          Reduced_messages_for_next.Step.Specialised.t )
        t
    end

    type 'a vec8 =
      ('a * ('a * ('a * ('a * ('a * ('a * ('a * ('a * unit))))))))
      Hlist.HlistId.t

    type ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'fp_opt, 'bool) flat_repr =
      ( ('a, Nat.N5.n) Vector.t
      * ( ('b, Nat.N2.n) Vector.t
        * ( ('c, Nat.N3.n) Vector.t
          * ( ('d, Nat.N3.n) Vector.t
            * ('e * (('f, Nat.N1.n) Vector.t * ('bool vec8 * ('g * unit)))) ) )
        ) )
      Hlist.HlistId.t

    (** A layout of the raw data in a statement, which is needed for
        representing it inside the circuit. *)
    let spec (type f v) (_impl : (f, v) Spec.impl) lookup feature_flags =
      let feature_flags_spec =
        let [ f1; f2; f3; f4; f5; f6; f7; f8 ] =
          (* Ensure that layout is the same *)
          Plonk_types.Features.to_data feature_flags
        in
        let constant x =
          Spec.T.Constant (x, (fun x y -> assert (Bool.equal x y)), B Bool)
        in
        let maybe_constant flag =
          match flag with
          | Opt.Flag.Yes ->
              constant true
          | Opt.Flag.No ->
              constant false
          | Opt.Flag.Maybe ->
              Spec.T.B Bool
        in
        Spec.T.Struct
          [ maybe_constant f1
          ; maybe_constant f2
          ; maybe_constant f3
          ; maybe_constant f4
          ; maybe_constant f5
          ; maybe_constant f6
          ; maybe_constant f7
          ; maybe_constant f8
          ]
      in
      Spec.T.Struct
        [ Vector (B Field, Nat.N5.n)
        ; Vector (B Challenge, Nat.N2.n)
        ; Vector (Scalar Challenge, Nat.N3.n)
        ; Vector (B Digest, Nat.N3.n)
        ; Vector (B Bulletproof_challenge, Backend.Tick.Rounds.n)
        ; Vector (B Branch_data, Nat.N1.n)
        ; feature_flags_spec
        ; Lookup_parameters.opt_spec lookup
        ]

    (** Convert a statement (as structured data) into the flat data-based representation. *)
    let[@warning "-45"] to_data
        ({ proof_state =
             { deferred_values =
                 { xi
                 ; combined_inner_product
                 ; b
                 ; branch_data
                 ; bulletproof_challenges
                 ; plonk =
                     { alpha
                     ; beta
                     ; gamma
                     ; zeta
                     ; zeta_to_srs_length
                     ; zeta_to_domain_size
                     ; perm
                     ; feature_flags
                     ; joint_combiner
                     }
                 }
             ; sponge_digest_before_evaluations
             ; messages_for_next_wrap_proof
               (* messages_for_next_wrap_proof is represented as a digest (and then unhashed) inside the circuit *)
             }
         ; messages_for_next_step_proof
           (* messages_for_next_step_proof is represented as a digest inside the circuit *)
         } :
          _ t ) ~option_map =
      let open Vector in
      let fp =
        [ combined_inner_product
        ; b
        ; zeta_to_srs_length
        ; zeta_to_domain_size
        ; perm
        ]
      in
      let challenge = [ beta; gamma ] in
      let scalar_challenge = [ alpha; zeta; xi ] in
      let digest =
        [ sponge_digest_before_evaluations
        ; messages_for_next_wrap_proof
        ; messages_for_next_step_proof
        ]
      in
      let index = [ branch_data ] in
      Hlist.HlistId.
        [ fp
        ; challenge
        ; scalar_challenge
        ; digest
        ; bulletproof_challenges
        ; index
        ; Plonk_types.Features.to_data feature_flags
        ; option_map joint_combiner ~f:(fun x -> Hlist.HlistId.[ x ])
        ]

    (** Construct a statement (as structured data) from the flat data-based representation. *)
    let[@warning "-45"] of_data
        Hlist.HlistId.
          [ fp
          ; challenge
          ; scalar_challenge
          ; digest
          ; bulletproof_challenges
          ; index
          ; feature_flags
          ; joint_combiner
          ] ~option_map : _ t =
      let open Vector in
      let [ combined_inner_product
          ; b
          ; zeta_to_srs_length
          ; zeta_to_domain_size
          ; perm
          ] =
        fp
      in
      let [ beta; gamma ] = challenge in
      let [ alpha; zeta; xi ] = scalar_challenge in
      let [ sponge_digest_before_evaluations
          ; messages_for_next_wrap_proof
          ; messages_for_next_step_proof
          ] =
        digest
      in
      let [ branch_data ] = index in
      let feature_flags = Plonk_types.Features.of_data feature_flags in
      { proof_state =
          { deferred_values =
              { xi
              ; combined_inner_product
              ; b
              ; branch_data
              ; bulletproof_challenges
              ; plonk =
                  { alpha
                  ; beta
                  ; gamma
                  ; zeta
                  ; zeta_to_srs_length
                  ; zeta_to_domain_size
                  ; perm
                  ; feature_flags
                  ; joint_combiner =
                      option_map joint_combiner ~f:(fun Hlist.HlistId.[ x ] ->
                          x )
                  }
              }
          ; sponge_digest_before_evaluations
          ; messages_for_next_wrap_proof
          }
      ; messages_for_next_step_proof
      }
  end

  module Constant = struct
    type ('plonk, 'fp) t =
      { proof_state : ('plonk, 'fp) Proof_state.Constant.t
      ; messages_for_next_step_proof : Digest.Constant.t
      }

    let to_stable
        ({ proof_state; messages_for_next_step_proof } : ('plonk, 'fp) t) :
        ( 'plonk
        , Limb_vector.Challenge.Constant.t Scalar_challenge.t
        , 'fp
        , Digest.Constant.t
        , Digest.Constant.t
        , Digest.Constant.t
        , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
            Bulletproof_challenge.t
          , Backend.Tick.Rounds.n )
          Vector.t
        , Branch_data.t )
        Poly.Stable.V1.t =
      { proof_state = Proof_state.Constant.to_stable proof_state
      ; messages_for_next_step_proof
      }

    let of_stable
        ({ proof_state; messages_for_next_step_proof } :
          ( 'plonk
          , Limb_vector.Challenge.Constant.t Scalar_challenge.t
          , 'fp
          , Digest.Constant.t
          , Digest.Constant.t
          , Digest.Constant.t
          , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
              Bulletproof_challenge.t
            , Backend.Tick.Rounds.n )
            Vector.t
          , Branch_data.t )
          Poly.Stable.V1.t ) : ('plonk, 'fp) t =
      { proof_state = Proof_state.Constant.of_stable proof_state
      ; messages_for_next_step_proof
      }

    (** [Spec]-driven flat layout for [Constant.t] with the inner
        Plonk pinned to [Plonk.In_circuit.Constant.t] (with
        [option]-shaped [joint_combiner]). *)
    let spec = In_circuit.spec

    let[@warning "-45"] to_data
        ({ proof_state =
             { deferred_values =
                 { xi
                 ; combined_inner_product
                 ; b
                 ; branch_data
                 ; bulletproof_challenges
                 ; plonk
                 }
             ; sponge_digest_before_evaluations
             ; messages_for_next_wrap_proof
             }
         ; messages_for_next_step_proof
         } :
          (_ Proof_state.Deferred_values.Plonk.In_circuit.Constant.t, _) t )
        ~option_map =
      let { Proof_state.Deferred_values.Plonk.In_circuit.Constant.alpha
          ; beta
          ; gamma
          ; zeta
          ; zeta_to_srs_length
          ; zeta_to_domain_size
          ; perm
          ; feature_flags
          ; joint_combiner
          } =
        plonk
      in
      let open Vector in
      let fp =
        [ combined_inner_product
        ; b
        ; zeta_to_srs_length
        ; zeta_to_domain_size
        ; perm
        ]
      in
      let challenge = [ beta; gamma ] in
      let scalar_challenge = [ alpha; zeta; xi ] in
      let digest =
        [ sponge_digest_before_evaluations
        ; messages_for_next_wrap_proof
        ; messages_for_next_step_proof
        ]
      in
      let index = [ branch_data ] in
      Hlist.HlistId.
        [ fp
        ; challenge
        ; scalar_challenge
        ; digest
        ; bulletproof_challenges
        ; index
        ; Plonk_types.Features.to_data feature_flags
        ; option_map joint_combiner ~f:(fun x -> Hlist.HlistId.[ x ])
        ]

    let[@warning "-45"] of_data
        Hlist.HlistId.
          [ fp
          ; challenge
          ; scalar_challenge
          ; digest
          ; bulletproof_challenges
          ; index
          ; feature_flags
          ; joint_combiner
          ] ~option_map :
        (_ Proof_state.Deferred_values.Plonk.In_circuit.Constant.t, _) t =
      let open Vector in
      let [ combined_inner_product
          ; b
          ; zeta_to_srs_length
          ; zeta_to_domain_size
          ; perm
          ] =
        fp
      in
      let [ beta; gamma ] = challenge in
      let [ alpha; zeta; xi ] = scalar_challenge in
      let [ sponge_digest_before_evaluations
          ; messages_for_next_wrap_proof
          ; messages_for_next_step_proof
          ] =
        digest
      in
      let [ branch_data ] = index in
      let feature_flags = Plonk_types.Features.of_data feature_flags in
      { proof_state =
          { deferred_values =
              { xi
              ; combined_inner_product
              ; b
              ; branch_data
              ; bulletproof_challenges
              ; plonk =
                  { alpha
                  ; beta
                  ; gamma
                  ; zeta
                  ; zeta_to_srs_length
                  ; zeta_to_domain_size
                  ; perm
                  ; feature_flags
                  ; joint_combiner =
                      option_map joint_combiner ~f:(fun Hlist.HlistId.[ x ] ->
                          x )
                  }
              }
          ; sponge_digest_before_evaluations
          ; messages_for_next_wrap_proof
          }
      ; messages_for_next_step_proof
      }
  end

  (** Step-circuit (Tick) instantiation of {!t}. Fresh record. *)
  module Step = struct
    type ('plonk, 'fp) t =
      { proof_state : ('plonk, 'fp) Proof_state.Step.t
      ; messages_for_next_step_proof : Step_impl.Field.t
      }

    let to_stable
        ({ proof_state; messages_for_next_step_proof } : ('plonk, 'fp) t) :
        ( 'plonk
        , Step_impl.Field.t Scalar_challenge.t
        , 'fp
        , Step_impl.Field.t
        , Step_impl.Field.t
        , Step_impl.Field.t
        , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
          , Backend.Tick.Rounds.n )
          Vector.t
        , Branch_data.Checked.Step.t )
        Poly.Stable.V1.t =
      { proof_state = Proof_state.Step.to_stable proof_state
      ; messages_for_next_step_proof
      }

    let of_stable
        ({ proof_state; messages_for_next_step_proof } :
          ( 'plonk
          , Step_impl.Field.t Scalar_challenge.t
          , 'fp
          , Step_impl.Field.t
          , Step_impl.Field.t
          , Step_impl.Field.t
          , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
            , Backend.Tick.Rounds.n )
            Vector.t
          , Branch_data.Checked.Step.t )
          Poly.Stable.V1.t ) : ('plonk, 'fp) t =
      { proof_state = Proof_state.Step.of_stable proof_state
      ; messages_for_next_step_proof
      }

    (** [Spec]-driven flat layout for [Step.t] with the inner Plonk
        pinned to [Plonk.In_circuit.Step.t]. *)
    let spec = In_circuit.spec

    let[@warning "-45"] to_data
        ({ proof_state =
             { deferred_values =
                 { xi
                 ; combined_inner_product
                 ; b
                 ; branch_data
                 ; bulletproof_challenges
                 ; plonk
                 }
             ; sponge_digest_before_evaluations
             ; messages_for_next_wrap_proof
             }
         ; messages_for_next_step_proof
         } :
          (_ Proof_state.Deferred_values.Plonk.In_circuit.Step.t, _) t )
        ~option_map =
      let { Proof_state.Deferred_values.Plonk.In_circuit.Step.alpha
          ; beta
          ; gamma
          ; zeta
          ; zeta_to_srs_length
          ; zeta_to_domain_size
          ; perm
          ; feature_flags
          ; joint_combiner
          } =
        plonk
      in
      let open Vector in
      let fp =
        [ combined_inner_product
        ; b
        ; zeta_to_srs_length
        ; zeta_to_domain_size
        ; perm
        ]
      in
      let challenge = [ beta; gamma ] in
      let scalar_challenge = [ alpha; zeta; xi ] in
      let digest =
        [ sponge_digest_before_evaluations
        ; messages_for_next_wrap_proof
        ; messages_for_next_step_proof
        ]
      in
      let index = [ branch_data ] in
      Hlist.HlistId.
        [ fp
        ; challenge
        ; scalar_challenge
        ; digest
        ; bulletproof_challenges
        ; index
        ; Plonk_types.Features.to_data feature_flags
        ; option_map joint_combiner ~f:(fun x -> Hlist.HlistId.[ x ])
        ]

    let[@warning "-45"] of_data
        Hlist.HlistId.
          [ fp
          ; challenge
          ; scalar_challenge
          ; digest
          ; bulletproof_challenges
          ; index
          ; feature_flags
          ; joint_combiner
          ] ~option_map :
        (_ Proof_state.Deferred_values.Plonk.In_circuit.Step.t, _) t =
      let open Vector in
      let [ combined_inner_product
          ; b
          ; zeta_to_srs_length
          ; zeta_to_domain_size
          ; perm
          ] =
        fp
      in
      let [ beta; gamma ] = challenge in
      let [ alpha; zeta; xi ] = scalar_challenge in
      let [ sponge_digest_before_evaluations
          ; messages_for_next_wrap_proof
          ; messages_for_next_step_proof
          ] =
        digest
      in
      let [ branch_data ] = index in
      let feature_flags = Plonk_types.Features.of_data feature_flags in
      { proof_state =
          { deferred_values =
              { xi
              ; combined_inner_product
              ; b
              ; branch_data
              ; bulletproof_challenges
              ; plonk =
                  { alpha
                  ; beta
                  ; gamma
                  ; zeta
                  ; zeta_to_srs_length
                  ; zeta_to_domain_size
                  ; perm
                  ; feature_flags
                  ; joint_combiner =
                      option_map joint_combiner ~f:(fun Hlist.HlistId.[ x ] ->
                          x )
                  }
              }
          ; sponge_digest_before_evaluations
          ; messages_for_next_wrap_proof
          }
      ; messages_for_next_step_proof
      }
  end

  (** Wrap-circuit (Tock) instantiation of {!t}. Fresh record. *)
  module Wrap = struct
    type ('plonk, 'fp) t =
      { proof_state : ('plonk, 'fp) Proof_state.Wrap.t
      ; messages_for_next_step_proof : Wrap_impl.Field.t
      }

    let to_stable
        ({ proof_state; messages_for_next_step_proof } : ('plonk, 'fp) t) :
        ( 'plonk
        , Wrap_impl.Field.t Scalar_challenge.t
        , 'fp
        , Wrap_impl.Field.t
        , Wrap_impl.Field.t
        , Wrap_impl.Field.t
        , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
          , Backend.Tick.Rounds.n )
          Vector.t
        , Wrap_impl.Field.t )
        Poly.Stable.V1.t =
      { proof_state = Proof_state.Wrap.to_stable proof_state
      ; messages_for_next_step_proof
      }

    let of_stable
        ({ proof_state; messages_for_next_step_proof } :
          ( 'plonk
          , Wrap_impl.Field.t Scalar_challenge.t
          , 'fp
          , Wrap_impl.Field.t
          , Wrap_impl.Field.t
          , Wrap_impl.Field.t
          , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
            , Backend.Tick.Rounds.n )
            Vector.t
          , Wrap_impl.Field.t )
          Poly.Stable.V1.t ) : ('plonk, 'fp) t =
      { proof_state = Proof_state.Wrap.of_stable proof_state
      ; messages_for_next_step_proof
      }

    (** [Spec]-driven flat layout for [Wrap.t] with the inner Plonk
        pinned to [Plonk.In_circuit.Wrap.t]. *)
    let spec = In_circuit.spec

    let[@warning "-45"] to_data
        ({ proof_state =
             { deferred_values =
                 { xi
                 ; combined_inner_product
                 ; b
                 ; branch_data
                 ; bulletproof_challenges
                 ; plonk
                 }
             ; sponge_digest_before_evaluations
             ; messages_for_next_wrap_proof
             }
         ; messages_for_next_step_proof
         } :
          (_ Proof_state.Deferred_values.Plonk.In_circuit.Wrap.t, _) t )
        ~option_map =
      let { Proof_state.Deferred_values.Plonk.In_circuit.Wrap.alpha
          ; beta
          ; gamma
          ; zeta
          ; zeta_to_srs_length
          ; zeta_to_domain_size
          ; perm
          ; feature_flags
          ; joint_combiner
          } =
        plonk
      in
      let open Vector in
      let fp =
        [ combined_inner_product
        ; b
        ; zeta_to_srs_length
        ; zeta_to_domain_size
        ; perm
        ]
      in
      let challenge = [ beta; gamma ] in
      let scalar_challenge = [ alpha; zeta; xi ] in
      let digest =
        [ sponge_digest_before_evaluations
        ; messages_for_next_wrap_proof
        ; messages_for_next_step_proof
        ]
      in
      let index = [ branch_data ] in
      Hlist.HlistId.
        [ fp
        ; challenge
        ; scalar_challenge
        ; digest
        ; bulletproof_challenges
        ; index
        ; Plonk_types.Features.to_data feature_flags
        ; option_map joint_combiner ~f:(fun x -> Hlist.HlistId.[ x ])
        ]

    let[@warning "-45"] of_data
        Hlist.HlistId.
          [ fp
          ; challenge
          ; scalar_challenge
          ; digest
          ; bulletproof_challenges
          ; index
          ; feature_flags
          ; joint_combiner
          ] ~option_map :
        (_ Proof_state.Deferred_values.Plonk.In_circuit.Wrap.t, _) t =
      let open Vector in
      let [ combined_inner_product
          ; b
          ; zeta_to_srs_length
          ; zeta_to_domain_size
          ; perm
          ] =
        fp
      in
      let [ beta; gamma ] = challenge in
      let [ alpha; zeta; xi ] = scalar_challenge in
      let [ sponge_digest_before_evaluations
          ; messages_for_next_wrap_proof
          ; messages_for_next_step_proof
          ] =
        digest
      in
      let [ branch_data ] = index in
      let feature_flags = Plonk_types.Features.of_data feature_flags in
      { proof_state =
          { deferred_values =
              { xi
              ; combined_inner_product
              ; b
              ; branch_data
              ; bulletproof_challenges
              ; plonk =
                  { alpha
                  ; beta
                  ; gamma
                  ; zeta
                  ; zeta_to_srs_length
                  ; zeta_to_domain_size
                  ; perm
                  ; feature_flags
                  ; joint_combiner =
                      option_map joint_combiner ~f:(fun Hlist.HlistId.[ x ] ->
                          x )
                  }
              }
          ; sponge_digest_before_evaluations
          ; messages_for_next_wrap_proof
          }
      ; messages_for_next_step_proof
      }
  end

  module Minimal = struct
    (** Wire-format polymorphic skeleton for the [Minimal] form. *)
    module Poly = Wire.Wrap.Statement.Minimal
  end

  let to_minimal
      ({ proof_state; messages_for_next_step_proof } : _ In_circuit.t)
      ~to_option : _ Minimal.Poly.t =
    { proof_state = Proof_state.to_minimal ~to_option proof_state
    ; messages_for_next_step_proof
    }
end
