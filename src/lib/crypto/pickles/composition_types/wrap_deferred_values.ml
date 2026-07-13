(** Wrap-circuit deferred-values record.

    Extracted from [Composition_types.Wrap.Proof_state.Deferred_values]
    so the per-concept hierarchy is one file per concept. *)

open Pickles_types
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
module Bulletproof_challenge = Bulletproof_challenge
module Branch_data = Branch_data
module Step_impl = Kimchi_pasta_snarky_backend.Step_impl
module Wrap_impl = Kimchi_pasta_snarky_backend.Wrap_impl

(** Wire-format polymorphic skeleton. Concrete records below name
    it explicitly via {!Poly} rather than [include]ing it. *)
module Poly = Wire.Wrap.Proof_state.Deferred_values

module Plonk = Wrap_plonk_iop

(** Wire-form (out-of-circuit) instantiation of {!t}; concretises
    the [scalar_challenge] / [bulletproof_challenges] slots.
    ['plonk], ['fp], ['branch_data] are left polymorphic because
    callers pick them from {!Plonk.Minimal} vs {!Plonk.In_circuit},
    between [Shifted_value.Type1.t] and [Shifted_value.Type2.t],
    and per branch_data form respectively. {!to_deferred_values} /
    {!of_deferred_values} bridge to the polymorphic
    {!Poly.t}. *)
module Constant = struct
  type ('plonk, 'fp) t =
    { plonk : 'plonk
    ; combined_inner_product : 'fp
    ; b : 'fp
    ; xi : Limb_vector.Challenge.Constant.t Scalar_challenge.t
    ; bulletproof_challenges :
        ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
          Bulletproof_challenge.t
        , Backend.Tick.Rounds.n )
        Vector.t
    ; branch_data : Branch_data.t
    }

  (** [Poly.t] specialised to the wire-form scalar_challenge /
      bulletproof_challenges / branch_data slots used out of
      circuit — the result type of {!to_deferred_values}, also
      consumed by [Wrap.For_tests_only.deferred_values_and_hints]. *)
  type ('plonk, 'fp) poly_t =
    ( 'plonk
    , Limb_vector.Challenge.Constant.t Scalar_challenge.t
    , 'fp
    , ( Limb_vector.Challenge.Constant.t Scalar_challenge.t
        Bulletproof_challenge.t
      , Backend.Tick.Rounds.n )
      Vector.t
    , Branch_data.t )
    Poly.t

  let to_deferred_values
      ({ plonk
       ; combined_inner_product
       ; b
       ; xi
       ; bulletproof_challenges
       ; branch_data
       } :
        ('plonk, 'fp) t ) : ('plonk, 'fp) poly_t =
    { plonk
    ; combined_inner_product
    ; b
    ; xi
    ; bulletproof_challenges
    ; branch_data
    }

  let of_deferred_values
      ({ plonk
       ; combined_inner_product
       ; b
       ; xi
       ; bulletproof_challenges
       ; branch_data
       } :
        ('plonk, 'fp) poly_t ) : ('plonk, 'fp) t =
    { plonk
    ; combined_inner_product
    ; b
    ; xi
    ; bulletproof_challenges
    ; branch_data
    }
end

(** Step-circuit (Tick) instantiation of {!t}. *)
module Step = struct
  type ('plonk, 'fp) t =
    { plonk : 'plonk
    ; combined_inner_product : 'fp
    ; b : 'fp
    ; xi : Step_impl.Field.t Scalar_challenge.t
    ; bulletproof_challenges :
        ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
        , Backend.Tick.Rounds.n )
        Vector.t
    ; branch_data : Branch_data.Checked.Step.t
    }

  let to_deferred_values
      ({ plonk
       ; combined_inner_product
       ; b
       ; xi
       ; bulletproof_challenges
       ; branch_data
       } :
        ('plonk, 'fp) t ) :
      ( 'plonk
      , Step_impl.Field.t Scalar_challenge.t
      , 'fp
      , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
        , Backend.Tick.Rounds.n )
        Vector.t
      , Branch_data.Checked.Step.t )
      Poly.t =
    { plonk
    ; combined_inner_product
    ; b
    ; xi
    ; bulletproof_challenges
    ; branch_data
    }

  let of_deferred_values
      ({ plonk
       ; combined_inner_product
       ; b
       ; xi
       ; bulletproof_challenges
       ; branch_data
       } :
        ( 'plonk
        , Step_impl.Field.t Scalar_challenge.t
        , 'fp
        , ( Step_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
          , Backend.Tick.Rounds.n )
          Vector.t
        , Branch_data.Checked.Step.t )
        Poly.t ) : ('plonk, 'fp) t =
    { plonk
    ; combined_inner_product
    ; b
    ; xi
    ; bulletproof_challenges
    ; branch_data
    }
end

(** Wrap-circuit (Tock) instantiation of {!t}. *)
module Wrap = struct
  type ('plonk, 'fp) t =
    { plonk : 'plonk
    ; combined_inner_product : 'fp
    ; b : 'fp
    ; xi : Wrap_impl.Field.t Scalar_challenge.t
    ; bulletproof_challenges :
        ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
        , Backend.Tick.Rounds.n )
        Vector.t
    ; branch_data : Wrap_impl.Field.t
    }

  let to_deferred_values
      ({ plonk
       ; combined_inner_product
       ; b
       ; xi
       ; bulletproof_challenges
       ; branch_data
       } :
        ('plonk, 'fp) t ) :
      ( 'plonk
      , Wrap_impl.Field.t Scalar_challenge.t
      , 'fp
      , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
        , Backend.Tick.Rounds.n )
        Vector.t
      , Wrap_impl.Field.t )
      Poly.t =
    { plonk
    ; combined_inner_product
    ; b
    ; xi
    ; bulletproof_challenges
    ; branch_data
    }

  let of_deferred_values
      ({ plonk
       ; combined_inner_product
       ; b
       ; xi
       ; bulletproof_challenges
       ; branch_data
       } :
        ( 'plonk
        , Wrap_impl.Field.t Scalar_challenge.t
        , 'fp
        , ( Wrap_impl.Field.t Scalar_challenge.t Bulletproof_challenge.t
          , Backend.Tick.Rounds.n )
          Vector.t
        , Wrap_impl.Field.t )
        Poly.t ) : ('plonk, 'fp) t =
    { plonk
    ; combined_inner_product
    ; b
    ; xi
    ; bulletproof_challenges
    ; branch_data
    }
