module Or_infinite = struct
  type 'a t = Infinite | Finite of 'a
end

module Poly_comm = struct
  type 'a t = {shifted: 'a option; unshifted: 'a array}
end

module Plonk_domain = struct
  type 'field t = {log_size_of_group: int; group_gen: 'field}
end

module Plonk_verification_evals = struct
  type 'poly_comm t =
    { sigma_comm0: 'poly_comm
    ; sigma_comm1: 'poly_comm
    ; sigma_comm2: 'poly_comm
    ; ql_comm: 'poly_comm
    ; qr_comm: 'poly_comm
    ; qo_comm: 'poly_comm
    ; qm_comm: 'poly_comm
    ; qc_comm: 'poly_comm
    ; rcm_comm0: 'poly_comm
    ; rcm_comm1: 'poly_comm
    ; rcm_comm2: 'poly_comm
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
