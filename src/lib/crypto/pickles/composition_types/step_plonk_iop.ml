(** Step-circuit PLONK IOP challenge records.

    Extracted from [Composition_types.Step.Proof_state.Deferred_values.Plonk]
    so the per-concept hierarchy is one file per concept. The wire-format
    skeleton lives in {!Wire.Step.Proof_state.Deferred_values.Plonk}. *)

module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
open Core_kernel
module Step_impl = Kimchi_pasta_snarky_backend.Step_impl
module Wrap_impl = Kimchi_pasta_snarky_backend.Wrap_impl

module Minimal = struct
  (** Challenges from the PLONK IOP. These, plus the evaluations
      that are already in the proof, are all that's needed to
      derive all the values in the [In_circuit] version below.
      See src/lib/pickles/plonk_checks/plonk_checks.ml for the
      computation of the [In_circuit] value from the [Minimal]
      value. *)

  (** Wire-format polymorphic skeleton. Concrete records below
      name it explicitly via {!Poly} rather than [include]ing it. *)
  module Poly = Wire.Step.Proof_state.Deferred_values.Plonk.Minimal

  (** Wire-form (out-of-circuit) instantiation of {!t}. The
      [Step.Proof_state] tree is for step proofs (Vesta/Tick
      curve), whose challenges live in the Tock field; out of
      circuit those challenges are carried in the
      [Limb_vector.Challenge.Constant] form. *)
  module Constant = struct
    type t =
      { alpha : Limb_vector.Challenge.Constant.t Scalar_challenge.t
      ; beta : Limb_vector.Challenge.Constant.t
      ; gamma : Limb_vector.Challenge.Constant.t
      ; zeta : Limb_vector.Challenge.Constant.t Scalar_challenge.t
      }
    [@@deriving sexp, compare, yojson, hlist, hash, equal]

    let to_minimal ({ alpha; beta; gamma; zeta } : t) :
        ( Limb_vector.Challenge.Constant.t
        , Limb_vector.Challenge.Constant.t Scalar_challenge.t )
        Poly.t =
      { alpha; beta; gamma; zeta }

    let of_minimal
        ({ alpha; beta; gamma; zeta } :
          ( Limb_vector.Challenge.Constant.t
          , Limb_vector.Challenge.Constant.t Scalar_challenge.t )
          Poly.t ) : t =
      { alpha; beta; gamma; zeta }
  end

  (** Step-circuit (Tick) instantiation of {!t}.

      Fresh record; see {!Constant} for the rationale. Used when
      the Step verifier handles step proof challenges
      in-circuit. *)
  module Step = struct
    type t =
      { alpha : Step_impl.Field.t Scalar_challenge.t
      ; beta : Step_impl.Field.t
      ; gamma : Step_impl.Field.t
      ; zeta : Step_impl.Field.t Scalar_challenge.t
      }

    let to_minimal ({ alpha; beta; gamma; zeta } : t) :
        (Step_impl.Field.t, Step_impl.Field.t Scalar_challenge.t) Poly.t =
      { alpha; beta; gamma; zeta }

    let of_minimal
        ({ alpha; beta; gamma; zeta } :
          (Step_impl.Field.t, Step_impl.Field.t Scalar_challenge.t) Poly.t ) : t
        =
      { alpha; beta; gamma; zeta }
  end

  (** Wrap-circuit (Tock) instantiation of {!t}. *)
  module Wrap = struct
    type t =
      { alpha : Wrap_impl.Field.t Scalar_challenge.t
      ; beta : Wrap_impl.Field.t
      ; gamma : Wrap_impl.Field.t
      ; zeta : Wrap_impl.Field.t Scalar_challenge.t
      }

    let to_minimal ({ alpha; beta; gamma; zeta } : t) :
        (Wrap_impl.Field.t, Wrap_impl.Field.t Scalar_challenge.t) Poly.t =
      { alpha; beta; gamma; zeta }

    let of_minimal
        ({ alpha; beta; gamma; zeta } :
          (Wrap_impl.Field.t, Wrap_impl.Field.t Scalar_challenge.t) Poly.t ) : t
        =
      { alpha; beta; gamma; zeta }
  end
end

