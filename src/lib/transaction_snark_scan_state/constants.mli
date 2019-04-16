(** Log of the capacity of transactions per transition. 1 will only work if we don't have prover fees. 2 will work with prover fees, but not if we want a transaction included in every block. At least 3 ensures we can have a transaction per block. *)
val transaction_capacity_log_2 : int

(** Log of number of block-times snark workers take to produce at least two proofs. Needs to be at least 2, increase this as needed to support slower SNARK workers *)
val work_delay_factor : int

(**latency factor (LF) decides how far to go up the tree before a ledger proof is emitted. If directly translates to the depth of the tree at which, all the transaction snarks are emitted and not merged any further. If L is the latency of the scan state at LF=0 (merge all the way up to the root of the tree) then for any lf, 0<= lf <= (work_delay_factor-1), the new latency is L/2^lf  *)
val latency_factor : int
