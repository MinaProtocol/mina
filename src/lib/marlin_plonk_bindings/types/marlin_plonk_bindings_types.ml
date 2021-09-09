module Or_infinity = struct
  type 'a t = Infinity | Finite of 'a
end

module Scalar_challenge = struct
  type 'a t = Scalar_challenge of 'a
end

module Poly_comm = struct
  type 'a t = {unshifted: 'a array; shifted: 'a option}
end

module Plonk_domain = struct
  type 'field t = {log_size_of_group: int; group_gen: 'field}
end

module Plonk_verification_evals = struct
  type 'poly_comm t =
    { sigma_comm_0: 'poly_comm
    ; sigma_comm_1: 'poly_comm
    ; sigma_comm_2: 'poly_comm
    ; ql_comm: 'poly_comm
    ; qr_comm: 'poly_comm
    ; qo_comm: 'poly_comm
    ; qm_comm: 'poly_comm
    ; qc_comm: 'poly_comm
    ; rcm_comm_0: 'poly_comm
    ; rcm_comm_1: 'poly_comm
    ; rcm_comm_2: 'poly_comm
    ; psm_comm: 'poly_comm
    ; add_comm: 'poly_comm
    ; mul1_comm: 'poly_comm
    ; mul2_comm: 'poly_comm
    ; emul1_comm: 'poly_comm
    ; emul2_comm: 'poly_comm
    ; emul3_comm: 'poly_comm }
end

module Plonk_verification_shifts = struct
  type 'field t = {r: 'field; o: 'field}
end

module Plonk_verifier_index = struct
  type ('field, 'urs, 'poly_comm) t =
    { domain: 'field Plonk_domain.t
    ; max_poly_size: int
    ; max_quot_size: int
    ; urs: 'urs
    ; evals: 'poly_comm Plonk_verification_evals.t
    ; shifts: 'field Plonk_verification_shifts.t }
end

module Plonk_gate = struct
  module Kind = struct
    type t =
      | Zero
      | Generic
      | Poseidon
      | Add1
      | Add2
      | Vbmul1
      | Vbmul2
      | Vbmul3
      | Endomul1
      | Endomul2
      | Endomul3
      | Endomul4
  end

  module Col = struct
    type t = L | R | O
  end

  module Wire = struct
    type t = {row: int; col: Col.t}
  end

  module Wires = struct
    type t = {row: int; l: Wire.t; r: Wire.t; o: Wire.t}
  end

  type 'a t = {kind: Kind.t; wires: Wires.t; c: 'a array}
end

module Plonk_proof = struct
  module Evaluations = struct
    type 'field t =
      { l: 'field array
      ; r: 'field array
      ; o: 'field array
      ; z: 'field array
      ; t: 'field array
      ; f: 'field array
      ; sigma1: 'field array
      ; sigma2: 'field array }
  end

  module Opening_proof = struct
    type ('field, 'g) t =
      {lr: ('g * 'g) array; delta: 'g; z1: 'field; z2: 'field; sg: 'g}
  end

  module Messages = struct
    type 'poly_comm t =
      { l_comm: 'poly_comm
      ; r_comm: 'poly_comm
      ; o_comm: 'poly_comm
      ; z_comm: 'poly_comm
      ; t_comm: 'poly_comm }
  end

  type ('field, 'g, 'poly_comm) t =
    { messages: 'poly_comm Messages.t
    ; proof: ('field, 'g) Opening_proof.t
    ; evals: 'field Evaluations.t * 'field Evaluations.t
    ; public: 'field array
    ; prev_challenges: ('field array * 'poly_comm) array }
end

module Oracles = struct
  module Random_oracles = struct
    type 'field t =
      { beta: 'field
      ; gamma: 'field
      ; alpha_chal: 'field Scalar_challenge.t
      ; alpha: 'field
      ; zeta: 'field
      ; v: 'field
      ; u: 'field
      ; zeta_chal: 'field Scalar_challenge.t
      ; v_chal: 'field Scalar_challenge.t
      ; u_chal: 'field Scalar_challenge.t }
  end

  type 'field t =
    { o: 'field Random_oracles.t
    ; p_eval: 'field * 'field
    ; opening_prechallenges: 'field array
    ; digest_before_evaluations: 'field }
end
