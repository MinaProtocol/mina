open Async_kernel
open Core_kernel
open Coda_base
open Coda_incremental
open Pipe_lib

module Make (Inputs : sig
  include Inputs.Inputs_intf

  module Breadcrumb :
    Coda_intf.Transition_frontier_breadcrumb_intf
    with type mostly_validated_external_transition :=
                ( [`Time_received] * unit Truth.true_t
                , [`Proof] * unit Truth.true_t
                , [`Delta_transition_chain]
                  * State_hash.t Non_empty_list.t Truth.true_t
                , [`Frontier_dependencies] * unit Truth.true_t
                , [`Staged_ledger_diff] * unit Truth.false_t )
                External_transition.Validation.with_transition
     and type external_transition_validated := External_transition.Validated.t
     and type staged_ledger := Staged_ledger.t
     and type verifier := Verifier.t

  module Diff :
    Coda_intf.Transition_frontier_diff_intf
    with type breadcrumb := Breadcrumb.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type external_transition_validated := External_transition.Validated.t
end) :
  Coda_intf.Transition_frontier_extensions_intf
  with type breadcrumb := Inputs.Breadcrumb.t
   and type external_transition_validated :=
              Inputs.External_transition.Validated.t
   and type transaction_snark_scan_state := Inputs.Staged_ledger.Scan_state.t
   and module Diff := Inputs.Diff = struct
  open Inputs

  module type Extension_intf =
    Coda_intf.Transition_frontier_extension_intf
    with type transition_frontier_diff := Diff.t

  module Work = Transaction_snark_work.Statement

  module Snark_pool_refcount = struct
    module Work = Inputs.Transaction_snark_work.Statement

    type t = int Work.Table.t

    type view = int * int Work.Table.t

    type input = unit

    let get_work (breadcrumb : Breadcrumb.t) : Work.t list =
      let ledger = Inputs.Breadcrumb.staged_ledger breadcrumb in
      let scan_state = Inputs.Staged_ledger.scan_state ledger in
      Inputs.Staged_ledger.Scan_state.all_work_statements scan_state

    (** Returns true if this update changed which elements are in the table
    (but not if the same elements exist with a different reference count) *)
    let add_breadcrumb_to_ref_table table breadcrumb : bool =
      List.fold ~init:false (get_work breadcrumb) ~f:(fun acc work ->
          match Work.Table.find table work with
          | Some count ->
              Work.Table.set table ~key:work ~data:(count + 1) ;
              acc
          | None ->
              Work.Table.set table ~key:work ~data:1 ;
              true )

    (** Returns true if this update changed which elements are in the table
    (but not if the same elements exist with a different reference count) *)
    let remove_breadcrumb_from_ref_table table breadcrumb : bool =
      List.fold (get_work breadcrumb) ~init:false ~f:(fun acc work ->
          match Work.Table.find table work with
          | Some 1 ->
              Work.Table.remove table work ;
              true
          | Some v ->
              Work.Table.set table ~key:work ~data:(v - 1) ;
              acc
          | None ->
              failwith "Removed a breadcrumb we didn't know about" )

    let create () = Work.Table.create ()

    let initial_view () = (0, Work.Table.create ())

    let handle_diff t diff =
      let removed, added =
        match (diff : Diff.t) with
        | New_breadcrumb {added= breadcrumb; _} | New_frontier breadcrumb ->
            (0, add_breadcrumb_to_ref_table t breadcrumb)
        | New_best_tip {old_root; new_root; added_to_best_tip_path; garbage; _}
          ->
            let added =
              add_breadcrumb_to_ref_table t
              @@ Non_empty_list.last added_to_best_tip_path
            in
            let all_garbage =
              if phys_equal old_root new_root then garbage
              else old_root :: garbage
            in
            ( List.fold ~init:0
                ~f:(fun acc bc ->
                  acc + if remove_breadcrumb_from_ref_table t bc then 1 else 0
                  )
                all_garbage
            , added )
      in
      if removed > 0 || added then Some (removed, t) else None
  end

  module Root_history = struct
    module Queue = Hash_queue.Make (State_hash)

    type t = {history: Breadcrumb.t Queue.t; capacity: int}

    let create capacity =
      let history = Queue.create () in
      {history; capacity}

    let lookup {history; _} = Queue.lookup history

    let most_recent {history; _} =
      let open Option.Let_syntax in
      let%map state_hash, breadcrumb = Queue.dequeue_back_with_key history in
      Queue.enqueue_back history state_hash breadcrumb |> ignore ;
      breadcrumb

    let oldest {history; _} =
      let open Option.Let_syntax in
      let%map state_hash, breadcrumb = Queue.dequeue_front_with_key history in
      Queue.enqueue_front history state_hash breadcrumb |> ignore ;
      breadcrumb

    let mem {history; _} = Queue.mem history

    let enqueue {history; capacity} state_hash breadcrumb =
      if Queue.length history >= capacity then
        Queue.dequeue_front_exn history |> ignore ;
      Queue.enqueue_back history state_hash breadcrumb |> ignore

    let is_empty {history; _} = Queue.is_empty history
  end

  (* TODO: guard against waiting for transitions that already exist in the frontier *)
  module Transition_registry = struct
    type t = unit Ivar.t list State_hash.Table.t

    let create () = State_hash.Table.create ()

    let notify t state_hash =
      State_hash.Table.change t state_hash ~f:(function
        | Some ls ->
            List.iter ls ~f:(Fn.flip Ivar.fill ()) ;
            None
        | None ->
            None )

    let register t state_hash =
      Deferred.create (fun ivar ->
          State_hash.Table.update t state_hash ~f:(function
            | Some ls ->
                ivar :: ls
            | None ->
                [ivar] ) )
  end

  type t =
    { root_history: Root_history.t
    ; snark_pool_refcount: Snark_pool_refcount.t
    ; transition_registry: Transition_registry.t
    ; best_tip_diff: Diff.Best_tip_diff.t
    ; root_diff: Diff.Root_diff.t
    ; persistence_diff: Diff.Persistence_diff.t
    ; new_transition: External_transition.Validated.t New_transition.Var.t }
  [@@deriving fields]

  (* TODO: Each of these extensions should be created with the input of the breadcrumb *)
  let create root_breadcrumb =
    let new_transition =
      New_transition.Var.create
        (Breadcrumb.validated_transition root_breadcrumb)
    in
    { root_history= Root_history.create (2 * max_length)
    ; snark_pool_refcount= Snark_pool_refcount.create ()
    ; transition_registry= Transition_registry.create ()
    ; best_tip_diff= Diff.Best_tip_diff.create ()
    ; root_diff= Diff.Root_diff.create ()
    ; persistence_diff= Diff.Persistence_diff.create ()
    ; new_transition }

  type writers =
    { snark_pool: Snark_pool_refcount.view Broadcast_pipe.Writer.t
    ; best_tip_diff: Diff.Best_tip_diff.view Broadcast_pipe.Writer.t
    ; root_diff: Diff.Root_diff.view Broadcast_pipe.Writer.t
    ; persistence_diff: Diff.Persistence_diff.view Broadcast_pipe.Writer.t }

  type readers =
    { snark_pool: Snark_pool_refcount.view Broadcast_pipe.Reader.t
    ; best_tip_diff: Diff.Best_tip_diff.view Broadcast_pipe.Reader.t
    ; root_diff: Diff.Root_diff.view Broadcast_pipe.Reader.t
    ; persistence_diff: Diff.Persistence_diff.view Broadcast_pipe.Reader.t }
  [@@deriving fields]

  let make_pipes () : readers * writers =
    let snark_reader, snark_writer =
      Broadcast_pipe.create (Snark_pool_refcount.initial_view ())
    and best_tip_reader, best_tip_writer =
      Broadcast_pipe.create (Diff.Best_tip_diff.initial_view ())
    and root_diff_reader, root_diff_writer =
      Broadcast_pipe.create (Diff.Root_diff.initial_view ())
    and persistence_diff_reader, persistence_diff_writer =
      Broadcast_pipe.create (Diff.Persistence_diff.initial_view ())
    in
    ( { snark_pool= snark_reader
      ; best_tip_diff= best_tip_reader
      ; root_diff= root_diff_reader
      ; persistence_diff= persistence_diff_reader }
    , { snark_pool= snark_writer
      ; best_tip_diff= best_tip_writer
      ; root_diff= root_diff_writer
      ; persistence_diff= persistence_diff_writer } )

  let close_pipes
      ({snark_pool; best_tip_diff; root_diff; persistence_diff} : writers) =
    Broadcast_pipe.Writer.close snark_pool ;
    Broadcast_pipe.Writer.close best_tip_diff ;
    Broadcast_pipe.Writer.close root_diff ;
    Broadcast_pipe.Writer.close persistence_diff

  let mb_write_to_pipe diff ext_t handle pipe =
    Option.value ~default:Deferred.unit
    @@ Option.map ~f:(Broadcast_pipe.Writer.write pipe) (handle ext_t diff)

  let handle_diff t (pipes : writers) (diff : Diff.t) : unit Deferred.t =
    let use handler pipe acc field =
      let%bind () = acc in
      mb_write_to_pipe diff (Field.get field t) handler pipe
    in
    ( match diff with
    | New_best_tip {old_root; new_root; _} ->
        if not (Breadcrumb.equal old_root new_root) then
          Root_history.enqueue t.root_history
            (Breadcrumb.state_hash old_root)
            old_root
    | _ ->
        () ) ;
    let%map () =
      Fields.fold ~init:diff
        ~root_history:(fun _ _ -> Deferred.unit)
        ~snark_pool_refcount:
          (use Snark_pool_refcount.handle_diff pipes.snark_pool)
        ~transition_registry:(fun acc _ -> acc)
        ~best_tip_diff:(use Diff.Best_tip_diff.handle_diff pipes.best_tip_diff)
        ~root_diff:(use Diff.Root_diff.handle_diff pipes.root_diff)
        ~persistence_diff:
          (use Diff.Persistence_diff.handle_diff pipes.persistence_diff)
        ~new_transition:(fun acc _ -> acc)
    in
    let bc_opt =
      match diff with
      | New_breadcrumb {added; _} ->
          Some added
      | New_best_tip {added_to_best_tip_path; _} ->
          Some (Non_empty_list.last added_to_best_tip_path)
      | _ ->
          None
    in
    Option.iter bc_opt ~f:(fun bc ->
        (* Other components may be waiting on these, so it's important they're
           updated after the views above so that those other components see
           the views updated with the new breadcrumb. *)
        Transition_registry.notify t.transition_registry
          (Breadcrumb.state_hash bc) ;
        New_transition.Var.set t.new_transition
        @@ Breadcrumb.validated_transition bc ;
        New_transition.stabilize () )
end
