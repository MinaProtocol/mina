open Core
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

let dot_product a b =
  List.fold_left ~init:Fr.zero ~f:Fr.( + ) (List.map2_exn a b ~f:Fr.( * ))

let satisfied (circuit : Arith_circuit.t) (assignment : Assignment.t) =
  let a_l = assignment.a_l in
  let a_r = assignment.a_r in
  let a_o = assignment.a_o in
  let (gate_weights : Gate_weights.t) = circuit.weights in
  let w_l = gate_weights.w_l in
  let w_r = gate_weights.w_r in
  let w_o = gate_weights.w_o in
  let cs = circuit.cs in
  let q = List.length cs in
  List.fold_left ~init:true ~f:( && )
    (List.map ~f:(fun i ->
      Fr.equal
        (Fr.( + )
          (Fr.( + ) (dot_product (List.nth_exn w_l i) a_l) (dot_product (List.nth_exn w_r i) a_r))
          ((dot_product (List.nth_exn w_o i) a_o)))
        (List.nth_exn cs i)
      ) (List.range 0 q))
