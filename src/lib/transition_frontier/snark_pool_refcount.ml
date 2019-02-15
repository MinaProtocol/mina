open Protocols
open Coda_base
open Coda_transition_frontier

module type Inputs_intf = sig
  include Transition_frontier0.Inputs_intf

  module Transition_frontier :
    Transition_frontier0.S
    with type state_hash := State_hash.t
     and type external_transition_verified := External_transition.Verified.t
     and type ledger_database := Ledger.Db.t
     and type staged_ledger := Staged_ledger.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type masked_ledger := Coda_base.Ledger.t
     and type consensus_local_state := Consensus.Local_state.t
end

module type S = Transition_frontier_extension_intf

module Make (Inputs : Inputs_intf) :
  S
  with type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t
   and type input := unit = struct
  module Work = Inputs.Transaction_snark_work.Statement

  type t = {ref_table: int Work.Table.t}

  let create () = {ref_table= Work.Table.create ()}

  (* TODO: implement diff-handling functionality *)
  let handle_diff (_t : t) _frontier
      (_diff :
        Inputs.Transition_frontier.Breadcrumb.t Transition_frontier_diff.t) =
    ()
end
