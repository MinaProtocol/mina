open Snarkette.Mnt6_80
module Fq_target = Fq6
module Fr = Snarkette.Mnt4_80.Fq

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
  type t = {wL: Fr.t list list; wR: Fr.t list list; wO: Fr.t list list}
  [@@deriving eq]
end

module Arith_circuit = struct
  type t =
    {weights: Gate_weights.t; commitment_weights: Fr.t list list; cs: Fr.t list}
  [@@deriving eq]
end

module Assignment = struct
  type t = {aL: Fr.t list; aR: Fr.t list; aO: Fr.t list} [@@deriving eq]
end

module Arith_witness = struct
  type t =
    { assignment: Assignment.t
    ; commitments: G1.t list
    ; commitBlinders: Fr.t list }
end
