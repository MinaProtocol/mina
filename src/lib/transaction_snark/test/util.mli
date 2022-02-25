open Mina_base

val genesis_constants : Genesis_constants.t

val proof_level : Genesis_constants.Proof_level.t

val consensus_constants : Consensus.Constants.t

(* For tests, monkey patch ledger and sparse ledger to freeze their 
   ledger_hashes.
   The nominal type prevents using this in non-test code. *)
module Ledger : module type of Mina_ledger.Ledger

module Sparse_ledger : module type of Mina_ledger.Sparse_ledger

val ledger_depth : Ledger.index

include Transaction_snark.S

val state_body : Transaction_protocol_state.Block_data.t

val init_stack : Pending_coinbase.Stack_versioned.t

val apply_parties : Ledger.t -> Parties.t list -> unit * unit

val dummy_rule :
     (Snapp_statement.Checked.t, 'a, 'b, 'c) Pickles.Tag.t
  -> ( Snapp_statement.Checked.t * (Snapp_statement.Checked.t * unit)
     , 'a * ('a * unit)
     , 'b * ('b * unit)
     , 'c * ('c * unit)
     , 'd
     , 'e )
     Pickles.Inductive_rule.t
