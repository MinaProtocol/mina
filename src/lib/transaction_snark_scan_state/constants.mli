val transaction_capacity_log_2 : int
(** Log of the capacity of transactions per transition. 1 will only work if we don't have prover fees. 2 will work with prover fees, but not if we want a transaction included in every block. At least 3 ensures we can have a transaction per block. *)

val work_delay_factor : int
(** Log of number of block-times snark workers take to produce at least two proofs. Needs to be at least 2, increase this as needed to support slower SNARK workers *)
