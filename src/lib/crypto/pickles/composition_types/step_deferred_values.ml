(** Step-circuit deferred-values record.

    Extracted from [Composition_types.Step.Proof_state.Deferred_values]
    so the per-concept hierarchy is one file per concept. *)

open Pickles_types
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
module Bulletproof_challenge = Bulletproof_challenge
open Core_kernel
module Step_impl = Kimchi_pasta_snarky_backend.Step_impl
module Wrap_impl = Kimchi_pasta_snarky_backend.Wrap_impl

module Plonk = Step_plonk_iop

(** All the scalar-field values needed to finalize the verification of a proof
    by checking that the correct values were used in the "group operations" part of the
    verifier.

    Consists of some evaluations of PLONK polynomials (columns, permutation aggregation, etc.)
    and the remainder are things related to the inner product argument.
*)
type ('plonk, 'scalar_challenge, 'fq, 'bulletproof_challenges) t_ =
  { plonk : 'plonk
  ; combined_inner_product : 'fq
        (** combined_inner_product = sum_{i < num_evaluation_points} sum_{j < num_polys} r^i xi^j f_j(pt_i) *)
  ; xi : 'scalar_challenge
        (** The challenge used for combining polynomials *)
  ; bulletproof_challenges : 'bulletproof_challenges
        (** The challenges from the inner-product argument that was partially verified. *)
  ; b : 'fq
        (** b = challenge_poly plonk.zeta + r * challenge_poly (domain_generrator * plonk.zeta)
          where challenge_poly(x) = \prod_i (1 + bulletproof_challenges.(i) * x^{2^{k - 1 - i}})
      *)
  }
[@@deriving sexp, compare, yojson]

module Minimal = struct
  type ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t =
    ( ('challenge, 'scalar_challenge) Plonk.Minimal.Poly.t
    , 'scalar_challenge
    , 'fq
    , 'bulletproof_challenges )
    t_
  [@@deriving sexp, compare, yojson]
end

module In_circuit = struct
  type ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t =
    ( ('challenge, 'scalar_challenge, 'fq) Plonk.In_circuit.t
    , 'scalar_challenge
    , 'fq
    , 'bulletproof_challenges )
    t_
  [@@deriving sexp, compare, yojson]
end

(** Wire-form (out-of-circuit) instantiation of {!t_}; ['plonk] and
    ['fq] are left polymorphic because callers pick from the
    Minimal/In_circuit Plonk submodules and between Type1/Type2
    Shifted_value forms. {!to_t_} / {!of_t_} bridge to the polymorphic
    skeleton. *)
module Constant = struct
  type ('plonk, 'fq) t =
    { plonk : 'plonk
    ; combined_inner_product : 'fq
    ; xi : Limb_vector.Challenge.Constant.t Scalar_challenge.t
    ; bulletproof_challenges :
        ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
          Bulletproof_challenge.t
        , Backend.Tock.Rounds.n )
        Vector.t
    ; b : 'fq
    }

  let to_t_
      ({ plonk; combined_inner_product; xi; bulletproof_challenges; b } :
        ('plonk, 'fq) t ) :
      ( 'plonk
      , Limb_vector.Challenge.Constant.t Scalar_challenge.t
      , 'fq
      , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
          Bulletproof_challenge.t
        , Backend.Tock.Rounds.n )
        Vector.t )
      t_ =
    { plonk; combined_inner_product; xi; bulletproof_challenges; b }

  let of_t_
      ({ plonk; combined_inner_product; xi; bulletproof_challenges; b } :
        ( 'plonk
        , Limb_vector.Challenge.Constant.t Scalar_challenge.t
        , 'fq
        , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
            Bulletproof_challenge.t
          , Backend.Tock.Rounds.n )
          Vector.t )
        t_ ) : ('plonk, 'fq) t =
    { plonk; combined_inner_product; xi; bulletproof_challenges; b }
end

let _ = fun (c : (_, _) Constant.t) -> Constant.of_t_ (Constant.to_t_ c)

(** Step-circuit (Tick) instantiation of {!t_}. *)
module Step = struct
  type ('plonk, 'fq) t =
    { plonk : 'plonk
    ; combined_inner_product : 'fq
    ; xi : Step_impl.Field.t Scalar_challenge.t
    ; bulletproof_challenges :
        ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
        , Backend.Tock.Rounds.n )
        Vector.t
    ; b : 'fq
    }

  let to_t_
      ({ plonk; combined_inner_product; xi; bulletproof_challenges; b } :
        ('plonk, 'fq) t ) :
      ( 'plonk
      , Step_impl.Field.t Scalar_challenge.t
      , 'fq
      , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
        , Backend.Tock.Rounds.n )
        Vector.t )
      t_ =
    { plonk; combined_inner_product; xi; bulletproof_challenges; b }

  let of_t_
      ({ plonk; combined_inner_product; xi; bulletproof_challenges; b } :
        ( 'plonk
        , Step_impl.Field.t Scalar_challenge.t
        , 'fq
        , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
          , Backend.Tock.Rounds.n )
          Vector.t )
        t_ ) : ('plonk, 'fq) t =
    { plonk; combined_inner_product; xi; bulletproof_challenges; b }
end

let _ = fun (s : (_, _) Step.t) -> Step.of_t_ (Step.to_t_ s)

(** Wrap-circuit (Tock) instantiation of {!t_}. *)
module Wrap = struct
  type ('plonk, 'fq) t =
    { plonk : 'plonk
    ; combined_inner_product : 'fq
    ; xi : Wrap_impl.Field.t Scalar_challenge.t
    ; bulletproof_challenges :
        ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
        , Backend.Tock.Rounds.n )
        Vector.t
    ; b : 'fq
    }

  let to_t_
      ({ plonk; combined_inner_product; xi; bulletproof_challenges; b } :
        ('plonk, 'fq) t ) :
      ( 'plonk
      , Wrap_impl.Field.t Scalar_challenge.t
      , 'fq
      , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
        , Backend.Tock.Rounds.n )
        Vector.t )
      t_ =
    { plonk; combined_inner_product; xi; bulletproof_challenges; b }

  let of_t_
      ({ plonk; combined_inner_product; xi; bulletproof_challenges; b } :
        ( 'plonk
        , Wrap_impl.Field.t Scalar_challenge.t
        , 'fq
        , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
          , Backend.Tock.Rounds.n )
          Vector.t )
        t_ ) : ('plonk, 'fq) t =
    { plonk; combined_inner_product; xi; bulletproof_challenges; b }
end

let _ = fun (w : (_, _) Wrap.t) -> Wrap.of_t_ (Wrap.to_t_ w)
