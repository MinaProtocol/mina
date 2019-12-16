module Dlog_based : sig
  module Proof_state : sig
    module Deferred_values : sig
      module Marlin : sig
        type ('challenge, 'fp) t =
          { sigma_2: 'fp
          ; sigma_3: 'fp
          ; alpha: 'challenge
          ; eta_a: 'challenge
          ; eta_b: 'challenge
          ; eta_c: 'challenge
          ; beta_1: 'challenge
          ; beta_2: 'challenge
          ; beta_3: 'challenge }

        val map_challenges : ('c1, 'fp) t -> f:('c1 -> 'c2) -> ('c2, 'fp) t

        include Intf.Snarkable.S2 with type ('a, 'b) t := ('a, 'b) t
      end

      type ('challenge, 'fp, 'fq_challenge, 'fq) t =
        { xi: 'challenge
        ; r: 'challenge
        ; r_xi_sum: 'fp
        ; marlin: ('challenge, 'fp) Marlin.t
        ; sg_challenge_point: 'fq_challenge
        ; sg_evaluation: 'fq }

      val map_challenges :
        ('c1, 'x1, 'x2, 'x3) t -> f:('c1 -> 'c2) -> ('c2, 'x1, 'x2, 'x3) t

      include
        Intf.Snarkable.S4 with type ('a, 'b, 'c, 'd) t := ('a, 'b, 'c, 'd) t
    end

    module Me_only : sig
      type 'g1 t =
        { pairing_marlin_index: 'g1 Abc.t Matrix_evals.t
        ; pairing_marlin_acc: 'g1 Pairing_marlin_types.Accumulator.t }

      include Intf.Snarkable.S1 with type 'a t := 'a t
    end

    type ('challenge, 'fp, 'fq_challenge, 'fq, 'me_only, 'digest) t =
      { deferred_values: ('challenge, 'fp, 'fq_challenge, 'fq) Deferred_values.t
      ; sponge_digest_before_evaluations: 'digest
      ; me_only: 'me_only }

    include
      Intf.Snarkable.S6
      with type ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) t :=
                  ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) t
  end

  module Pass_through : sig
    type ('g, 's) t =
      {app_state: 's; dlog_marlin_index: 'g Abc.t Matrix_evals.t; sg: 'g}

    include Intf.Snarkable.S2 with type ('a, 'b) t := ('a, 'b) t
  end

  module rec Statement : sig
    type ( 'challenge
         , 'fp
         , 'fq_challenge
         , 'fq
         , 'me_only
         , 'digest
         , 'pass_through )
         t =
      { proof_state:
          ( 'challenge
          , 'fp
          , 'fq_challenge
          , 'fq
          , 'me_only
          , 'digest )
          Proof_state.t
      ; pass_through: 'pass_through }

    open Vector.Nat

    val to_data :
         ('a, 'b, 'a, 'c, 'd, 'd, 'd) Statement.t
      -> ('b, N3.n) Vector.t
         * ('c, N1.n) Vector.t
         * ('a, N13.n) Vector.t
         * ('d, N3.n) Vector.t

    val of_data :
         ('b, N3.n) Vector.t
         * ('c, N1.n) Vector.t
         * ('a, N13.n) Vector.t
         * ('d, N3.n) Vector.t
      -> ('a, 'b, 'a, 'c, 'd, 'd, 'd) Statement.t
  end
end

module Pairing_based : sig
  module Marlin_polys = Vector.Nat.N20

  module Bulletproof_challenge : sig
    type ('challenge, 'bool) t = {prechallenge: 'challenge; is_square: 'bool}

    include Intf.Snarkable.S2 with type ('a, 'b) t := ('a, 'b) t
  end

  module Openings : sig
    module Evaluations : sig
      module By_point : sig
        type 'fq t = {beta_1: 'fq; beta_2: 'fq; beta_3: 'fq; g_challenge: 'fq}
      end

      type 'fq t = ('fq By_point.t, Marlin_polys.n Vector.s) Vector.t
    end

    module Bulletproof : sig
      type ('fq, 'g) t =
        {gammas: ('g * 'g) array; z_1: 'fq; z_2: 'fq; beta: 'g; delta: 'g}

      include Intf.Snarkable.S2 with type ('a, 'b) t := ('a, 'b) t

      module Advice : sig
        (* This is data that can be computed in linear time from the above plus the statement.

          It doesn't need to be sent on the wire, but it does need to be provided to the verifier
        *)
        type ('fq, 'g) t = {sg: 'g; a_hat: 'fq}

        include Intf.Snarkable.S2 with type ('a, 'b) t := ('a, 'b) t
      end
    end

    type ('fq, 'g) t =
      {evaluations: 'fq Evaluations.t; proof: ('fq, 'g) Bulletproof.t}
  end

  module Proof_state : sig
    module Deferred_values : sig
      module Marlin = Dlog_based.Proof_state.Deferred_values.Marlin

      type ('challenge, 'fq, 'bool) t =
        { marlin: ('challenge, 'fq) Marlin.t
        ; combined_inner_product: 'fq
        ; xi: 'challenge
        ; r: 'challenge
        ; bulletproof_challenges:
            ('challenge, 'bool) Bulletproof_challenge.t array
        ; a_hat: 'fq }

      include Intf.Snarkable.S3 with type ('a, 'b, 'c) t := ('a, 'b, 'c) t
    end

    module Pass_through = Dlog_based.Proof_state.Me_only
    module Me_only = Dlog_based.Pass_through

    type ('challenge, 'fq, 'bool, 'me_only, 'digest) t =
      { deferred_values: ('challenge, 'fq, 'bool) Deferred_values.t
      ; sponge_digest_before_evaluations: 'digest
      ; me_only: 'me_only }

    include
      Intf.Snarkable.S5
      with type ('a1, 'a2, 'a3, 'a4, 'a5) t := ('a1, 'a2, 'a3, 'a4, 'a5) t
  end

  module rec Statement : sig
    type ('challenge, 'fq, 'bool, 'me_only, 'pass_through, 'digest, 's) t =
      { proof_state: ('challenge, 'fq, 'bool, 'me_only, 'digest) Proof_state.t
      ; pass_through: 'pass_through }

    open Vector.Nat

    val to_data :
         ('a, 'b, 'c, 'd, 'd, 'd, 'e) Statement.t
      -> ('b, N4.n) Vector.t
         * ('d, N3.n) Vector.t
         * ('a, N9.n) Vector.t
         * ('a, 'c) Bulletproof_challenge.t array

    val of_data :
         ('b, N4.n) Vector.t
         * ('d, N3.n) Vector.t
         * ('a, N9.n) Vector.t
         * ('a, 'c) Bulletproof_challenge.t array
      -> ('a, 'b, 'c, 'd, 'd, 'd, 'e) Statement.t
  end
end
