open Default_backend.Backend

module Arith_circuit_proof = struct
  type t =
    { tBlinding: Fr.t
    ; mu: Fr.t
    ; tt: Fr.t
    ; aiCommit: G1.t (* commitments are elements of G1 *)
    ; aoCommit: G1.t
    ; sCommit: G1.t
    ; tCommits: G1.t list (*; productProof : InnerProductProof.t *) }
end

module Gate_weights = struct
  type t = {w_l: Fr.t list list; w_r: Fr.t list list; w_o: Fr.t list list}
  [@@deriving eq]
end

module Arith_circuit = struct
  type t =
    {weights: Gate_weights.t; commitment_weights: Fr.t list list; cs: Fr.t list}
  [@@deriving eq]
end

module Assignment = struct
  type t = {a_l: Fr.t list; a_r: Fr.t list; a_o: Fr.t list} [@@deriving eq]
end

module Arith_witness = struct
  type t =
    { assignment: Assignment.t
    ; commitments: G1.t list
    ; commitBlinders: Fr.t list }
end
