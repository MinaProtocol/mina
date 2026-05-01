(** Step-side proof types.

    Extracted from [Composition_types.Step], holding [Bulletproof],
    [Proof_state] and [Statement] modules used by the step circuit. *)

open Pickles_types
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
module Bulletproof_challenge = Bulletproof_challenge
module Branch_data = Branch_data
module Digest = Digest
module Spec = Spec
module Step_impl = Kimchi_pasta_snarky_backend.Step_impl
module Wrap_impl = Kimchi_pasta_snarky_backend.Wrap_impl
module Per_proof = Step_per_proof

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

  module Messages_for_next_wrap_proof = Messages_for_next.Wrap_proof
  module Messages_for_next_step_proof = Messages_for_next.Step_proof

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
