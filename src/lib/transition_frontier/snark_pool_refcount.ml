(** This module keeps track of the number of references from the breadcrumbs in the transition frontier to the work they require *)
open Protocols

open Core_kernel
open Coda_base
open Coda_transition_frontier

module type Inputs_intf = sig
  include Inputs.Inputs_intf

  module Breadcrumb :
    Transition_frontier_Breadcrumb_intf
    with type state_hash := State_hash.t
     and type external_transition_verified := External_transition.Verified.t
     and type staged_ledger := Staged_ledger.t
end

module Make (Inputs : Inputs_intf) = struct
  module Work = Inputs.Transaction_snark_work.Statement

  type t = int Work.Table.t

  let get_work (breadcrumb : Inputs.Breadcrumb.t) : Work.t Sequence.t =
    let ledger = Inputs.Breadcrumb.staged_ledger breadcrumb in
    let scan_state = Inputs.Staged_ledger.scan_state ledger in
    let work_to_do =
      Inputs.Staged_ledger.Scan_state.all_work_to_do scan_state
    in
    Or_error.ok_exn work_to_do

  (** Returns true if this update changed which elements are in the table
  (but not if the same elements exist with a different reference count) *)
  let add_breadcrumb_to_ref_table table breadcrumb : bool =
    Sequence.fold ~init:false (get_work breadcrumb) ~f:(fun acc work ->
        match Work.Table.find table work with
        | Some count ->
            Work.Table.set table ~key:work ~data:(count + 1) ;
            acc || false
        | None ->
            Work.Table.set table ~key:work ~data:1 ;
            acc || true )

  (** Returns true if this update changed which elements are in the table
  (but not if the same elements exist with a different reference count) *)
  let remove_breadcrumb_from_ref_table table breadcrumb : bool =
    Sequence.fold (get_work breadcrumb) ~init:false ~f:(fun acc work ->
        match Work.Table.find table work with
        | Some 1 ->
            Work.Table.remove table work ;
            acc || true
        | Some v ->
            Work.Table.set table ~key:work ~data:(v - 1) ;
            acc || false
        | None -> failwith "Removed a breadcrumb we didn't know about" )

  let create () = Work.Table.create ()

  let handle_diff t diff =
    if
      match (diff : Inputs.Breadcrumb.t Transition_frontier_diff.t) with
      | New_breadcrumb breadcrumb -> add_breadcrumb_to_ref_table t breadcrumb
      | New_best_tip {old_root; new_root; new_best_tip; garbage; _} ->
          let added = add_breadcrumb_to_ref_table t new_best_tip in
          let all_garbage =
            if phys_equal old_root new_root then garbage
            else old_root :: garbage
          in
          List.fold ~init:false
            ~f:(fun acc bc -> acc || remove_breadcrumb_from_ref_table t bc)
            all_garbage
          || added
    then Some t
    else None
end
