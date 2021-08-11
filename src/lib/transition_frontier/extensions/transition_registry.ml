open Async_kernel
open Core_kernel
open Mina_base
open Frontier_base

module T = struct
  type t = unit Ivar.t list State_hash.Table.t

  type view = unit

  let create ~logger:_ _frontier = (State_hash.Table.create (), ())

  let notify t state_hash =
    State_hash.Table.change t state_hash ~f:(function
      | Some ls ->
          List.iter ls ~f:(fun ivar ->
              if Ivar.is_full ivar then
                [%log' error (Logger.create ())] "Ivar.fill bug is here!" ;
              Ivar.fill ivar ()) ;
          None
      | None ->
          None)

  let register t state_hash =
    Deferred.create (fun ivar ->
        State_hash.Table.update t state_hash ~f:(function
          | Some ls ->
              ivar :: ls
          | None ->
              [ ivar ]))

  let handle_diffs transition_registry _ diffs_with_mutants =
    List.iter diffs_with_mutants ~f:(function
      | Diff.Full.With_mutant.E (New_node (Full breadcrumb), _) ->
          notify transition_registry (Breadcrumb.state_hash breadcrumb)
      | _ ->
          ()) ;
    None
end

module Broadcasted = Functor.Make_broadcasted (T)
include T
