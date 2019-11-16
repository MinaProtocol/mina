[%%import
"/src/config.mlh"]

module type S = sig
  (** Log of the capacity of transactions per transition. 1 will only work if we don't have prover fees. 2 will work with prover fees, but not if we want a transaction included in every block. At least 3 ensures a transaction per block and the staged-ledger unit tests pass. *)
  val transaction_capacity_log_2 : int

  (** All the proofs before the last <work_delay> blocks are required to be completed to add transactions. <work_delay> is the minimum number of blocks and will increase if the throughput is less. If delay = 0, then all the work that was added to the scan state in the previous block is expected to be completed and included in the current block if any transactions/coinbase are to be included. Having a delay >= 1 means there's at least two block times for completing the proofs *)
  val work_delay : int
end
