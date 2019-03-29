open Coda_base

include Inputs

module Make = Functor.Make

include Make(struct
  module Staged_ledger_aux_hash = struct
    include Staged_ledger_hash.Aux_hash.Stable.Latest

    let of_bytes = Staged_ledger_hash.Aux_hash.of_bytes

    let to_bytes = Staged_ledger_hash.Aux_hash.to_bytes
  end
  module Ledger_proof_statement = Transaction_snark.Statement
  module Ledger_proof = Ledger_proof
  module Transaction_snark_work = Transaction_snark_work
  module Staged_ledger = Staged_ledger
  let max_length = Consensus.Constants.k
end)
