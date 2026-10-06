open Async_kernel
open Core_kernel
open Mina_base
open Frontier_base

module T = struct
  type waiters = unit Ivar.t Int.Table.t

  type t = { mutable next_id : int; waiters : waiters State_hash.Table.t }

  type registration = { wait : unit Deferred.t; unregister : unit -> unit }

  type view = unit

  let name = "transition_registry"

  let create ~logger:_ _frontier =
    ({ next_id = 0; waiters = State_hash.Table.create () }, ())

  let advance_next_id t =
    let id = t.next_id in
    t.next_id <- (if Int.equal id Int.max_value then 0 else id + 1) ;
    id

  let rec fresh_id t waiters =
    let id = advance_next_id t in
    if Hashtbl.mem waiters id then fresh_id t waiters else id

  let find_or_add_waiters t state_hash =
    State_hash.Table.find_or_add t.waiters state_hash ~default:(fun () ->
        Int.Table.create () )

  let notify t state_hash =
    State_hash.Table.change t.waiters state_hash ~f:(function
      | Some waiters ->
          Hashtbl.iter waiters ~f:(fun ivar ->
              if Ivar.is_full ivar then
                [%log' error (Logger.create ())] "Ivar.fill bug is here!" ;
              Ivar.fill ivar () ) ;
          None
      | None ->
          None )

  let unregister_id t state_hash id =
    State_hash.Table.change t.waiters state_hash ~f:(function
      | Some waiters ->
          Hashtbl.remove waiters id ;
          if Hashtbl.is_empty waiters then None else Some waiters
      | None ->
          None )

  let register t state_hash =
    let ivar = Ivar.create () in
    let waiters = find_or_add_waiters t state_hash in
    let id = fresh_id t waiters in
    Hashtbl.add_exn waiters ~key:id ~data:ivar ;
    let unregistered = ref false in
    let unregister () =
      if not !unregistered then (
        unregistered := true ;
        if not (Ivar.is_full ivar) then unregister_id t state_hash id )
    in
    { wait = Ivar.read ivar; unregister }

  let wait { wait; _ } = wait

  let unregister { unregister; _ } = unregister ()

  let handle_diffs transition_registry _ diffs_with_mutants =
    List.iter diffs_with_mutants ~f:(function
      | Diff.Full.With_mutant.E (New_node (Full breadcrumb), _) ->
          notify transition_registry (Breadcrumb.state_hash breadcrumb)
      | _ ->
          () ) ;
    None
end

module Broadcasted = Functor.Make_broadcasted (T)
include T
