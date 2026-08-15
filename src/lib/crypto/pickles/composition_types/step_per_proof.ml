(** Step-circuit per-proof record.

    Extracted from [Composition_types.Step.Proof_state.Per_proof]. *)

open Pickles_types
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
module Bulletproof_challenge = Bulletproof_challenge
module Branch_data = Branch_data
module Digest = Digest
module Spec = Spec
open Core_kernel
module Step_impl = Kimchi_pasta_snarky_backend.Step_impl
module Wrap_impl = Kimchi_pasta_snarky_backend.Wrap_impl
module Deferred_values = Step_deferred_values

(** For each proof that a step circuit verifies, we do not verify the whole proof.
    Specifically,
    - we defer calculations involving the "other field" (i.e., the scalar-field of the group
      elements involved in the proof.
    - we do not fully verify the inner-product argument as that would be O(n) and instead
      do the accumulator trick.

    As a result, for each proof that a step circuit verifies, we must expose some data
    related to it as part of the step circuit's statement, in order to allow those proofs
    to be fully verified eventually.

    This is that data. *)
type ( 'plonk
     , 'scalar_challenge
     , 'fq
     , 'bulletproof_challenges
     , 'digest
     , 'bool )
     t_ =
  { deferred_values :
      ( 'plonk
      , 'scalar_challenge
      , 'fq
      , 'bulletproof_challenges )
      Deferred_values.t_
        (** Scalar values related to the proof *)
  ; should_finalize : 'bool
        (** We allow circuits in pickles proof systems to decide if it's OK that a proof did
    not recursively verify. In that case, when we expose the unfinalized bits, we need
    to communicate that it's OK if those bits do not "finalize". That's what this boolean
    is for. *)
  ; sponge_digest_before_evaluations : 'digest
  }
[@@deriving sexp, compare, yojson]

module Minimal = struct
  type ( 'challenge
       , 'scalar_challenge
       , 'fq
       , 'bulletproof_challenges
       , 'digest
       , 'bool )
       t =
    ( ('challenge, 'scalar_challenge) Deferred_values.Plonk.Minimal.Poly.t
    , 'scalar_challenge
    , 'fq
    , 'bulletproof_challenges
    , 'digest
    , 'bool )
    t_
  [@@deriving sexp, compare, yojson]
end

module In_circuit = struct
  type ( 'challenge
       , 'scalar_challenge
       , 'fq
       , 'bulletproof_challenges
       , 'digest
       , 'bool )
       t =
    ( ('challenge, 'scalar_challenge, 'fq) Deferred_values.Plonk.In_circuit.t
    , 'scalar_challenge
    , 'fq
    , 'bulletproof_challenges
    , 'digest
    , 'bool )
    t_
  [@@deriving sexp, compare, yojson]

  (** A layout of the raw data in this value, which is needed for
    representing it inside the circuit. *)
  let spec bp_log2 =
    Spec.T.Struct
      [ Vector (B Field, Nat.N5.n)
      ; Vector (B Digest, Nat.N1.n)
      ; Vector (B Challenge, Nat.N2.n)
      ; Vector (Scalar Challenge, Nat.N3.n)
      ; Vector (B Bulletproof_challenge, bp_log2)
      ; Vector (B Bool, Nat.N1.n)
      ]

  let[@warning "-45"] to_data
      ({ deferred_values =
           { xi
           ; bulletproof_challenges
           ; b
           ; combined_inner_product
           ; plonk =
               { alpha
               ; beta
               ; gamma
               ; zeta
               ; zeta_to_srs_length
               ; zeta_to_domain_size
               ; perm
               }
           }
       ; should_finalize
       ; sponge_digest_before_evaluations
       } :
        _ t ) =
    let open Vector in
    let fq =
      [ combined_inner_product
      ; b
      ; zeta_to_srs_length
      ; zeta_to_domain_size
      ; perm
      ]
    in
    let challenge = [ beta; gamma ] in
    let scalar_challenge = [ alpha; zeta; xi ] in
    let digest = [ sponge_digest_before_evaluations ] in
    let bool = [ should_finalize ] in
    let open Hlist.HlistId in
    [ fq; digest; challenge; scalar_challenge; bulletproof_challenges; bool ]

  let[@warning "-45"] of_data
      Hlist.HlistId.
        [ Vector.
            [ combined_inner_product
            ; b
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; perm
            ]
        ; Vector.[ sponge_digest_before_evaluations ]
        ; Vector.[ beta; gamma ]
        ; Vector.[ alpha; zeta; xi ]
        ; bulletproof_challenges
        ; Vector.[ should_finalize ]
        ] : _ t =
    { deferred_values =
        { xi
        ; bulletproof_challenges
        ; b
        ; combined_inner_product
        ; plonk =
            { alpha
            ; beta
            ; gamma
            ; zeta
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; perm
            }
        }
    ; should_finalize
    ; sponge_digest_before_evaluations
    }
end

(** Wire-form (out-of-circuit) instantiation of {!t_}; the
    [deferred_values] slot is also out-of-circuit
    ({!Deferred_values.Constant.t}). {!to_t_} / {!of_t_} bridge
    to the polymorphic skeleton. *)
module Constant = struct
  type ('plonk, 'fq, 'digest) t =
    { deferred_values : ('plonk, 'fq) Deferred_values.Constant.t
    ; should_finalize : bool
    ; sponge_digest_before_evaluations : 'digest
    }

  let to_t_
      ({ deferred_values; should_finalize; sponge_digest_before_evaluations } :
        ('plonk, 'fq, 'digest) t ) :
      ( 'plonk
      , Limb_vector.Challenge.Constant.t Scalar_challenge.t
      , 'fq
      , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
          Bulletproof_challenge.t
        , Backend.Tock.Rounds.n )
        Vector.t
      , 'digest
      , bool )
      t_ =
    { deferred_values = Deferred_values.Constant.to_t_ deferred_values
    ; should_finalize
    ; sponge_digest_before_evaluations
    }

  let of_t_
      ({ deferred_values; should_finalize; sponge_digest_before_evaluations } :
        ( 'plonk
        , Limb_vector.Challenge.Constant.t Scalar_challenge.t
        , 'fq
        , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
            Bulletproof_challenge.t
          , Backend.Tock.Rounds.n )
          Vector.t
        , 'digest
        , bool )
        t_ ) : ('plonk, 'fq, 'digest) t =
    { deferred_values = Deferred_values.Constant.of_t_ deferred_values
    ; should_finalize
    ; sponge_digest_before_evaluations
    }

  (* [spec] / [to_data] / [of_data] for the value side: outer
     [Per_proof.Constant.t] with the inner Plonk pinned to
     [Plonk.In_circuit.Constant.t]. *)
  let spec bp_log2 = In_circuit.spec bp_log2

  let[@warning "-45"] to_data
      (t : ('fp Deferred_values.Plonk.In_circuit.Constant.t, 'fq, 'digest) t) =
    let { deferred_values; should_finalize; sponge_digest_before_evaluations } =
      t
    in
    let { Deferred_values.Constant.xi
        ; bulletproof_challenges
        ; b
        ; combined_inner_product
        ; plonk
        } =
      deferred_values
    in
    let ({ alpha
         ; beta
         ; gamma
         ; zeta
         ; zeta_to_srs_length
         ; zeta_to_domain_size
         ; perm
         }
          : _ Deferred_values.Plonk.In_circuit.Constant.t ) =
      plonk
    in
    let open Vector in
    let fq =
      [ combined_inner_product
      ; b
      ; zeta_to_srs_length
      ; zeta_to_domain_size
      ; perm
      ]
    in
    let challenge = [ beta; gamma ] in
    let scalar_challenge = [ alpha; zeta; xi ] in
    let digest = [ sponge_digest_before_evaluations ] in
    let bool = [ should_finalize ] in
    let open Hlist.HlistId in
    [ fq; digest; challenge; scalar_challenge; bulletproof_challenges; bool ]

  let[@warning "-45"] of_data
      Hlist.HlistId.
        [ Vector.
            [ combined_inner_product
            ; b
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; perm
            ]
        ; Vector.[ sponge_digest_before_evaluations ]
        ; Vector.[ beta; gamma ]
        ; Vector.[ alpha; zeta; xi ]
        ; bulletproof_challenges
        ; Vector.[ should_finalize ]
        ] : ('fp Deferred_values.Plonk.In_circuit.Constant.t, 'fq, 'digest) t =
    { deferred_values =
        { xi
        ; bulletproof_challenges
        ; b
        ; combined_inner_product
        ; plonk =
            { alpha
            ; beta
            ; gamma
            ; zeta
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; perm
            }
        }
    ; should_finalize
    ; sponge_digest_before_evaluations
    }
end

(** Step-circuit (Tick) instantiation of {!t_}. *)
module Step = struct
  type ('plonk, 'fq, 'digest) t =
    { deferred_values : ('plonk, 'fq) Deferred_values.Step.t
    ; should_finalize : Step_impl.Boolean.var
    ; sponge_digest_before_evaluations : 'digest
    }

  let to_t_
      ({ deferred_values; should_finalize; sponge_digest_before_evaluations } :
        ('plonk, 'fq, 'digest) t ) :
      ( 'plonk
      , Step_impl.Field.t Scalar_challenge.t
      , 'fq
      , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
        , Backend.Tock.Rounds.n )
        Vector.t
      , 'digest
      , Step_impl.Boolean.var )
      t_ =
    { deferred_values = Deferred_values.Step.to_t_ deferred_values
    ; should_finalize
    ; sponge_digest_before_evaluations
    }

  let of_t_
      ({ deferred_values; should_finalize; sponge_digest_before_evaluations } :
        ( 'plonk
        , Step_impl.Field.t Scalar_challenge.t
        , 'fq
        , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
          , Backend.Tock.Rounds.n )
          Vector.t
        , 'digest
        , Step_impl.Boolean.var )
        t_ ) : ('plonk, 'fq, 'digest) t =
    { deferred_values = Deferred_values.Step.of_t_ deferred_values
    ; should_finalize
    ; sponge_digest_before_evaluations
    }

  (* [spec] / [to_data] / [of_data] for the Step var side: outer
     [Per_proof.Step.t] with the inner Plonk pinned to
     [Plonk.In_circuit.Step.t]. The flat-data output matches
     {!In_circuit}'s, so [Spec]-driven typ construction works
     interchangeably with either form. *)
  let spec bp_log2 = In_circuit.spec bp_log2

  let[@warning "-45"] to_data
      (t : ('fp Deferred_values.Plonk.In_circuit.Step.t, 'fq, 'digest) t) =
    let { deferred_values; should_finalize; sponge_digest_before_evaluations } =
      t
    in
    let { Deferred_values.Step.xi
        ; bulletproof_challenges
        ; b
        ; combined_inner_product
        ; plonk
        } =
      deferred_values
    in
    let ({ alpha
         ; beta
         ; gamma
         ; zeta
         ; zeta_to_srs_length
         ; zeta_to_domain_size
         ; perm
         }
          : _ Deferred_values.Plonk.In_circuit.Step.t ) =
      plonk
    in
    let open Vector in
    let fq =
      [ combined_inner_product
      ; b
      ; zeta_to_srs_length
      ; zeta_to_domain_size
      ; perm
      ]
    in
    let challenge = [ beta; gamma ] in
    let scalar_challenge = [ alpha; zeta; xi ] in
    let digest = [ sponge_digest_before_evaluations ] in
    let bool = [ should_finalize ] in
    let open Hlist.HlistId in
    [ fq; digest; challenge; scalar_challenge; bulletproof_challenges; bool ]

  let[@warning "-45"] of_data
      Hlist.HlistId.
        [ Vector.
            [ combined_inner_product
            ; b
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; perm
            ]
        ; Vector.[ sponge_digest_before_evaluations ]
        ; Vector.[ beta; gamma ]
        ; Vector.[ alpha; zeta; xi ]
        ; bulletproof_challenges
        ; Vector.[ should_finalize ]
        ] : ('fp Deferred_values.Plonk.In_circuit.Step.t, 'fq, 'digest) t =
    { deferred_values =
        { xi
        ; bulletproof_challenges
        ; b
        ; combined_inner_product
        ; plonk =
            { alpha
            ; beta
            ; gamma
            ; zeta
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; perm
            }
        }
    ; should_finalize
    ; sponge_digest_before_evaluations
    }
end

(** Wrap-circuit (Tock) instantiation of {!t_}. *)
module Wrap = struct
  type ('plonk, 'fq, 'digest) t =
    { deferred_values : ('plonk, 'fq) Deferred_values.Wrap.t
    ; should_finalize : Wrap_impl.Boolean.var
    ; sponge_digest_before_evaluations : 'digest
    }

  let to_t_
      ({ deferred_values; should_finalize; sponge_digest_before_evaluations } :
        ('plonk, 'fq, 'digest) t ) :
      ( 'plonk
      , Wrap_impl.Field.t Scalar_challenge.t
      , 'fq
      , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
        , Backend.Tock.Rounds.n )
        Vector.t
      , 'digest
      , Wrap_impl.Boolean.var )
      t_ =
    { deferred_values = Deferred_values.Wrap.to_t_ deferred_values
    ; should_finalize
    ; sponge_digest_before_evaluations
    }

  let of_t_
      ({ deferred_values; should_finalize; sponge_digest_before_evaluations } :
        ( 'plonk
        , Wrap_impl.Field.t Scalar_challenge.t
        , 'fq
        , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
          , Backend.Tock.Rounds.n )
          Vector.t
        , 'digest
        , Wrap_impl.Boolean.var )
        t_ ) : ('plonk, 'fq, 'digest) t =
    { deferred_values = Deferred_values.Wrap.of_t_ deferred_values
    ; should_finalize
    ; sponge_digest_before_evaluations
    }

  (* [spec] / [to_data] / [of_data] for the Wrap var side: outer
     [Per_proof.Wrap.t] with the inner Plonk pinned to
     [Plonk.In_circuit.Wrap.t]. No consumer yet — included for
     symmetry with {!Constant} and {!Step}. *)
  let[@warning "-32"] spec bp_log2 = In_circuit.spec bp_log2

  let[@warning "-32-45"] to_data
      (t : ('fp Deferred_values.Plonk.In_circuit.Wrap.t, 'fq, 'digest) t) =
    let { deferred_values; should_finalize; sponge_digest_before_evaluations } =
      t
    in
    let { Deferred_values.Wrap.xi
        ; bulletproof_challenges
        ; b
        ; combined_inner_product
        ; plonk
        } =
      deferred_values
    in
    let ({ alpha
         ; beta
         ; gamma
         ; zeta
         ; zeta_to_srs_length
         ; zeta_to_domain_size
         ; perm
         }
          : _ Deferred_values.Plonk.In_circuit.Wrap.t ) =
      plonk
    in
    let open Vector in
    let fq =
      [ combined_inner_product
      ; b
      ; zeta_to_srs_length
      ; zeta_to_domain_size
      ; perm
      ]
    in
    let challenge = [ beta; gamma ] in
    let scalar_challenge = [ alpha; zeta; xi ] in
    let digest = [ sponge_digest_before_evaluations ] in
    let bool = [ should_finalize ] in
    let open Hlist.HlistId in
    [ fq; digest; challenge; scalar_challenge; bulletproof_challenges; bool ]

  let[@warning "-32-45"] of_data
      Hlist.HlistId.
        [ Vector.
            [ combined_inner_product
            ; b
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; perm
            ]
        ; Vector.[ sponge_digest_before_evaluations ]
        ; Vector.[ beta; gamma ]
        ; Vector.[ alpha; zeta; xi ]
        ; bulletproof_challenges
        ; Vector.[ should_finalize ]
        ] : ('fp Deferred_values.Plonk.In_circuit.Wrap.t, 'fq, 'digest) t =
    { deferred_values =
        { xi
        ; bulletproof_challenges
        ; b
        ; combined_inner_product
        ; plonk =
            { alpha
            ; beta
            ; gamma
            ; zeta
            ; zeta_to_srs_length
            ; zeta_to_domain_size
            ; perm
            }
        }
    ; should_finalize
    ; sponge_digest_before_evaluations
    }
end

(** Step-circuit Typ producing the fresh {!Step.t} (var) and
    {!Constant.t} (value) records, threading the [Constant.spec],
    [Constant.to_data], [Constant.of_data] duplicates on the value
    side and [Step.spec], [Step.to_data], [Step.of_data] on the
    var side. *)
let typ fq ~assert_16_bits =
  Spec.typ fq ~assert_16_bits (Constant.spec Backend.Tock.Rounds.n)
  |> Step_impl.Typ.transport ~there:Constant.to_data ~back:Constant.of_data
  |> Step_impl.Typ.transport_var ~there:Step.to_data ~back:Step.of_data

(** Wrap-circuit counterpart of {!typ}, threading the [Constant]
    duplicates on the value side and the [Wrap] duplicates on the
    var side. *)
let wrap_typ fq ~assert_16_bits =
  Spec.wrap_typ fq ~assert_16_bits (Constant.spec Backend.Tock.Rounds.n)
  |> Wrap_impl.Typ.transport ~there:Constant.to_data ~back:Constant.of_data
  |> Wrap_impl.Typ.transport_var ~there:Wrap.to_data ~back:Wrap.of_data