end

(** Post-compute (out-of-circuit) instantiation of {!t}. Fresh
    record. Differs from {!Constant} in the
    [bulletproof_challenges] slot: this form holds the field
    elements that come out of [Ipa.Step.compute_challenges]
    (challenge polynomial evaluations), not the
    {!Bulletproof_challenge.t}-wrapped scalar challenges that
    {!Constant} carries.

    Returned by [Wrap_deferred_values.expand_deferred] and
    consumed downstream by the prover-side step / verify
    paths. *)
module Computed = struct
  type ('plonk, 'fp, 'branch_data) t =
    { plonk : 'plonk
    ; combined_inner_product : 'fp
    ; b : 'fp
    ; xi : Limb_vector.Challenge.Constant.t Scalar_challenge.t
    ; bulletproof_challenges :
        (Backend.Tick.Field.t, Backend.Tick.Rounds.n) Vector.t
    ; branch_data : 'branch_data
    }

  let to_deferred_values
      ({ plonk
       ; combined_inner_product
       ; b
       ; xi
       ; bulletproof_challenges
       ; branch_data
       } :
        ('plonk, 'fp, 'branch_data) t ) :
      ( 'plonk
      , Limb_vector.Challenge.Constant.t Scalar_challenge.t
      , 'fp
      , (Backend.Tick.Field.t, Backend.Tick.Rounds.n) Vector.t
      , 'branch_data )
      Poly.t =
    { plonk
    ; combined_inner_product
    ; b
    ; xi
    ; bulletproof_challenges
    ; branch_data
    }

  let of_deferred_values
      ({ plonk
       ; combined_inner_product
       ; b
       ; xi
       ; bulletproof_challenges
       ; branch_data
       } :
        ( 'plonk
        , Limb_vector.Challenge.Constant.t Scalar_challenge.t
        , 'fp
        , (Backend.Tick.Field.t, Backend.Tick.Rounds.n) Vector.t
        , 'branch_data )
        Poly.t ) : ('plonk, 'fp, 'branch_data) t =
    { plonk
    ; combined_inner_product
    ; b
    ; xi
    ; bulletproof_challenges
    ; branch_data
    }
end

module Minimal = struct
  [@@@warning "-27"]

  (* 'fp is unused in Minimal but kept for type compatibility with
     In_circuit, to preserve the serialization format. *)

  (** Wire-format polymorphic skeleton for the [Minimal] form. *)
  module Poly = Wire.Wrap.Proof_state.Deferred_values.Minimal

  let map_challenges ({ plonk; bulletproof_challenges; branch_data } : _ Poly.t)
      ~f ~scalar : _ Poly.t =
    { plonk = Plonk.Minimal.map_challenges ~f ~scalar plonk
    ; bulletproof_challenges
    ; branch_data
    }
end

let map_challenges
    ({ plonk
     ; combined_inner_product
     ; b
     ; xi
     ; bulletproof_challenges
     ; branch_data
     } :
      _ Poly.t ) ~f:_ ~scalar : _ Poly.t =
  { xi = scalar xi
  ; combined_inner_product
  ; b
  ; plonk
  ; bulletproof_challenges
  ; branch_data
  }

module In_circuit = struct
  type ( 'challenge
       , 'scalar_challenge
       , 'fp
       , 'fp_opt
       , 'lookup_opt
       , 'bulletproof_challenges
       , 'branch_data
       , 'bool )
       t =
    ( ( 'challenge
      , 'scalar_challenge
      , 'fp
      , 'fp_opt
      , 'lookup_opt
      , 'bool )
      Plonk.In_circuit.t
    , 'scalar_challenge
    , 'fp
    , 'bulletproof_challenges
    , 'branch_data )
    Poly.Stable.Latest.t
  [@@deriving sexp, compare, yojson, hash, equal]

  let to_hlist = Poly.Stable.Latest.to_hlist

  let of_hlist = Poly.Stable.Latest.of_hlist

  let typ (type fp) ~dummy_scalar_challenge ~challenge ~scalar_challenge
      ~feature_flags (fp : (fp, _) Step_impl.Typ.t) index =
    Step_impl.Typ.of_hlistable
      [ Plonk.In_circuit.typ ~dummy_scalar_challenge ~challenge
          ~scalar_challenge ~bool:Step_impl.Boolean.typ ~feature_flags fp
      ; fp
      ; fp
      ; Scalar_challenge.typ scalar_challenge
      ; Vector.typ
          (Bulletproof_challenge.typ scalar_challenge)
          Backend.Tick.Rounds.n
      ; index
      ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

let to_minimal
    ({ plonk
     ; combined_inner_product = _
     ; b = _
     ; xi = _
     ; bulletproof_challenges
     ; branch_data
     } :
      _ In_circuit.t ) ~to_option : _ Minimal.Poly.t =
  { plonk = Plonk.to_minimal ~to_option plonk
  ; bulletproof_challenges
  ; branch_data
  }
