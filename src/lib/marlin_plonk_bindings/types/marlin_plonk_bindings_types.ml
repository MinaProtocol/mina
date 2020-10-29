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
