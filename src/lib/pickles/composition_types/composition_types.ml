open Pickles_types
module Scalar_challenge = Pickles_types.Scalar_challenge
open Core_kernel
module Bulletproof_challenge = Bulletproof_challenge
module Spec = Spec

let index_to_field_elements ({row; col; value} : 'a Abc.t Matrix_evals.t)
    ~g:g_to_field_elements =
  Array.concat_map [|row; col; value|] ~f:(fun {a; b; c} ->
      Array.concat_map [|a; b; c|] ~f:(fun g ->
          Array.of_list (g_to_field_elements g) ) )

module Dlog_based = struct
  module Proof_state = struct
    module Deferred_values = struct
      module Marlin = struct
        type ('challenge, 'scalar_challenge, 'fp) t =
          { sigma_2: 'fp
          ; sigma_3: 'fp
          ; alpha: 'challenge
          ; eta_a: 'challenge
          ; eta_b: 'challenge
          ; eta_c: 'challenge
          ; beta_1: 'scalar_challenge
          ; beta_2: 'scalar_challenge
          ; beta_3: 'scalar_challenge }
        [@@deriving bin_io, sexp, compare, yojson, hlist]

        let map_challenges
            { sigma_2
            ; sigma_3
            ; alpha
            ; eta_a
            ; eta_b
            ; eta_c
            ; beta_1
            ; beta_2
            ; beta_3 } ~f ~scalar =
          { sigma_2
          ; sigma_3
          ; alpha= f alpha
          ; eta_a= f eta_a
          ; eta_b= f eta_b
          ; eta_c= f eta_c
          ; beta_1= scalar beta_1
          ; beta_2= scalar beta_2
          ; beta_3= scalar beta_3 }

        open Snarky.H_list

        let typ chal fp =
          Snarky.Typ.of_hlistable
            [ fp
            ; fp
            ; chal
            ; chal
            ; chal
            ; chal
            ; Scalar_challenge.typ chal
            ; Scalar_challenge.typ chal
            ; Scalar_challenge.typ chal ]
            ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
            ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
      end

      type ('challenge, 'scalar_challenge, 'fp, 'fq) t =
        { xi: 'scalar_challenge
        ; r: 'scalar_challenge
        ; r_xi_sum: 'fp
        ; marlin: ('challenge, 'scalar_challenge, 'fp) Marlin.t }
      [@@deriving bin_io, sexp, compare, yojson, hlist]

      let map_challenges {xi; r; r_xi_sum; marlin} ~f ~scalar =
        { xi= scalar xi
        ; r= scalar r
        ; r_xi_sum
        ; marlin= Marlin.map_challenges marlin ~f ~scalar }

      let typ chal fp fq =
        Snarky.Typ.of_hlistable
          [ Scalar_challenge.typ chal
          ; Scalar_challenge.typ chal
          ; fp
          ; Marlin.typ chal fp ]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
          ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
    end

    module Me_only = struct
      type ('g1, 'unshifted, 'bulletproof_challenges) t =
        { pairing_marlin_acc:
            ('g1, 'unshifted) Pairing_marlin_types.Accumulator.Stable.Latest.t
        ; old_bulletproof_challenges: 'bulletproof_challenges }
      [@@deriving bin_io, sexp, compare, yojson, hlist]

      let to_field_elements
          { pairing_marlin_acc=
              { opening_check= {r_f_minus_r_v_plus_rz_pi; r_pi}
              ; degree_bound_checks=
                  {shifted_accumulator; unshifted_accumulators} }
          ; old_bulletproof_challenges } ~g1:g1_to_field_elements =
        Array.concat
          [ Vector.to_array old_bulletproof_challenges
            |> Array.concat_map ~f:Vector.to_array
          ; Array.concat_map
              (Array.append
                 [|r_f_minus_r_v_plus_rz_pi; r_pi; shifted_accumulator|]
                 ( Map.to_sequence ~order:`Increasing_key unshifted_accumulators
                 |> Sequence.map ~f:snd |> Sequence.to_array ))
              ~f:(fun g -> Array.of_list (g1_to_field_elements g)) ]

      let typ g1 chal domain_sizes ~length =
        Snarky.Typ.of_hlistable
          [ Pairing_marlin_types.Accumulator.typ domain_sizes g1
          ; Vector.typ chal length ]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
          ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
    end

    type ('challenge, 'scalar_challenge, 'fp, 'bool, 'fq, 'me_only, 'digest) t =
      { deferred_values:
          ('challenge, 'scalar_challenge, 'fp, 'fq) Deferred_values.t
      ; was_base_case: 'bool
      ; sponge_digest_before_evaluations: 'digest
            (* Not needed by other proof system *)
      ; me_only: 'me_only }
    [@@deriving bin_io, sexp, compare, yojson, hlist]

    let typ chal fp bool fq me_only digest =
      Snarky.Typ.of_hlistable
        [Deferred_values.typ chal fp fq; bool; digest; me_only]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  module Pass_through = struct
    type ('g, 's, 'sg) t =
      { app_state: 's
      ; dlog_marlin_index:
          'g Dlog_marlin_types.Poly_comm.Without_degree_bound.t Abc.t
          Matrix_evals.t
      ; sg: 'sg }

    let to_field_elements {app_state; dlog_marlin_index; sg}
        ~app_state:app_state_to_field_elements ~comm ~g =
      Array.concat
        [ index_to_field_elements ~g:comm dlog_marlin_index
        ; Array.of_list (List.concat_map ~f:g (Vector.to_list sg))
        ; app_state_to_field_elements app_state ]

    let to_field_elements_without_index {app_state; dlog_marlin_index= _; sg}
        ~app_state:app_state_to_field_elements ~g =
      Array.concat
        [ Array.of_list (List.concat_map ~f:g (Vector.to_list sg))
        ; app_state_to_field_elements app_state ]

    open Snarky.H_list

    let to_hlist {app_state; dlog_marlin_index; sg} =
      [app_state; dlog_marlin_index; sg]

    let of_hlist ([app_state; dlog_marlin_index; sg] : (unit, _) t) =
      {app_state; dlog_marlin_index; sg}

    let typ comm g s branching =
      Snarky.Typ.of_hlistable
        [s; Matrix_evals.typ (Abc.typ comm); Vector.typ g branching]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  module Statement = struct
    type ( 'challenge
         , 'scalar_challenge
         , 'fp
         , 'bool
         , 'fq
         , 'me_only
         , 'digest
         , 'pass_through )
         t =
      { proof_state:
          ( 'challenge
          , 'scalar_challenge
          , 'fp
          , 'bool
          , 'fq
          , 'me_only
          , 'digest )
          Proof_state.t
      ; pass_through: 'pass_through }
    [@@deriving bin_io, compare, yojson, sexp]

    let spec =
      let open Spec in
      Struct
        [ Vector (B Bool, Nat.N1.n)
        ; Vector (B Field, Nat.N3.n)
        ; Vector (B Challenge, Nat.N4.n)
        ; Vector (Scalar Challenge, Nat.N5.n)
        ; Vector (B Digest, Nat.N3.n) ]

    let to_data
        { proof_state=
            { deferred_values=
                { xi
                ; r
                ; r_xi_sum
                ; marlin=
                    { sigma_2
                    ; sigma_3
                    ; alpha
                    ; eta_a
                    ; eta_b
                    ; eta_c
                    ; beta_1
                    ; beta_2
                    ; beta_3 } }
            ; was_base_case
            ; sponge_digest_before_evaluations
            ; me_only }
        ; pass_through } =
      let open Vector in
      let fp = [sigma_2; sigma_3; r_xi_sum] in
      let challenge = [alpha; eta_a; eta_b; eta_c] in
      let scalar_challenge = [beta_1; beta_2; beta_3; xi; r] in
      let bool = [was_base_case] in
      let digest = [sponge_digest_before_evaluations; me_only; pass_through] in
      Hlist.HlistId.[bool; fp; challenge; scalar_challenge; digest]

    let of_data Hlist.HlistId.[bool; fp; challenge; scalar_challenge; digest] =
      let open Vector in
      let [sigma_2; sigma_3; r_xi_sum] = fp in
      let [alpha; eta_a; eta_b; eta_c] = challenge in
      let [beta_1; beta_2; beta_3; xi; r] = scalar_challenge in
      let [was_base_case] = bool in
      let [sponge_digest_before_evaluations; me_only; pass_through] = digest in
      { proof_state=
          { was_base_case
          ; deferred_values=
              { xi
              ; r
              ; r_xi_sum
              ; marlin=
                  { sigma_2
                  ; sigma_3
                  ; alpha
                  ; eta_a
                  ; eta_b
                  ; eta_c
                  ; beta_1
                  ; beta_2
                  ; beta_3 } }
          ; sponge_digest_before_evaluations
          ; me_only }
      ; pass_through }
  end
end

module Pairing_based = struct
  module Marlin_polys = Vector.Nat.N20

  module Openings = struct
    module Evaluations = struct
      module By_point = struct
        type 'fq t = {beta_1: 'fq; beta_2: 'fq; beta_3: 'fq; g_challenge: 'fq}
      end

      type 'fq t = ('fq By_point.t, Marlin_polys.n Vector.s) Vector.t
    end

    module Bulletproof = struct
      include Dlog_marlin_types.Openings.Bulletproof

      module Advice = struct
        (* This is data that can be computed in linear time from the above plus the statement.
        
          It doesn't need to be sent on the wire, but it does need to be provided to the verifier
        *)
        type ('fq, 'g) t = {b: 'fq} [@@deriving hlist]

        let typ fq g =
          let open Snarky.Typ in
          of_hlistable [fq] ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
            ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
      end
    end

    type ('fq, 'g) t =
      {evaluations: 'fq Evaluations.t; proof: ('fq, 'g) Bulletproof.t}
  end

  module Proof_state = struct
    module Deferred_values = struct
      module Marlin = Dlog_based.Proof_state.Deferred_values.Marlin

      type ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t =
        { marlin: ('challenge, 'scalar_challenge, 'fq) Marlin.t
        ; combined_inner_product: 'fq
        ; xi: 'scalar_challenge (* 128 bits *)
        ; r: 'scalar_challenge (* 128 bits *)
        ; bulletproof_challenges: 'bulletproof_challenges
        ; b: 'fq }
      [@@deriving bin_io, sexp, compare, yojson]
    end

    module Pass_through = Dlog_based.Proof_state.Me_only
    module Me_only = Dlog_based.Pass_through

    module Per_proof = struct
      type ( 'challenge
           , 'scalar_challenge
           , 'fq
           , 'bulletproof_challenges
           , 'digest )
           t =
        { deferred_values:
            ( 'challenge
            , 'scalar_challenge
            , 'fq
            , 'bulletproof_challenges )
            Deferred_values.t
        ; sponge_digest_before_evaluations: 'digest }
      [@@deriving bin_io, sexp, compare, yojson]

      let spec bp_log2 =
        let open Spec in
        Struct
          [ Vector (B Field, Nat.N4.n)
          ; Vector (B Digest, Nat.N1.n)
          ; Vector (B Challenge, Nat.N4.n)
          ; Vector (Scalar Challenge, Nat.N5.n)
          ; Vector (B Bulletproof_challenge, bp_log2) ]

      let to_data
          { deferred_values=
              { xi
              ; r
              ; bulletproof_challenges
              ; b
              ; combined_inner_product
              ; marlin=
                  { sigma_2
                  ; sigma_3
                  ; alpha
                  ; eta_a
                  ; eta_b
                  ; eta_c
                  ; beta_1
                  ; beta_2
                  ; beta_3 } }
          ; sponge_digest_before_evaluations } =
        let open Vector in
        let fq = [sigma_2; sigma_3; combined_inner_product; b] in
        let challenge = [alpha; eta_a; eta_b; eta_c] in
        let scalar_challenge = [beta_1; beta_2; beta_3; xi; r] in
        let digest = [sponge_digest_before_evaluations] in
        let open Hlist.HlistId in
        [fq; digest; challenge; scalar_challenge; bulletproof_challenges]

      open Hlist.HlistId

      let of_data
          [ Vector.[sigma_2; sigma_3; combined_inner_product; b]
          ; Vector.[sponge_digest_before_evaluations]
          ; Vector.[alpha; eta_a; eta_b; eta_c]
          ; Vector.[beta_1; beta_2; beta_3; xi; r]
          ; bulletproof_challenges ] =
        { deferred_values=
            { xi
            ; r
            ; bulletproof_challenges
            ; b
            ; combined_inner_product
            ; marlin=
                { sigma_2
                ; sigma_3
                ; alpha
                ; eta_a
                ; eta_b
                ; eta_c
                ; beta_1
                ; beta_2
                ; beta_3 } }
        ; sponge_digest_before_evaluations }
    end

    type ('unfinalized_proofs, 'me_only) t =
      {unfinalized_proofs: 'unfinalized_proofs; me_only: 'me_only}
    [@@(*       ; was_base_case: 'bool } *)
      deriving
      bin_io, sexp, compare, yojson]

    let spec unfinalized_proofs me_only =
      let open Spec in
      Struct [unfinalized_proofs; me_only]

    open Hlist.HlistId

    let to_data {unfinalized_proofs; me_only} =
      [ Vector.map unfinalized_proofs ~f:(fun (unfinalized, should_verify) ->
            [Per_proof.to_data unfinalized; should_verify] )
      ; me_only ]

    let of_data [unfinalized_proofs; me_only] =
      { unfinalized_proofs=
          Vector.map unfinalized_proofs ~f:(fun [unfinalized; should_verify] ->
              (Per_proof.of_data unfinalized, should_verify) )
      ; me_only }

    let typ impl branching bp_log2 fq =
      let unfinalized_proofs =
        let open Spec in
        Vector (Struct [Per_proof.spec bp_log2; B Bool], branching)
      in
      spec unfinalized_proofs (B Spec.Digest)
      |> Spec.typ impl fq
      |> Snarky.Typ.transport ~there:to_data ~back:of_data
      |> Snarky.Typ.transport_var ~there:to_data ~back:of_data
  end

  module Statement = struct
    type ('unfinalized_proofs, 'me_only, 'pass_through) t =
      { proof_state: ('unfinalized_proofs, 'me_only) Proof_state.t
      ; pass_through: 'pass_through }
    [@@deriving bin_io, sexp, compare, yojson]

    let to_data {proof_state= {unfinalized_proofs; me_only}; pass_through} =
      let open Hlist.HlistId in
      [ Vector.map unfinalized_proofs ~f:(fun (pp, b) ->
            Hlist.HlistId.[Proof_state.Per_proof.to_data pp; b] )
      ; me_only
      ; pass_through ]

    let of_data Hlist.HlistId.[unfinalized_proofs; me_only; pass_through] =
      { proof_state=
          { unfinalized_proofs=
              Vector.map unfinalized_proofs
                ~f:(fun ([pp; b] : _ Hlist.HlistId.t) ->
                  (Proof_state.Per_proof.of_data pp, b) )
          ; me_only }
      ; pass_through }

    let spec branching bp_log2 =
      let open Spec in
      let per_proof = Struct [Proof_state.Per_proof.spec bp_log2; B Bool] in
      Struct
        [Vector (per_proof, branching); B Digest; Vector (B Digest, branching)]
  end
end

module Nvector = Vector.With_length
module Bp_vec = Nvector (Zexe_backend.Dlog_based.Rounds)

module Challenges_vector = struct
  type 'n t =
    (Zexe_backend.Dlog_based.Field.t Snarky.Cvar.t Bp_vec.t, 'n) Vector.t

  module Constant = struct
    type 'n t = (Zexe_backend.Dlog_based.Field.t Bp_vec.t, 'n) Vector.t
  end
end
