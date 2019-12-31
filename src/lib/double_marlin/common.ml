open Pickles_types

let dlog_pcs_batch ~domain_h ~domain_k =
  let h = Domain.size domain_h in
  let k = Domain.size domain_k in
  Pcs_batch.create ~without_degree_bound:Nat.N18.n
    ~with_degree_bound:[h - 1; h - 1; k - 1]

let pairing_beta_1_pcs_batch ~domain_h =
  let h = Domain.size domain_h in
  Pcs_batch.create ~without_degree_bound:Nat.N6.n ~with_degree_bound:[h - 1]

let pairing_beta_2_pcs_batch ~domain_h =
  let h = Domain.size domain_h in
  Pcs_batch.create ~without_degree_bound:Nat.N1.n ~with_degree_bound:[h - 1]

let pairing_beta_3_pcs_batch ~domain_k =
  let k = Domain.size domain_k in
  Pcs_batch.create ~without_degree_bound:Nat.N10.n ~with_degree_bound:[k - 1]
