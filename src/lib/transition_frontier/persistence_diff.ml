(** A transition frontier extension that exposes the changes in the transactions
    in the best tip. *)

open Core
open Coda_base
open Protocols.Coda_pow

module type Inputs_intf = sig
  include Inputs.Inputs_intf

  module Breadcrumb :
    Transition_frontier_Breadcrumb_intf
    with type state_hash := State_hash.t
     and type staged_ledger := Staged_ledger.t
     and type external_transition_verified := External_transition.Verified.t
     and type user_command := User_command.t
end

module Make (Inputs : Inputs_intf) :
  Transition_frontier_extension_intf0
  with type transition_frontier_breadcrumb := Inputs.Breadcrumb.t
   and type input = unit
   and type view = Inputs.Diff_mutant.e option = struct
  open Inputs

  type t = unit

  type input = unit

  type view = Diff_mutant.e option

  let create () = ()

  let initial_view () = None

  let state_hash = Fn.compose With_hash.hash Breadcrumb.transition_with_hash

  let get_transition breadcrumb =
    let {With_hash.data= external_transition; hash} =
      Breadcrumb.transition_with_hash breadcrumb
    in
    {With_hash.data= External_transition.of_verified external_transition; hash}

  let scan_state breadcrumb =
    breadcrumb |> Breadcrumb.staged_ledger |> Staged_ledger.scan_state

  let handle_diff () diff : view option =
    let open Transition_frontier_diff in
    Option.return @@ Option.return
    @@
    match diff with
    | New_breadcrumb breadcrumb ->
        Diff_mutant.E (Add_transition (get_transition breadcrumb))
    | New_best_tip {garbage; added_to_best_tip_path; new_root; _} ->
        let removed_transitions = List.map garbage ~f:state_hash in
        let best_tip =
          Non_empty_list.last added_to_best_tip_path |> get_transition
        in
        let new_scan_state = scan_state new_root in
        let new_root = state_hash new_root in
        E (Move_root {removed_transitions; best_tip; new_scan_state; new_root})
end
