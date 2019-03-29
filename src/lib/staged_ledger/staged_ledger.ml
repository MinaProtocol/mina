open Coda_base
open Signature_lib

module Inputs = Inputs
module Make = Functor.Make
include Functor.Make (struct
  module Compressed_public_key = Public_key.Compressed
  module User_command = User_command
  module Fee_transfer = Fee_transfer
  module Coinbase = Coinbase
  module Transaction = Transaction
  module Ledger_hash = Ledger_hash
  module Frozen_ledger_hash = Frozen_ledger_hash
  module Ledger_proof_statement = Transaction_snark.Statement
  module Proof = Proof
  module Sok_message = Sok_message
  module Ledger_proof = Ledger_proof
  module Ledger_proof_verifier = Transaction_snark.Verifier
  module Staged_ledger_aux_hash = struct
    include Staged_ledger_hash.Aux_hash.Stable.Latest

    let of_bytes = Staged_ledger_hash.Aux_hash.of_bytes

    let to_bytes = Staged_ledger_hash.Aux_hash.to_bytes
  end
  module Staged_ledger_hash = struct
    include Staged_ledger_hash.Stable.Latest

    let ledger_hash = Staged_ledger_hash.ledger_hash

    let aux_hash = Staged_ledger_hash.aux_hash

    let of_aux_and_ledger_hash = Staged_ledger_hash.of_aux_and_ledger_hash
  end
  module Transaction_snark_work = Transaction_snark_work
  module Staged_ledger_diff = Staged_ledger_diff
  module Account = Account
  module Ledger = Ledger
  module Transaction_validator = Transaction_validator
  module Sparse_ledger = Sparse_ledger
end)
