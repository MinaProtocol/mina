open Pickles_types

let blockchain_proof () =
    Pickles.Proof.dummy Nat.N2.n Nat.N2.n Nat.N2.n ~domain_log2:16

let transaction_proof () =
    Pickles.Proof.dummy Nat.N2.n Nat.N2.n Nat.N0.n ~domain_log2:14