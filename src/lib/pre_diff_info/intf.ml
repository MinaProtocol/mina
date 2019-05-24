open Core
open Protocols.Coda_pow

module type Inputs = sig
  module Compressed_public_key : Compressed_public_key_intf

  module User_command :
    User_command_intf with type public_key := Compressed_public_key.t

  module Fee_transfer :
    Fee_transfer_intf with type public_key := Compressed_public_key.t

  module Coinbase :
    Coinbase_intf
    with type public_key := Compressed_public_key.t
     and type fee_transfer := Fee_transfer.Single.t

  module Pending_coinbase_hash : Pending_coinbase_hash_intf

  module Pending_coinbase :
    Pending_coinbase_intf
    with type pending_coinbase_hash := Pending_coinbase_hash.t
     and type coinbase := Coinbase.t

  module Pending_coinbase_stack_state :
    Pending_coinbase_stack_state_intf
    with type pending_coinbase_stack := Pending_coinbase.Stack.t

  module Ledger_hash : Ledger_hash_intf

  module Frozen_ledger_hash : sig
    include Ledger_hash_intf

    val of_ledger_hash : Ledger_hash.t -> t
  end

  module Ledger_proof_statement :
    Ledger_proof_statement_intf
    with type ledger_hash := Frozen_ledger_hash.t
     and type pending_coinbase_stack_state := Pending_coinbase_stack_state.t

  module Sok_message :
    Sok_message_intf with type public_key_compressed := Compressed_public_key.t

  module Proof : sig
    type t
  end

  module Ledger_proof : sig
    include
      Ledger_proof_intf
      with type statement := Ledger_proof_statement.t
       and type ledger_hash := Frozen_ledger_hash.t
       and type proof := Proof.t
       and type sok_digest := Sok_message.Digest.t

    include Sexpable.S with type t := t

    val statement : t -> Ledger_proof_statement.t
  end

  module Staged_ledger_aux_hash : Staged_ledger_aux_hash_intf

  module Staged_ledger_hash :
    Staged_ledger_hash_intf
    with type ledger_hash := Ledger_hash.t
     and type staged_ledger_aux_hash := Staged_ledger_aux_hash.t
     and type pending_coinbase := Pending_coinbase.t
     and type pending_coinbase_hash := Pending_coinbase_hash.t

  module Transaction_snark_work :
    Transaction_snark_work_intf
    with type proof := Ledger_proof.t
     and type statement := Ledger_proof_statement.t
     and type public_key := Compressed_public_key.t

  module Transaction :
    Transaction_intf
    with type valid_user_command := User_command.With_valid_signature.t
     and type fee_transfer := Fee_transfer.t
     and type coinbase := Coinbase.t

  module Staged_ledger_diff :
    Staged_ledger_diff_intf
    with type completed_work := Transaction_snark_work.t
     and type completed_work_checked := Transaction_snark_work.Checked.t
     and type user_command := User_command.t
     and type user_command_with_valid_signature :=
                User_command.With_valid_signature.t
     and type public_key := Compressed_public_key.t
     and type staged_ledger_hash := Staged_ledger_hash.t
     and type fee_transfer_single := Fee_transfer.Single.t
end

module type S = sig
  type user_command

  type transaction

  type completed_work

  type staged_ledger_diff

  type valid_staged_ledger_diff

  val get :
       staged_ledger_diff
    -> ( transaction list * completed_work list * int * Currency.Amount.t list
       , user_command Pre_diff_error.t )
       result

  val get_unchecked :
       valid_staged_ledger_diff
    -> transaction list * completed_work list * Currency.Amount.t list

  val get_transactions :
       staged_ledger_diff
    -> (transaction list, user_command Pre_diff_error.t) result
end
