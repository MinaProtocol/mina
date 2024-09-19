open Mina_base
module Ledger = Mina_ledger.Ledger
module Sparse_ledger = Mina_ledger.Sparse_ledger

type ledger_witness =
  { witness : Sparse_ledger.t
  ; source_hash : Ledger_hash.t
  ; target_hash : Ledger_hash.t
  }

type light_statement =
  { supply_increase : Currency.Amount.Signed.t
  ; fee_excess : Fee_excess.Stable.V1.t
  }

type 'ledger_witness t =
  { transaction_with_info : Mina_transaction_logic.Transaction_applied.Varying.t
  ; state_hash : State_hash.t * State_body_hash.t
  ; statement : light_statement
  ; init_stack : Transaction_snark.Pending_coinbase_stack_state.Init_stack.t
  ; first_pass : 'ledger_witness
  ; second_pass : 'ledger_witness
  ; block_global_slot : Mina_numbers.Global_slot_since_genesis.t
  ; pending_coinbase_stack_source : Pending_coinbase.Stack_versioned.t
  ; pending_coinbase_stack_target : Pending_coinbase.Stack_versioned.t
  }

type light = unit t

module type Compute_intf = sig
  type pre_witness

  type witness

  type nonrec t = witness t

  val compute_source :
    accounts_accessed:Account_id.t list -> Ledger.t -> pre_witness

  val compute : pre_witness -> Ledger.t -> witness
end

module Full :
  Compute_intf
    with type witness = ledger_witness
     and type pre_witness = Ledger_hash.t * Sparse_ledger.t = struct
  type nonrec t = ledger_witness t

  type witness = ledger_witness

  type pre_witness = Ledger_hash.t * Sparse_ledger.t

  let compute_source ~accounts_accessed ledger =
    ( Ledger.merkle_root ledger
    , Sparse_ledger.of_ledger_subset_exn ledger accounts_accessed )

  let compute (source_hash, witness) ledger =
    { source_hash; witness; target_hash = Ledger.merkle_root ledger }
end

module Light :
  Compute_intf with type witness = unit and type pre_witness = unit = struct
  type nonrec t = unit t

  type witness = unit

  type pre_witness = unit

  let compute_source ~accounts_accessed:_ _ledger = ()

  let compute () _ledger = ()
end
