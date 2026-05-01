(** Wrap-circuit PLONK IOP challenge records.

    Extracted from [Composition_types.Wrap.Proof_state.Deferred_values.Plonk]
    so the per-concept hierarchy is one file per concept. The wire-format
    skeleton lives in {!Wire.Wrap.Proof_state.Deferred_values.Plonk}. *)

open Pickles_types
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
open Core_kernel
module Step_impl = Kimchi_pasta_snarky_backend.Step_impl
module Wrap_impl = Kimchi_pasta_snarky_backend.Wrap_impl

  module Minimal = struct
    (** Challenges from the PLONK IOP. These, plus the evaluations that are already in the proof, are
        all that's needed to derive all the values in the [In_circuit] version below.

        See src/lib/pickles/plonk_checks/plonk_checks.ml for the computation of the [In_circuit] value
        from the [Minimal] value.
    *)
    include Wire.Wrap.Proof_state.Deferred_values.Plonk.Minimal

    (** Wire-format polymorphic skeleton. Concrete records below name it
        explicitly via {!Poly} rather than [include]ing it. *)
    module Poly = Wire.Wrap.Proof_state.Deferred_values.Plonk.Minimal

    (** Wire-form (out-of-circuit) instantiation. {!to_stable} /
        {!of_stable} bridge to the [Mina_wire_types]-constrained
        polymorphic skeleton in {!Stable.V1.t}. *)
    module Constant = struct
      type t =
        { alpha : Limb_vector.Challenge.Constant.t Scalar_challenge.t
        ; beta : Limb_vector.Challenge.Constant.t
        ; gamma : Limb_vector.Challenge.Constant.t
        ; zeta : Limb_vector.Challenge.Constant.t Scalar_challenge.t
        ; joint_combiner :
            Limb_vector.Challenge.Constant.t Scalar_challenge.t option
        ; feature_flags : bool Plonk_types.Features.t
        }
      [@@deriving sexp, compare, yojson, hlist, hash, equal]

      let to_stable
          ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
            t ) :
          ( Limb_vector.Challenge.Constant.t
          , Limb_vector.Challenge.Constant.t Scalar_challenge.t
          , bool )
          Poly.t =
        { alpha; beta; gamma; zeta; joint_combiner; feature_flags }

      let of_stable
          ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
            ( Limb_vector.Challenge.Constant.t
            , Limb_vector.Challenge.Constant.t Scalar_challenge.t
            , bool )
            Poly.t ) : t =
        { alpha; beta; gamma; zeta; joint_combiner; feature_flags }
    end

    (** Round-trip witness anchoring {!Constant} against {!Poly} until
        downstream consumers are migrated to the fresh record. *)
    let _ = fun (c : Constant.t) ->
      Constant.of_stable (Constant.to_stable c)

    let map_challenges t ~f ~scalar =
      { t with
        alpha = scalar t.alpha
      ; beta = f t.beta
      ; gamma = f t.gamma
      ; zeta = scalar t.zeta
      ; joint_combiner = Option.map ~f:scalar t.joint_combiner
      }

    module In_circuit = struct
      type ('challenge, 'scalar_challenge, 'bool) t =
        { alpha : 'scalar_challenge
        ; beta : 'challenge
        ; gamma : 'challenge
        ; zeta : 'scalar_challenge
        ; joint_combiner : ('scalar_challenge, 'bool) Opt.t
        ; feature_flags : 'bool Plonk_types.Features.t
        }
    end

    (** Step-circuit (Tick) instantiation of {!In_circuit.t}: the shape
        used when the Step verifier constructs Plonk-IOP challenges
        in-circuit. {!to_in_circuit} bridges to the polymorphic
        {!In_circuit.t}. *)
    module Step = struct
      type t =
        { alpha : Step_impl.Field.t Scalar_challenge.t
        ; beta : Step_impl.Field.t
        ; gamma : Step_impl.Field.t
        ; zeta : Step_impl.Field.t Scalar_challenge.t
        ; joint_combiner :
            (Step_impl.Field.t Scalar_challenge.t, Step_impl.Boolean.var) Opt.t
        ; feature_flags : Step_impl.Boolean.var Plonk_types.Features.t
        }

      let to_in_circuit
          ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
            t ) :
          ( Step_impl.Field.t
          , Step_impl.Field.t Scalar_challenge.t
          , Step_impl.Boolean.var )
          In_circuit.t =
        { alpha; beta; gamma; zeta; joint_combiner; feature_flags }

      let of_in_circuit
          ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
            ( Step_impl.Field.t
            , Step_impl.Field.t Scalar_challenge.t
            , Step_impl.Boolean.var )
            In_circuit.t ) : t =
        { alpha; beta; gamma; zeta; joint_combiner; feature_flags }
    end

    (** Round-trip witness anchoring {!Step} against {!In_circuit} until
        downstream consumers are migrated to the fresh record. *)
    let _ = fun (s : Step.t) -> Step.of_in_circuit (Step.to_in_circuit s)

    (** Wrap-circuit (Tock) instantiation of {!In_circuit.t}.

        Sibling of {!Step}, used when the Wrap verifier constructs
        Plonk-IOP challenges in-circuit. Fresh record; see {!Step} for
        the rationale. *)
    module Wrap = struct
      type t =
        { alpha : Wrap_impl.Field.t Scalar_challenge.t
        ; beta : Wrap_impl.Field.t
        ; gamma : Wrap_impl.Field.t
        ; zeta : Wrap_impl.Field.t Scalar_challenge.t
        ; joint_combiner :
            (Wrap_impl.Field.t Scalar_challenge.t, Wrap_impl.Boolean.var) Opt.t
        ; feature_flags : Wrap_impl.Boolean.var Plonk_types.Features.t
        }

      let to_in_circuit
          ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
            t ) :
          ( Wrap_impl.Field.t
          , Wrap_impl.Field.t Scalar_challenge.t
          , Wrap_impl.Boolean.var )
          In_circuit.t =
        { alpha; beta; gamma; zeta; joint_combiner; feature_flags }

      let of_in_circuit
          ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
            ( Wrap_impl.Field.t
            , Wrap_impl.Field.t Scalar_challenge.t
            , Wrap_impl.Boolean.var )
            In_circuit.t ) : t =
        { alpha; beta; gamma; zeta; joint_combiner; feature_flags }
    end

    (** Round-trip witness anchoring {!Wrap} against {!In_circuit} until
        downstream consumers are migrated to the fresh record. *)
    let _ = fun (w : Wrap.t) -> Wrap.of_in_circuit (Wrap.to_in_circuit w)

    (** Endo'd Tick-field instantiation of {!Stable.V1.t}.

        The prover, after running scalar challenges through
        {!Scalar_challenge.to_field_constant}, holds a Plonk.Minimal
        record where every field is a plain [Tick.Field.t] — i.e.
        both ['challenge] and ['scalar_challenge] are collapsed to
        [Tick.Field.t]. This is the shape consumed by
        {!Plonk_checks.scalars_env} when the prover prepares a wrap
        proof's deferred values for verification. {!to_stable} /
        {!of_stable} bridge to the wire-format polymorphic skeleton. *)
    module Tick = struct
      type t =
        { alpha : Backend.Tick.Field.t
        ; beta : Backend.Tick.Field.t
        ; gamma : Backend.Tick.Field.t
        ; zeta : Backend.Tick.Field.t
        ; joint_combiner : Backend.Tick.Field.t option
        ; feature_flags : bool Plonk_types.Features.t
        }
      [@@deriving sexp, compare, yojson, hlist, hash, equal]

      (** [Poly.t] specialised to [Tick] field elements — the result
          type of {!to_stable}, also the canonical shape consumed by
          [Wrap.combined_inner_product]. *)
      type poly_t = (Backend.Tick.Field.t, Backend.Tick.Field.t, bool) Poly.t

      let to_stable
          ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
            t ) : poly_t =
        { alpha; beta; gamma; zeta; joint_combiner; feature_flags }

      let of_stable
          ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
            poly_t ) : t =
        { alpha; beta; gamma; zeta; joint_combiner; feature_flags }
    end

    (** Round-trip witness anchoring {!Tick} against {!Poly} until
        downstream consumers are migrated to the fresh record. *)
    let _ = fun (t : Tick.t) -> Tick.of_stable (Tick.to_stable t)

    (** Endo'd Tock-field counterpart of {!Tick}: the shape used when
        the prover prepares a step proof's deferred values for
        verification (e.g. dummy unfinalized values). {!to_stable} /
        {!of_stable} bridge to the wire-format polymorphic skeleton. *)
    module Tock = struct
      type t =
        { alpha : Backend.Tock.Field.t
        ; beta : Backend.Tock.Field.t
        ; gamma : Backend.Tock.Field.t
        ; zeta : Backend.Tock.Field.t
        ; joint_combiner : Backend.Tock.Field.t option
        ; feature_flags : bool Plonk_types.Features.t
        }
      [@@deriving sexp, compare, yojson, hlist, hash, equal]

      let to_stable
          ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
            t ) :
          (Backend.Tock.Field.t, Backend.Tock.Field.t, bool) Poly.t =
        { alpha; beta; gamma; zeta; joint_combiner; feature_flags }

      let of_stable
          ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
            (Backend.Tock.Field.t, Backend.Tock.Field.t, bool) Poly.t ) :
          t =
        { alpha; beta; gamma; zeta; joint_combiner; feature_flags }
    end

    (** Round-trip witness anchoring {!Tock} against {!Poly} until
        downstream consumers are migrated to the fresh record. *)
    let _ = fun (t : Tock.t) -> Tock.of_stable (Tock.to_stable t)
  end

  open Pickles_types

  module In_circuit = struct
    [@@@warning "-27"]

    (* 'fp_opt is unused but kept for type compatibility with other
       In_circuit types. We suppress the warning instead of using a
       phantom type to preserve the serialization format. *)

    (** All scalar values deferred by a verifier circuit.
        We expose them so the next guy (who can do scalar arithmetic) can check that they
        were computed correctly from the evaluations in the proof and the challenges.
    *)
    type ( 'challenge
         , 'scalar_challenge
         , 'fp
         , 'fp_opt
         , 'scalar_challenge_opt
         , 'bool )
         t =
      { alpha : 'scalar_challenge
      ; beta : 'challenge
      ; gamma : 'challenge
      ; zeta : 'scalar_challenge
            (* TODO: zeta_to_srs_length is kind of unnecessary.
               Try to get rid of it when you can.
            *)
      ; zeta_to_srs_length : 'fp
      ; zeta_to_domain_size : 'fp
      ; perm : 'fp
            (** scalar used on one of the permutation polynomial commitments. *)
      ; feature_flags : 'bool Plonk_types.Features.t
      ; joint_combiner : 'scalar_challenge_opt
      }
    [@@deriving sexp, compare, yojson, hlist, hash, equal, fields]

    let map_challenges t ~f ~scalar =
      { t with
        alpha = scalar t.alpha
      ; beta = f t.beta
      ; gamma = f t.gamma
      ; joint_combiner = Opt.map ~f:scalar t.joint_combiner
      ; zeta = scalar t.zeta
      }

    let map_fields t ~f =
      { t with
        zeta_to_srs_length = f t.zeta_to_srs_length
      ; zeta_to_domain_size = f t.zeta_to_domain_size
      ; perm = f t.perm
      }

    let typ (type fp) ~dummy_scalar_challenge ~challenge ~scalar_challenge
        ~bool
        ~feature_flags:
          ({ Plonk_types.Features.Full.uses_lookups; _ } as feature_flags)
        (fp : (fp, _) Step_impl.Typ.t) =
      Step_impl.Typ.of_hlistable
        [ Scalar_challenge.typ scalar_challenge
        ; challenge
        ; challenge
        ; Scalar_challenge.typ scalar_challenge
        ; fp
        ; fp
        ; fp
        ; Plonk_types.Features.typ
            ~feature_flags:(Plonk_types.Features.of_full feature_flags)
            bool
        ; Opt.typ uses_lookups ~dummy:dummy_scalar_challenge
            (Scalar_challenge.typ scalar_challenge)
        ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

    (* A sibling alias for [t] so that the concrete submodules below
       can name it without colliding with their own [t]; OCaml does
       not let the [In_circuit] module reference itself by name from
       inside its own definition. *)
    type ('a, 'b, 'c, 'd, 'e, 'f) in_circuit_t =
      ('a, 'b, 'c, 'd, 'e, 'f) t

    (** Wire-form (out-of-circuit) instantiation of {!t}.

        ['fp] left polymorphic because the constant-side scalars are
        passed around in either [_ Shifted_value.Type1.t] or
        [_ Shifted_value.Type2.t] depending on which curve's deferred
        values they describe. The ['fp_opt] phantom from the
        polymorphic {!t} is dropped (no field uses it);
        {!to_in_circuit} can produce a value at any ['fp_opt]. *)
    module Constant = struct
      type 'fp t =
        { alpha : Limb_vector.Challenge.Constant.t Scalar_challenge.t
        ; beta : Limb_vector.Challenge.Constant.t
        ; gamma : Limb_vector.Challenge.Constant.t
        ; zeta : Limb_vector.Challenge.Constant.t Scalar_challenge.t
        ; zeta_to_srs_length : 'fp
        ; zeta_to_domain_size : 'fp
        ; perm : 'fp
        ; feature_flags : bool Plonk_types.Features.t
        ; joint_combiner :
            Limb_vector.Challenge.Constant.t Scalar_challenge.t option
        }

      let to_in_circuit
          ({ alpha
           ; beta
           ; gamma
           ; zeta
           ; zeta_to_srs_length
           ; zeta_to_domain_size
           ; perm
           ; feature_flags
           ; joint_combiner
           } :
            'fp t ) :
          ( Limb_vector.Challenge.Constant.t
          , Limb_vector.Challenge.Constant.t Scalar_challenge.t
          , 'fp
          , _
          , Limb_vector.Challenge.Constant.t Scalar_challenge.t option
          , bool )
          in_circuit_t =
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

      let of_in_circuit
          ({ alpha
           ; beta
           ; gamma
           ; zeta
           ; zeta_to_srs_length
           ; zeta_to_domain_size
           ; perm
           ; feature_flags
           ; joint_combiner
           } :
            ( Limb_vector.Challenge.Constant.t
            , Limb_vector.Challenge.Constant.t Scalar_challenge.t
            , 'fp
            , _
            , Limb_vector.Challenge.Constant.t Scalar_challenge.t option
            , bool )
            in_circuit_t ) : 'fp t =
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
    end

    let _ = fun (c : _ Constant.t) ->
      Constant.of_in_circuit (Constant.to_in_circuit c)

    (** Out-of-circuit instantiation of {!t} with [Opt.t]-with-[bool]
        optionality (rather than [option] as in {!Constant}). Fresh
        record. Consumed by [Wrap.For_tests_only.deferred_values]
        (and the main [wrap] function it underpins) — derived
        directly from [Plonk_checks.Type1.derive_plonk]'s output,
        which threads ['scalar_challenge_opt] as
        [(_, 'b) Pickles_types.Opt.t] regardless of whether ['b] is
        [bool] or a Snarky [Boolean.var]. *)
    module Constant_opt = struct
      type 'fp t =
        { alpha : Limb_vector.Challenge.Constant.t Scalar_challenge.t
        ; beta : Limb_vector.Challenge.Constant.t
        ; gamma : Limb_vector.Challenge.Constant.t
        ; zeta : Limb_vector.Challenge.Constant.t Scalar_challenge.t
        ; zeta_to_srs_length : 'fp
        ; zeta_to_domain_size : 'fp
        ; perm : 'fp
        ; feature_flags : bool Plonk_types.Features.t
        ; joint_combiner :
            (Limb_vector.Challenge.Constant.t Scalar_challenge.t, bool) Opt.t
        }

      let to_in_circuit
          ({ alpha
           ; beta
           ; gamma
           ; zeta
           ; zeta_to_srs_length
           ; zeta_to_domain_size
           ; perm
           ; feature_flags
           ; joint_combiner
           } :
            'fp t ) :
          ( Limb_vector.Challenge.Constant.t
          , Limb_vector.Challenge.Constant.t Scalar_challenge.t
          , 'fp
          , _
          , (Limb_vector.Challenge.Constant.t Scalar_challenge.t, bool) Opt.t
          , bool )
          in_circuit_t =
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

      let of_in_circuit
          ({ alpha
           ; beta
           ; gamma
           ; zeta
           ; zeta_to_srs_length
           ; zeta_to_domain_size
           ; perm
           ; feature_flags
           ; joint_combiner
           } :
            ( Limb_vector.Challenge.Constant.t
            , Limb_vector.Challenge.Constant.t Scalar_challenge.t
            , 'fp
            , _
            , (Limb_vector.Challenge.Constant.t Scalar_challenge.t, bool) Opt.t
            , bool )
            in_circuit_t ) : 'fp t =
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
    end

    let _ = fun (c : _ Constant_opt.t) ->
      Constant_opt.of_in_circuit (Constant_opt.to_in_circuit c)

    (** Step-circuit (Tick) instantiation of {!t}.

        The Step verifier's in-circuit Plonk record; ['fp] is left
        polymorphic for the same reason described in {!Constant}. *)
    module Step = struct
      type 'fp t =
        { alpha : Step_impl.Field.t Scalar_challenge.t
        ; beta : Step_impl.Field.t
        ; gamma : Step_impl.Field.t
        ; zeta : Step_impl.Field.t Scalar_challenge.t
        ; zeta_to_srs_length : 'fp
        ; zeta_to_domain_size : 'fp
        ; perm : 'fp
        ; feature_flags : Step_impl.Boolean.var Plonk_types.Features.t
        ; joint_combiner :
            (Step_impl.Field.t Scalar_challenge.t, Step_impl.Boolean.var) Opt.t
        }

      let to_in_circuit
          ({ alpha
           ; beta
           ; gamma
           ; zeta
           ; zeta_to_srs_length
           ; zeta_to_domain_size
           ; perm
           ; feature_flags
           ; joint_combiner
           } :
            'fp t ) :
          ( Step_impl.Field.t
          , Step_impl.Field.t Scalar_challenge.t
          , 'fp
          , _
          , (Step_impl.Field.t Scalar_challenge.t, Step_impl.Boolean.var) Opt.t
          , Step_impl.Boolean.var )
          in_circuit_t =
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

      let of_in_circuit
          ({ alpha
           ; beta
           ; gamma
           ; zeta
           ; zeta_to_srs_length
           ; zeta_to_domain_size
           ; perm
           ; feature_flags
           ; joint_combiner
           } :
            ( Step_impl.Field.t
            , Step_impl.Field.t Scalar_challenge.t
            , 'fp
            , _
            , (Step_impl.Field.t Scalar_challenge.t, Step_impl.Boolean.var) Opt.t
            , Step_impl.Boolean.var )
            in_circuit_t ) : 'fp t =
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
    end

    let _ = fun (s : _ Step.t) ->
      Step.of_in_circuit (Step.to_in_circuit s)

    (** Wrap-circuit (Tock) instantiation of {!t}. Sibling of
        {!Step}. *)
    module Wrap = struct
      type 'fp t =
        { alpha : Wrap_impl.Field.t Scalar_challenge.t
        ; beta : Wrap_impl.Field.t
        ; gamma : Wrap_impl.Field.t
        ; zeta : Wrap_impl.Field.t Scalar_challenge.t
        ; zeta_to_srs_length : 'fp
        ; zeta_to_domain_size : 'fp
        ; perm : 'fp
        ; feature_flags : Wrap_impl.Boolean.var Plonk_types.Features.t
        ; joint_combiner :
            (Wrap_impl.Field.t Scalar_challenge.t, Wrap_impl.Boolean.var) Opt.t
        }

      let to_in_circuit
          ({ alpha
           ; beta
           ; gamma
           ; zeta
           ; zeta_to_srs_length
           ; zeta_to_domain_size
           ; perm
           ; feature_flags
           ; joint_combiner
           } :
            'fp t ) :
          ( Wrap_impl.Field.t
          , Wrap_impl.Field.t Scalar_challenge.t
          , 'fp
          , _
          , (Wrap_impl.Field.t Scalar_challenge.t, Wrap_impl.Boolean.var) Opt.t
          , Wrap_impl.Boolean.var )
          in_circuit_t =
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

      let of_in_circuit
          ({ alpha
           ; beta
           ; gamma
           ; zeta
           ; zeta_to_srs_length
           ; zeta_to_domain_size
           ; perm
           ; feature_flags
           ; joint_combiner
           } :
            ( Wrap_impl.Field.t
            , Wrap_impl.Field.t Scalar_challenge.t
            , 'fp
            , _
            , (Wrap_impl.Field.t Scalar_challenge.t, Wrap_impl.Boolean.var) Opt.t
            , Wrap_impl.Boolean.var )
            in_circuit_t ) : 'fp t =
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
    end

    let _ = fun (w : _ Wrap.t) ->
      Wrap.of_in_circuit (Wrap.to_in_circuit w)
  end

  let to_minimal (type challenge scalar_challenge fp fp_opt lookup_opt)
      (t :
        ( challenge
        , scalar_challenge
        , fp
        , fp_opt
        , lookup_opt
        , 'bool )
        In_circuit.t ) ~(to_option : lookup_opt -> scalar_challenge option)
      : (challenge, scalar_challenge, 'bool) Minimal.Poly.t =
  { alpha = t.alpha
  ; beta = t.beta
  ; zeta = t.zeta
  ; gamma = t.gamma
  ; joint_combiner = to_option t.joint_combiner
  ; feature_flags = t.feature_flags
  }
