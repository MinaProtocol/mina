open Core
open Protocols

module type S = sig
  open Coda_pow

  module Compressed_public_key : Compressed_public_key_intf

  module User_command :
    Coda_pow.User_command_intf with type public_key := Compressed_public_key.t

  module Fee_transfer :
    Coda_pow.Fee_transfer_intf with type public_key := Compressed_public_key.t

  module Coinbase :
    Coda_pow.Coinbase_intf
    with type public_key := Compressed_public_key.t
     and type fee_transfer := Fee_transfer.single

  module Transaction :
    Coda_pow.Transaction_intf
    with type valid_user_command := User_command.With_valid_signature.t
     and type fee_transfer := Fee_transfer.t
     and type coinbase := Coinbase.t

  module Ledger_hash : Coda_pow.Ledger_hash_intf

  module Frozen_ledger_hash : sig
    include Coda_pow.Ledger_hash_intf

    val of_ledger_hash : Ledger_hash.t -> t
  end

  module Pending_coinbase_hash : Coda_pow.Pending_coinbase_hash_intf

  module Pending_coinbase :
    Coda_pow.Pending_coinbase_intf
    with type pending_coinbase_hash := Pending_coinbase_hash.t
     and type coinbase := Coinbase.t

  module Pending_coinbase_stack_state :
    Coda_pow.Pending_coinbase_stack_state_intf
    with type pending_coinbase_stack := Pending_coinbase.Stack.t

  module Ledger_proof_statement :
    Coda_pow.Ledger_proof_statement_intf
    with type ledger_hash := Frozen_ledger_hash.t
     and type pending_coinbase_stack_state := Pending_coinbase_stack_state.t

  module Proof : sig
    type t
  end

  module Sok_message :
    Sok_message_intf with type public_key_compressed := Compressed_public_key.t

  module Ledger_proof : sig
    include
      Coda_pow.Ledger_proof_intf
      with type statement := Ledger_proof_statement.t
       and type ledger_hash := Frozen_ledger_hash.t
       and type proof := Proof.t
       and type sok_digest := Sok_message.Digest.t

    include Sexpable.S with type t := t
  end

  module Ledger_proof_verifier :
    Ledger_proof_verifier_intf
    with type statement := Ledger_proof_statement.t
     and type message := Sok_message.t
     and type ledger_proof := Ledger_proof.t

  module Staged_ledger_aux_hash : Coda_pow.Staged_ledger_aux_hash_intf

  module Staged_ledger_hash :
    Coda_pow.Staged_ledger_hash_intf
    with type ledger_hash := Ledger_hash.t
     and type staged_ledger_aux_hash := Staged_ledger_aux_hash.t
     and type pending_coinbase := Pending_coinbase.t
     and type pending_coinbase_hash := Pending_coinbase_hash.t

  module Transaction_snark_work :
    Coda_pow.Transaction_snark_work_intf
    with type proof := Ledger_proof.t
     and type statement := Ledger_proof_statement.t
     and type public_key := Compressed_public_key.t

  module Staged_ledger_diff :
    Coda_pow.Staged_ledger_diff_intf
    with type completed_work := Transaction_snark_work.t
     and type completed_work_checked := Transaction_snark_work.Checked.t
     and type user_command := User_command.t
     and type user_command_with_valid_signature :=
                User_command.With_valid_signature.t
     and type public_key := Compressed_public_key.t
     and type staged_ledger_hash := Staged_ledger_hash.t
     and type fee_transfer_single := Fee_transfer.single

  module Account : sig
    type t
  end

  module Ledger :
    Coda_pow.Ledger_intf
    with type ledger_hash := Ledger_hash.t
     and type transaction := Transaction.t
     and type valid_user_command := User_command.With_valid_signature.t
     and type account := Account.t

  module Transaction_validator :
    Coda_pow.Transaction_validator_intf
    with type outer_ledger := Ledger.t
     and type transaction := Transaction.t
     and type user_command_with_valid_signature :=
                User_command.With_valid_signature.t
     and type ledger_hash := Ledger_hash.t

  module Sparse_ledger : sig
    type t [@@deriving sexp, bin_io]

    val of_ledger_subset_exn : Ledger.t -> Compressed_public_key.t list -> t

    val merkle_root : t -> Ledger_hash.t

    val apply_transaction_exn : t -> Transaction.t -> t
  end

  module Transaction_witness :
    Coda_pow.Transaction_witness_intf
    with type sparse_ledger := Sparse_ledger.t
end
