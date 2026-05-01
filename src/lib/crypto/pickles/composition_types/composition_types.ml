open Pickles_types
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
module Bulletproof_challenge = Bulletproof_challenge
module Branch_data = Branch_data
module Digest = Digest
module Spec = Spec
module Opt = Opt
module Wire = Wire
module Messages_for_next = Messages_for_next
module Reduced_messages_for_next = Reduced_messages_for_next

(* Internal alias preserving access to the local [Digest] module after the
   file-level [open Core_kernel] below shadows the unqualified name. *)
module Digest_ = Digest
open Core_kernel
module Step_impl = Kimchi_pasta_snarky_backend.Step_impl
module Wrap_impl = Kimchi_pasta_snarky_backend.Wrap_impl

let index_to_field_elements =
  Pickles_base.Side_loaded_verification_key.index_to_field_elements

module Zero_values = struct
  type ('chal, 'fp) single = { challenge : 'chal; scalar : 'fp }

  type ('chal, 'chal_var, 'fp, 'fp_var) t =
    { value : ('chal, 'fp) single; var : ('chal_var, 'fp_var) single }
end

module Wrap = struct
  module Proof_state = struct
    (** This module contains structures which contain the scalar-field elements that
        are required to finalize the verification of a proof that is partially verified inside
        a circuit.

        Each verifier circuit starts by verifying the parts of a proof involving group operations.
        At the end, there is a sequence of scalar-field computations it must perform. Instead of
        performing them directly, it exposes the values needed for those computations as a part of
        its own public-input, so that the next circuit can do them (since it will use the other curve on the cycle,
        and hence can efficiently perform computations in that scalar field). *)
    include Wire.Wrap.Proof_state

    module Deferred_values = Wrap_deferred_values

    (** The component of the proof accumulation state that is only computed on by the
        "wrapping" proof system, and that can be handled opaquely by any "step" circuits. *)
    module Messages_for_next_wrap_proof = Messages_for_next.Wrap_proof

    module Minimal = struct
      include Wire.Wrap.Proof_state.Minimal
    end

    module In_circuit = struct
      type ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fp_opt
           , 'lookup_opt
           , 'bool
           , 'messages_for_next_wrap_proof
           , 'digest
           , 'bp_chals
           , 'index )
           t =
        ( ( 'challenge
          , 'scalar_challenge
          , 'fp
          , 'fp_opt
          , 'lookup_opt
          , 'bool )
          Deferred_values.Plonk.In_circuit.t
        , 'scalar_challenge
        , 'fp
        , 'messages_for_next_wrap_proof
        , 'digest
        , 'bp_chals
        , 'index )
        Stable.Latest.t
      [@@deriving sexp, compare, yojson, hash, equal]

      let to_hlist, of_hlist = (to_hlist, of_hlist)

      let typ (type fp) ~dummy_scalar_challenge ~challenge ~scalar_challenge
          ~feature_flags (fp : (fp, _) Step_impl.Typ.t)
          messages_for_next_wrap_proof digest index =
        Step_impl.Typ.of_hlistable
          [ Deferred_values.In_circuit.typ ~dummy_scalar_challenge ~challenge
              ~scalar_challenge ~feature_flags fp index
          ; digest
          ; messages_for_next_wrap_proof
          ]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
          ~value_of_hlist:of_hlist

      (** Step-circuit (Tick) instantiation of {!t}. Used by the var-side
          of [Per_proof_witness.t]. The [messages_for_next_wrap_proof] slot
          is [unit] because the per-proof witness records its mfn-wrap
          digest separately at the outer [Statement] level. *)
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
          Stable.Latest.t

        let typ ~dummy_scalar_challenge ~challenge ~scalar_challenge
            ~feature_flags fp messages_for_next_wrap_proof digest index :
            (t, _) Step_impl.Typ.t =
          Step_impl.Typ.of_hlistable
            [ Deferred_values.In_circuit.typ ~dummy_scalar_challenge ~challenge
                ~scalar_challenge ~feature_flags fp index
            ; digest
            ; messages_for_next_wrap_proof
            ]
            ~var_to_hlist:Stable.Latest.to_hlist
            ~var_of_hlist:Stable.Latest.of_hlist
            ~value_to_hlist:Stable.Latest.to_hlist
            ~value_of_hlist:Stable.Latest.of_hlist
      end

      (** Out-of-circuit ("constant") instantiation of {!t}. Used by the
          value-side of [Per_proof_witness.Constant.t]. *)
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
          , Digest_.Constant.t
          , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
              Bulletproof_challenge.t
            , Backend.Tick.Rounds.n )
            Vector.t
          , Branch_data.t )
          Stable.Latest.t
      end
    end

    let to_minimal
        ({ deferred_values
         ; sponge_digest_before_evaluations
         ; messages_for_next_wrap_proof
         } :
          _ In_circuit.t ) ~to_option : _ Minimal.t =
      { deferred_values = Deferred_values.to_minimal ~to_option deferred_values
      ; sponge_digest_before_evaluations
      ; messages_for_next_wrap_proof
      }

    (** Wire-format polymorphic skeleton. Concrete records below name it
        explicitly via {!Poly} rather than [include]ing it. *)
    module Poly = Wire.Wrap.Proof_state

    (** Wire-form (out-of-circuit) instantiation. Pins the digest /
        bulletproof / branch_data slots; ['plonk] and ['fp] stay
        polymorphic. *)
    module Constant = struct
      type ('plonk, 'fp) t =
        { deferred_values : ('plonk, 'fp) Deferred_values.Constant.t
        ; sponge_digest_before_evaluations : Digest_.Constant.t
        ; messages_for_next_wrap_proof : Digest_.Constant.t
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
          , Digest_.Constant.t
          , Digest_.Constant.t
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
            , Digest_.Constant.t
            , Digest_.Constant.t
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

    let _ = fun (c : (_, _) Constant.t) -> Constant.of_stable (Constant.to_stable c)

    (** Step-circuit (Tick) instantiation. *)
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

    let _ = fun (s : (_, _) Step.t) -> Step.of_stable (Step.to_stable s)

    (** Wrap-circuit (Tock) instantiation. *)
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

    let _ = fun (w : (_, _) Wrap.t) -> Wrap.of_stable (Wrap.to_stable w)
  end

  (** The component of the proof accumulation state that is only computed on by the
      "stepping" proof system, and that can be handled opaquely by any "wrap" circuits. *)
  module Messages_for_next_step_proof = Messages_for_next.Step_proof

  module Lookup_parameters = struct
    (* Values needed for computing lookup parts of the verifier circuit. *)
    type ('chal, 'chal_var, 'fp, 'fp_var) t =
      { zero : ('chal, 'chal_var, 'fp, 'fp_var) Zero_values.t
      ; use : Opt.Flag.t
      }

    let opt_spec { zero = { value; var }; use } =
      Spec.T.Opt
        { inner = Struct [ Scalar Challenge ]
        ; flag = use
        ; dummy1 =
            [ Kimchi_backend_common.Scalar_challenge.create value.challenge ]
        ; dummy2 =
            [ Kimchi_backend_common.Scalar_challenge.create var.challenge ]
        }
  end

  (** This is the full statement for "wrap" proofs which contains
      - the application-level statement (app_state)
      - data needed to perform the final verification of the proof, which correspond
        to parts of incompletely verified proofs.
  *)
  module Statement = struct
    include Wire.Wrap.Statement

    module Minimal = struct
      include Wire.Wrap.Statement.Minimal
    end

    module In_circuit = struct
      type ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fp_opt
           , 'lookup_opt
           , 'bool
           , 'messages_for_next_wrap_proof
           , 'digest
           , 'messages_for_next_step_proof
           , 'bp_chals
           , 'index )
           t =
        ( ( 'challenge
          , 'scalar_challenge
          , 'fp
          , 'fp_opt
          , 'lookup_opt
          , 'bool )
          Proof_state.Deferred_values.Plonk.In_circuit.t
        , 'scalar_challenge
        , 'fp
        , 'messages_for_next_wrap_proof
        , 'digest
        , 'messages_for_next_step_proof
        , 'bp_chals
        , 'index )
        Stable.Latest.t
      [@@deriving compare, yojson, sexp, hash, equal]

      (** A layout of the raw data in a statement, which is needed for
          representing it inside the circuit. *)
      let spec _impl lookup feature_flags =
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

    let to_minimal
        ({ proof_state; messages_for_next_step_proof } : _ In_circuit.t)
        ~to_option : _ Minimal.t =
      { proof_state = Proof_state.to_minimal ~to_option proof_state
      ; messages_for_next_step_proof
      }

    (** Wire-format polymorphic skeleton. Concrete records below name it
        explicitly via {!Poly} rather than [include]ing it. *)
    module Poly = Wire.Wrap.Statement

    (** Wire-form (out-of-circuit) instantiation. Pins
        [messages_for_next_step_proof] to a digest; ['plonk] and ['fp]
        stay polymorphic. *)
    module Constant = struct
      type ('plonk, 'fp) t =
        { proof_state : ('plonk, 'fp) Proof_state.Constant.t
        ; messages_for_next_step_proof : Digest_.Constant.t
        }

      let to_stable
          ({ proof_state; messages_for_next_step_proof } : ('plonk, 'fp) t) :
          ( 'plonk
          , Limb_vector.Challenge.Constant.t Scalar_challenge.t
          , 'fp
          , Digest_.Constant.t
          , Digest_.Constant.t
          , Digest_.Constant.t
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
            , Digest_.Constant.t
            , Digest_.Constant.t
            , Digest_.Constant.t
            , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
                Bulletproof_challenge.t
              , Backend.Tick.Rounds.n )
              Vector.t
            , Branch_data.t )
            Poly.Stable.V1.t ) : ('plonk, 'fp) t =
        { proof_state = Proof_state.Constant.of_stable proof_state
        ; messages_for_next_step_proof
        }
    end

    let _ = fun (c : (_, _) Constant.t) -> Constant.of_stable (Constant.to_stable c)

    (** Step-circuit (Tick) instantiation. *)
    module Step = struct
      type ('plonk, 'fp, 'messages_for_next_step_proof) t =
        { proof_state : ('plonk, 'fp) Proof_state.Step.t
        ; messages_for_next_step_proof : 'messages_for_next_step_proof
        }

      let to_stable
          ({ proof_state; messages_for_next_step_proof } :
            ('plonk, 'fp, 'm) t ) :
          ( 'plonk
          , Step_impl.Field.t Scalar_challenge.t
          , 'fp
          , Step_impl.Field.t
          , Step_impl.Field.t
          , 'm
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
            , 'm
            , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
              , Backend.Tick.Rounds.n )
              Vector.t
            , Branch_data.Checked.Step.t )
            Poly.Stable.V1.t ) : ('plonk, 'fp, 'm) t =
        { proof_state = Proof_state.Step.of_stable proof_state
        ; messages_for_next_step_proof
        }
    end

    let _ = fun (s : (_, _, _) Step.t) -> Step.of_stable (Step.to_stable s)

    (** Wrap-circuit (Tock) instantiation. *)
    module Wrap = struct
      type ('plonk, 'fp, 'messages_for_next_step_proof) t =
        { proof_state : ('plonk, 'fp) Proof_state.Wrap.t
        ; messages_for_next_step_proof : 'messages_for_next_step_proof
        }

      let to_stable
          ({ proof_state; messages_for_next_step_proof } :
            ('plonk, 'fp, 'm) t ) :
          ( 'plonk
          , Wrap_impl.Field.t Scalar_challenge.t
          , 'fp
          , Wrap_impl.Field.t
          , Wrap_impl.Field.t
          , 'm
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
            , 'm
            , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
              , Backend.Tick.Rounds.n )
              Vector.t
            , Wrap_impl.Field.t )
            Poly.Stable.V1.t ) : ('plonk, 'fp, 'm) t =
        { proof_state = Proof_state.Wrap.of_stable proof_state
        ; messages_for_next_step_proof
        }
    end

    let _ = fun (w : (_, _, _) Wrap.t) -> Wrap.of_stable (Wrap.to_stable w)
  end
end

module Step = struct
  module Plonk_polys = Nat.N10

  module Bulletproof = struct
    include Plonk_types.Openings.Bulletproof

    module Advice = struct
      (** This is data that can be computed in linear time from the proof + statement.

          It doesn't need to be sent on the wire, but it does need to be provided to the verifier
      *)
      type 'fq t =
        { b : 'fq
        ; combined_inner_product : 'fq (* sum_i r^i sum_j xi^j f_j(pt_i) *)
        }
      [@@deriving hlist]
    end
  end

  module Proof_state = struct
    module Deferred_values = Step_deferred_values

    module Messages_for_next_wrap_proof =
      Wrap.Proof_state.Messages_for_next_wrap_proof
    module Messages_for_next_step_proof = Wrap.Messages_for_next_step_proof

    module Per_proof = Step_per_proof

    type ('unfinalized_proofs, 'messages_for_next_step_proof) t =
      { unfinalized_proofs : 'unfinalized_proofs
            (** A vector of the "per-proof" structures defined above, one for each proof
    that the step-circuit partially verifies. *)
      ; messages_for_next_step_proof : 'messages_for_next_step_proof
            (** The component of the proof accumulation state that is only computed on by the
          "stepping" proof system, and that can be handled opaquely by any "wrap" circuits. *)
      }
    [@@deriving sexp, compare, yojson, hlist]

    let spec unfinalized_proofs messages_for_next_step_proof =
      Spec.T.Struct [ unfinalized_proofs; messages_for_next_step_proof ]

    let[@warning "-60"] wrap_typ (type n) ~assert_16_bits
        (proofs_verified : (Opt.Flag.t Plonk_types.Features.t, n) Vector.t) fq :
        (((_, _) Vector.t, _) t, ((_, _) Vector.t, _) t) Wrap_impl.Typ.t =
      let per_proof _ = Per_proof.wrap_typ fq ~assert_16_bits in
      let unfinalized_proofs =
        Vector.wrap_typ' (Vector.map proofs_verified ~f:per_proof)
      in
      let messages_for_next_step_proof =
        Spec.wrap_typ fq ~assert_16_bits (B Spec.Digest)
      in
      Wrap_impl.Typ.of_hlistable
        [ unfinalized_proofs; messages_for_next_step_proof ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  module Statement = struct
    type ( 'unfinalized_proofs
         , 'messages_for_next_step_proof
         , 'messages_for_next_wrap_proof )
         t =
      { proof_state :
          ('unfinalized_proofs, 'messages_for_next_step_proof) Proof_state.t
      ; messages_for_next_wrap_proof : 'messages_for_next_wrap_proof
            (** The component of the proof accumulation state that is only computed on by the
        "wrapping" proof system, and that can be handled opaquely by any "step" circuits. *)
      }
    [@@deriving sexp, compare, yojson]

    let[@warning "-45"] to_data
        { proof_state = { unfinalized_proofs; messages_for_next_step_proof }
        ; messages_for_next_wrap_proof
        } =
      let open Hlist.HlistId in
      [ Vector.map unfinalized_proofs
          ~f:Proof_state.Per_proof.In_circuit.to_data
      ; messages_for_next_step_proof
      ; messages_for_next_wrap_proof
      ]

    let[@warning "-45"] of_data
        Hlist.HlistId.
          [ unfinalized_proofs
          ; messages_for_next_step_proof
          ; messages_for_next_wrap_proof
          ] =
      { proof_state =
          { unfinalized_proofs =
              Vector.map unfinalized_proofs
                ~f:Proof_state.Per_proof.In_circuit.of_data
          ; messages_for_next_step_proof
          }
      ; messages_for_next_wrap_proof
      }

    let spec proofs_verified bp_log2 =
      let per_proof = Proof_state.Per_proof.In_circuit.spec bp_log2 in
      Spec.T.Struct
        [ Vector (per_proof, proofs_verified)
        ; B Digest
        ; Vector (B Digest, proofs_verified)
        ]

    (** [to_data] / [of_data] / [spec] for the fresh
        [{Constant,Step,Wrap}.t] outer Statements. The flat-data output
        matches the toplevel [Step.Statement.{to_data, of_data, spec}],
        so [Spec]-driven typ construction stays interoperable. *)
    module Constant = struct
      let[@warning "-45"] to_data
          { proof_state = { unfinalized_proofs; messages_for_next_step_proof }
          ; messages_for_next_wrap_proof
          } =
        let open Hlist.HlistId in
        [ Vector.map unfinalized_proofs
            ~f:Proof_state.Per_proof.Constant.to_data
        ; messages_for_next_step_proof
        ; messages_for_next_wrap_proof
        ]

      let[@warning "-45"] of_data
          Hlist.HlistId.
            [ unfinalized_proofs
            ; messages_for_next_step_proof
            ; messages_for_next_wrap_proof
            ] =
        { proof_state =
            { unfinalized_proofs =
                Vector.map unfinalized_proofs
                  ~f:Proof_state.Per_proof.Constant.of_data
            ; messages_for_next_step_proof
            }
        ; messages_for_next_wrap_proof
        }

      let spec proofs_verified bp_log2 =
        let per_proof = Proof_state.Per_proof.Constant.spec bp_log2 in
        Spec.T.Struct
          [ Vector (per_proof, proofs_verified)
          ; B Digest
          ; Vector (B Digest, proofs_verified)
          ]
    end

    let _ : _ = (Constant.to_data, Constant.of_data, Constant.spec)

    module Step = struct
      let[@warning "-45"] to_data
          { proof_state = { unfinalized_proofs; messages_for_next_step_proof }
          ; messages_for_next_wrap_proof
          } =
        let open Hlist.HlistId in
        [ Vector.map unfinalized_proofs ~f:Proof_state.Per_proof.Step.to_data
        ; messages_for_next_step_proof
        ; messages_for_next_wrap_proof
        ]

      let[@warning "-45"] of_data
          Hlist.HlistId.
            [ unfinalized_proofs
            ; messages_for_next_step_proof
            ; messages_for_next_wrap_proof
            ] =
        { proof_state =
            { unfinalized_proofs =
                Vector.map unfinalized_proofs
                  ~f:Proof_state.Per_proof.Step.of_data
            ; messages_for_next_step_proof
            }
        ; messages_for_next_wrap_proof
        }

      let spec proofs_verified bp_log2 =
        let per_proof = Proof_state.Per_proof.Step.spec bp_log2 in
        Spec.T.Struct
          [ Vector (per_proof, proofs_verified)
          ; B Digest
          ; Vector (B Digest, proofs_verified)
          ]
    end

    let _ : _ = (Step.to_data, Step.of_data, Step.spec)

    module Wrap = struct
      let[@warning "-45"] to_data
          { proof_state = { unfinalized_proofs; messages_for_next_step_proof }
          ; messages_for_next_wrap_proof
          } =
        let open Hlist.HlistId in
        [ Vector.map unfinalized_proofs ~f:Proof_state.Per_proof.Wrap.to_data
        ; messages_for_next_step_proof
        ; messages_for_next_wrap_proof
        ]

      let[@warning "-45"] of_data
          Hlist.HlistId.
            [ unfinalized_proofs
            ; messages_for_next_step_proof
            ; messages_for_next_wrap_proof
            ] =
        { proof_state =
            { unfinalized_proofs =
                Vector.map unfinalized_proofs
                  ~f:Proof_state.Per_proof.Wrap.of_data
            ; messages_for_next_step_proof
            }
        ; messages_for_next_wrap_proof
        }

      let spec proofs_verified bp_log2 =
        let per_proof = Proof_state.Per_proof.Wrap.spec bp_log2 in
        Spec.T.Struct
          [ Vector (per_proof, proofs_verified)
          ; B Digest
          ; Vector (B Digest, proofs_verified)
          ]
    end

    let _ : _ = (Wrap.to_data, Wrap.of_data, Wrap.spec)
  end
end

module Nvector = Vector.With_length
module Wrap_bp_vec = Backend.Tock.Rounds_vector
module Step_bp_vec = Backend.Tick.Rounds_vector

module Challenges_vector = struct
  type 'n t = (Wrap_impl.Field.t Wrap_bp_vec.t, 'n) Vector.t

  module Constant = struct
    type 'n t = (Wrap_impl.Field.Constant.t Wrap_bp_vec.t, 'n) Vector.t
  end
end

(** Concrete (non-versioned) records mirroring
    [Pickles.Reduced_messages_for_next_proof_over_same_field].

    The versioned/[bin_io] type lives in
    [src/lib/crypto/pickles/reduced_messages_for_next_proof_over_same_field.ml].
    The records here are constrained equal to the corresponding
    [Mina_wire_types] skeleton so values flow freely between the two
    modules without conversion.

    Defining these records inside [Composition_types] lets consumers
    inline the [Step] / [Wrap] shapes directly instead of re-spelling
    them at every site. *)
