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

module Make (Inputs : Inputs_intf) :
  Transition_frontier_extension_intf
  with type transition_frontier_breadcrumb := Inputs.Breadcrumb.t
   and type input := unit
   and type view := int Inputs.Transaction_snark_work.Statement.Table.t =
struct
  module Work = Inputs.Transaction_snark_work.Statement

  type t = int Work.Table.t

  let get_work (breadcrumb : Inputs.Breadcrumb.t) : Work.t Sequence.t =
    let ledger = Inputs.Breadcrumb.staged_ledger breadcrumb in
    let scan_state = Inputs.Staged_ledger.scan_state ledger in
    let work_to_do =
      Inputs.Staged_ledger.Scan_state.all_work_to_do scan_state
    in
    Or_error.ok_exn work_to_do

  let add_breadcrumb_to_ref_table table breadcrumb =
    Sequence.iter (get_work breadcrumb) ~f:(fun work ->
        Work.Table.change table work ~f:(function
          | Some count -> Some (count + 1)
          | None -> Some 1 ) )

  let remove_breadcrumb_from_ref_table table breadcrumb =
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
    match (diff : Inputs.Breadcrumb.t Transition_frontier_diff.t) with
    | New_breadcrumb breadcrumb ->
        add_breadcrumb_to_ref_table t breadcrumb ;
        None
    | New_best_tip {old_root; new_root; new_best_tip; garbage; _} ->
        add_breadcrumb_to_ref_table t new_best_tip ;
        let all_garbage =
          if phys_equal old_root new_root then garbage else old_root :: garbage
        in
        let removed : bool =
          List.fold ~init:false
            ~f:(fun acc bc -> acc || remove_breadcrumb_from_ref_table t bc)
            all_garbage
        in
        if removed then Some t else None
end
