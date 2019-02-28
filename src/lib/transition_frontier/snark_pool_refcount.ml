open Protocols
open Coda_base
open Coda_transition_frontier

module type Inputs_intf = sig
  include Inputs.Inputs_intf

  module Breadcrumb :
    Transition_frontier_Breadcrumb_intf
    with type state_hash := State_hash.t
     and type external_transition_verified := External_transition.Verified.t
     and type staged_ledger := Staged_ledger.t
     and type user_command := User_command.t
end

module Make (Inputs : Inputs_intf) :
  Transition_frontier_extension_intf0
  with type transition_frontier_breadcrumb := Inputs.Breadcrumb.t
   and type input = unit
   and type view = unit = struct
  module Work = Inputs.Transaction_snark_work.Statement

  type t = {ref_table: int Work.Table.t}

  type input = unit

  type view = unit

  let create () = {ref_table= Work.Table.create ()}

  let initial_view = ()

  (* TODO: implement diff-handling functionality *)
  let handle_diff (_t : t) _diff = None
end
