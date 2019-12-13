module Dlog_based = struct
  module Proof_state = struct
    module Deferred_values = struct
      (* For each evaluation point beta_i, just expose the value of
        \sum_j xi^i f_j(beta_i). The next person can exists in
        the actualy values f_j(beta_i) and check them against that
        value and xi.
      *)
      module Marlin = struct
        type ('challenge, 'fp) t =
          { sigma_2: 'fp
          ; sigma_3: 'fp
          ; alpha: 'challenge (* 128 bits *)
          ; eta_a: 'challenge (* 128 bits *)
          ; eta_b: 'challenge (* 128 bits *)
          ; eta_c: 'challenge (* 128 bits *)
          ; beta_1: 'challenge (* 128 bits *)
          ; beta_2: 'challenge (* 128 bits *)
          ; beta_3: 'challenge (* 128 bits *)
          ; beta_1_xi_sum: 'fp
          ; beta_2_xi_sum: 'fp
          ; beta_3_xi_sum: 'fp }
      end

      type ('challenge, 'fp, 'bool, 'g) t =
        {xi: 'fp; marlin: ('challenge, 'fp) Marlin.t}
    end

    type ('challenge, 'fp, 'bool, 'g, 'g1, 'digest) t =
      { deferred_values: ('challenge, 'fp, 'bool, 'g) Deferred_values.t
      ; sponge_digest: 'digest (* Not needed by other proof system *)
      ; pairing_marlin_index: 'g1 Abc.t Matrix_evals.t
      ; pairing_marlin_acc: 'g1 Pairing_marlin_types.Accumulator.t
            (* Pass thru. Not needed by this proof system *)
      ; dlog_marlin_index: 'g Abc.t Matrix_evals.t }
  end

  module Statement = struct
    type ('challenge, 'fp, 'bool, 'g, 'g1, 'digest, 's) t =
      { proof_state: ('challenge, 'fp, 'bool, 'g, 'g1, 'digest) Proof_state.t
      ; app_state: 's }
  end
end