module In_circuit = struct
  (** All scalar values deferred by a verifier circuit.
      The values in [vbmul], [complete_add], [endomul], [endomul_scalar], and [perm]
      are all scalars which will have been used to scale selector polynomials during the
      computation of the linearized polynomial commitment.

      Then, we expose them so the next guy (who can do scalar arithmetic) can check that they
      were computed correctly from the evaluations in the proof and the challenges.
  *)
  type ('challenge, 'scalar_challenge, 'fp) t =
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
    }
  [@@deriving sexp, compare, yojson, hlist, hash, equal, fields]

  let map_challenges t ~f ~scalar =
    { t with
      alpha = scalar t.alpha
    ; beta = f t.beta
    ; gamma = f t.gamma
    ; zeta = scalar t.zeta
    }

  let map_fields t ~f =
    { t with
      zeta_to_srs_length = f t.zeta_to_srs_length
    ; zeta_to_domain_size = f t.zeta_to_domain_size
    ; perm = f t.perm
    }

  (* Alias for [t] so concrete submodules below can name it
     without colliding with their own [t]. *)
  type ('a, 'b, 'c) in_circuit_t = ('a, 'b, 'c) t

  (** Wire-form (out-of-circuit) instantiation of {!t}; ['fp]
      is left polymorphic because the constant scalar slot may
      carry either [_ Shifted_value.Type1.t] or
      [_ Shifted_value.Type2.t] depending on which curve's
      deferred values are being described. {!to_in_circuit} /
      {!of_in_circuit} bridge to the polymorphic skeleton. *)
  module Constant = struct
    type 'fp t =
      { alpha : Limb_vector.Challenge.Constant.t Scalar_challenge.t
      ; beta : Limb_vector.Challenge.Constant.t
      ; gamma : Limb_vector.Challenge.Constant.t
      ; zeta : Limb_vector.Challenge.Constant.t Scalar_challenge.t
      ; zeta_to_srs_length : 'fp
      ; zeta_to_domain_size : 'fp
      ; perm : 'fp
      }

    let to_in_circuit
        ({ alpha
         ; beta
         ; gamma
         ; zeta
         ; zeta_to_srs_length
         ; zeta_to_domain_size
         ; perm
         } :
          'fp t ) :
        ( Limb_vector.Challenge.Constant.t
        , Limb_vector.Challenge.Constant.t Scalar_challenge.t
        , 'fp )
        in_circuit_t =
      { alpha
      ; beta
      ; gamma
      ; zeta
      ; zeta_to_srs_length
      ; zeta_to_domain_size
      ; perm
      }

    let of_in_circuit
        ({ alpha
         ; beta
         ; gamma
         ; zeta
         ; zeta_to_srs_length
         ; zeta_to_domain_size
         ; perm
         } :
          ( Limb_vector.Challenge.Constant.t
          , Limb_vector.Challenge.Constant.t Scalar_challenge.t
          , 'fp )
          in_circuit_t ) : 'fp t =
      { alpha
      ; beta
      ; gamma
      ; zeta
      ; zeta_to_srs_length
      ; zeta_to_domain_size
      ; perm
      }
  end

  (** Step-circuit (Tick) instantiation of {!t}. *)
  module Step = struct
    type 'fp t =
      { alpha : Step_impl.Field.t Scalar_challenge.t
      ; beta : Step_impl.Field.t
      ; gamma : Step_impl.Field.t
      ; zeta : Step_impl.Field.t Scalar_challenge.t
      ; zeta_to_srs_length : 'fp
      ; zeta_to_domain_size : 'fp
      ; perm : 'fp
      }

    let to_in_circuit
        ({ alpha
         ; beta
         ; gamma
         ; zeta
         ; zeta_to_srs_length
         ; zeta_to_domain_size
         ; perm
         } :
          'fp t ) :
        ( Step_impl.Field.t
        , Step_impl.Field.t Scalar_challenge.t
        , 'fp )
        in_circuit_t =
      { alpha
      ; beta
      ; gamma
      ; zeta
      ; zeta_to_srs_length
      ; zeta_to_domain_size
      ; perm
      }

    let of_in_circuit
        ({ alpha
         ; beta
         ; gamma
         ; zeta
         ; zeta_to_srs_length
         ; zeta_to_domain_size
         ; perm
         } :
          ( Step_impl.Field.t
          , Step_impl.Field.t Scalar_challenge.t
          , 'fp )
          in_circuit_t ) : 'fp t =
      { alpha
      ; beta
      ; gamma
      ; zeta
      ; zeta_to_srs_length
      ; zeta_to_domain_size
      ; perm
      }
  end

  (** Wrap-circuit (Tock) instantiation of {!t}. *)
  module Wrap = struct
    type 'fp t =
      { alpha : Wrap_impl.Field.t Scalar_challenge.t
      ; beta : Wrap_impl.Field.t
      ; gamma : Wrap_impl.Field.t
      ; zeta : Wrap_impl.Field.t Scalar_challenge.t
      ; zeta_to_srs_length : 'fp
      ; zeta_to_domain_size : 'fp
      ; perm : 'fp
      }

    let to_in_circuit
        ({ alpha
         ; beta
         ; gamma
         ; zeta
         ; zeta_to_srs_length
         ; zeta_to_domain_size
         ; perm
         } :
          'fp t ) :
        ( Wrap_impl.Field.t
        , Wrap_impl.Field.t Scalar_challenge.t
        , 'fp )
        in_circuit_t =
      { alpha
      ; beta
      ; gamma
      ; zeta
      ; zeta_to_srs_length
      ; zeta_to_domain_size
      ; perm
      }

    let of_in_circuit
        ({ alpha
         ; beta
         ; gamma
         ; zeta
         ; zeta_to_srs_length
         ; zeta_to_domain_size
         ; perm
         } :
          ( Wrap_impl.Field.t
          , Wrap_impl.Field.t Scalar_challenge.t
          , 'fp )
          in_circuit_t ) : 'fp t =
      { alpha
      ; beta
      ; gamma
      ; zeta
      ; zeta_to_srs_length
      ; zeta_to_domain_size
      ; perm
      }
  end
end

let to_minimal (type challenge scalar_challenge fp)
    (t : (challenge, scalar_challenge, fp) In_circuit.t) :
    (challenge, scalar_challenge) Minimal.Poly.t =
  { alpha = t.alpha; beta = t.beta; zeta = t.zeta; gamma = t.gamma }
