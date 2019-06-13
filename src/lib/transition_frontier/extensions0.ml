open Async_kernel
open Core_kernel
open Coda_base
open Pipe_lib

module Make (Inputs : sig
  include Inputs.Inputs_intf

  module Transition_frontier :
    Coda_intf.Transition_frontier_base0_intf
    with type mostly_validated_external_transition :=
                ( [`Time_received] * Truth.true_t
                , [`Proof] * Truth.true_t
                , [`Frontier_dependencies] * Truth.true_t
                , [`Staged_ledger_diff] * Truth.false_t )
                External_transition.Validation.with_transition
     and type external_transition_validated := External_transition.Validated.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type verifier := Verifier.t

  module Diff :
    Coda_intf.Transition_frontier_diff0_intf
    with type breadcrumb := Transition_frontier.Breadcrumb.t
     and type external_transition_validated := External_transition.Validated.t
end) =
struct
  (* Have to treat functor Transition_frontier as Inputs.Transition_frontier *)
  (* Invariant: No mutations are allowed to the transition_frontier on the transactions *)
  open Inputs
  module Breadcrumb = Inputs.Transition_frontier.Breadcrumb

  module Root_history = struct
    module Queue = Hash_queue.Make (State_hash)

    type t = {history: Breadcrumb.t Queue.t; capacity: int}

    let create capacity =
      let history = Queue.create () in
      {history; capacity}

    let lookup {history; _} = Queue.lookup history

    let mem {history; _} = Queue.mem history

    let enqueue {history; capacity} breadcrumb =
      if Queue.length history >= capacity then
        Queue.dequeue_front_exn history |> ignore ;
      Queue.enqueue_back history (Breadcrumb.state_hash breadcrumb) breadcrumb
      |> ignore

    let is_empty {history; _} = Queue.is_empty history
  end

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

  module type Base_ext_intf = sig
    type t

    type view

    val create : Breadcrumb.t -> t * view

    val handle_diffs :
         t
      -> Inputs.Transition_frontier.t
      -> Diff.E.t list
      -> view Deferred.Option.t
  end

  module type Broadcast_extension_intf = sig
    type t

    type view

    val create : Breadcrumb.t -> t Deferred.t

    val peek : t -> view

    val update :
      t -> Inputs.Transition_frontier.t -> Diff.E.t list -> unit Deferred.t
  end

  module Make_broadcastable (Ext : Base_ext_intf) :
    Broadcast_extension_intf with type view = Ext.view = struct
    type t =
      { t: Ext.t
      ; writer: Ext.view Broadcast_pipe.Writer.t
      ; reader: Ext.view Broadcast_pipe.Reader.t }

    type view = Ext.view

    let peek {reader; _} = Broadcast_pipe.Reader.peek reader

    let create breadcrumb =
      let t, initial_view = Ext.create breadcrumb in
      let reader, writer = Broadcast_pipe.create initial_view in
      let%map () = Broadcast_pipe.Writer.write writer initial_view in
      {t; reader; writer}

    let update {t; writer; _} transition_frontier diffs =
      match%bind Ext.handle_diffs t transition_frontier diffs with
      | Some view ->
          Broadcast_pipe.Writer.write writer view
      | None ->
          Deferred.unit
  end

  module Extensions = struct
    module Root_history = struct
      type t = Root_history.t

      module View : sig
        type t = private Root_history.t

        val lookup : t -> State_hash.t -> Breadcrumb.t option

        val to_view : Root_history.t -> t

        val mem : t -> State_hash.t -> bool

        val is_empty : t -> bool
      end = struct
        include Root_history

        let to_view = Fn.id
      end

      type view = View.t

      let create breadcrumb =
        let root_history = Root_history.create (2 * Inputs.max_length) in
        Root_history.enqueue root_history breadcrumb ;
        (root_history, View.to_view root_history)

      let handle_diffs root_history transition_frontier diffs =
        let should_produce_view =
          List.exists diffs ~f:(function
            | Diff.E.E (Diff.Root_transitioned _) ->
                Root_history.enqueue root_history
                  (Inputs.Transition_frontier.root transition_frontier) ;
                true
            | Diff.E.E _ ->
                false )
        in
        Deferred.return
        @@ Option.some_if should_produce_view
        @@ View.to_view root_history
    end

    module Transition_registry = struct
      type t = Transition_registry.t

      type view = Transition_registry.t

      let create (_ : Breadcrumb.t) =
        let registry = Transition_registry.create () in
        (registry, registry)

      let handle_diffs transition_registry transition_frontier diffs =
        let should_produce_view =
          List.exists diffs ~f:(function
            | Diff.E.E (Diff.New_breadcrumb breadcrumb) ->
                let state_hash = Breadcrumb.state_hash breadcrumb in
                Transition_registry.notify transition_registry state_hash ;
                Ivar.fill ivar () ;
                true
            | Diff.E.E _ ->
                false )
        in
        Deferred.return
        @@ Option.some_if should_produce_view
        @@ View.to_view transition_registry
    end

    module Snark_pool_refcount = struct
      module Work = Inputs.Transaction_snark_work.Statement

      type t = int Work.Table.t

      type view = int * int Work.Table.t

      type input = unit

      let get_work (breadcrumb : Breadcrumb.t) : Work.t Sequence.t =
        let staged_ledger =
          Inputs.Transition_frontier.Breadcrumb.staged_ledger breadcrumb
        in
        let scan_state = Inputs.Staged_ledger.scan_state staged_ledger in
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
                acc
            | None ->
                Work.Table.set table ~key:work ~data:1 ;
                true )

      (** Returns true if this update changed which elements are in the table
          (but not if the same elements exist with a different reference count) *)
      let remove_breadcrumb_from_ref_table table breadcrumb : bool =
        Sequence.fold (get_work breadcrumb) ~init:false ~f:(fun acc work ->
            match Work.Table.find table work with
            | Some 1 ->
                Work.Table.remove table work ;
                true
            | Some v ->
                Work.Table.set table ~key:work ~data:(v - 1) ;
                acc
            | None ->
                failwith "Removed a breadcrumb we didn't know about" )

      let create breadcrumb =
        let t = Work.Table.create () in
        let (_ : bool) = add_breadcrumb_to_ref_table t breadcrumb in
        (t, (0, t))

      type diff_update = {num_removed: int; is_added: bool}

      let handle_diffs t (_ : Inputs.Transition_frontier.t) diffs =
        let {num_removed; is_added} =
          List.fold diffs ~init:{num_removed= 0; is_added= false}
            ~f:(fun ({num_removed; is_added} as init) -> function
            | Diff.E.E (New_breadcrumb breadcrumb) ->
                { num_removed
                ; is_added=
                    is_added || add_breadcrumb_to_ref_table t breadcrumb }
            | Diff.E.E (Root_transitioned {new_= _; garbage}) ->
                let extra_num_removed =
                  List.fold ~init:0
                    ~f:(fun acc bc ->
                      acc
                      + if remove_breadcrumb_from_ref_table t bc then 1 else 0
                      )
                    garbage
                in
                {num_removed= num_removed + extra_num_removed; is_added}
            | Diff.E.E (Best_tip_changed _) ->
                init )
        in
        Deferred.return
          (if num_removed > 0 || is_added then Some (num_removed, t) else None)
    end

    module Best_tip_diff = struct
      type t = unit

      type input = unit

      type view =
        { new_user_commands: User_command.t list
        ; removed_user_commands: User_command.t list }

      let create breadcrumb =
        ( ()
        , { new_user_commands= Breadcrumb.to_user_commands breadcrumb
          ; removed_user_commands= [] } )

      let common_ancestor (t : Inputs.Transition_frontier.t)
          (bc1 : Breadcrumb.t) (bc2 : Breadcrumb.t) : State_hash.t =
        let rec go ancestors1 ancestors2 sh1 sh2 =
          Hash_set.add ancestors1 sh1 ;
          Hash_set.add ancestors2 sh2 ;
          if Hash_set.mem ancestors1 sh2 then sh2
          else if Hash_set.mem ancestors2 sh1 then sh1
          else
            let open Inputs.Transition_frontier in
            let parent_unless_root sh =
              if State_hash.equal sh (Breadcrumb.state_hash @@ root t) then sh
              else Breadcrumb.parent_hash (find_exn t sh)
            in
            go ancestors1 ancestors2 (parent_unless_root sh1)
              (parent_unless_root sh2)
        in
        go
          (Hash_set.create (module State_hash) ())
          (Hash_set.create (module State_hash) ())
          (Breadcrumb.state_hash bc1)
          (Breadcrumb.state_hash bc2)

      (* TODO: Might be an error *)
      (* Get the breadcrumbs that are on bc1's path but not bc2's, and vice versa.
         Ordered oldest to newest.
      *)
      let get_path_diff t (bc1 : Breadcrumb.t) (bc2 : Breadcrumb.t) :
          Breadcrumb.t list * Breadcrumb.t list =
        let ancestor = common_ancestor t bc1 bc2 in
        (* Find the breadcrumbs connecting bc1 and bc2, excluding bc1. Precondition:
           bc1 is an ancestor of bc2. *)
        let open Inputs.Transition_frontier in
        let path_from_to bc1 bc2 =
          let rec go cursor acc =
            if Breadcrumb.equal cursor bc1 then acc
            else
              go (find_exn t @@ Breadcrumb.parent_hash cursor) (cursor :: acc)
          in
          go bc2 []
        in
        Logger.debug (logger t) ~module_:__MODULE__ ~location:__LOC__
          !"Common ancestor: %{sexp: State_hash.t}"
          ancestor ;
        ( path_from_to (find_exn t ancestor) bc1
        , path_from_to (find_exn t ancestor) bc2 )

      let handle_diffs () transition_frontier diffs : view Deferred.Option.t =
        let old_best_tip =
          Inputs.Transition_frontier.best_tip transition_frontier
        in
        let view, _, should_broadcast =
          List.fold diffs
            ~init:
              ( {new_user_commands= []; removed_user_commands= []}
              , old_best_tip
              , false )
            ~f:
              (fun ( ({new_user_commands; removed_user_commands} as acc)
                   , old_best_tip
                   , should_broadcast ) -> function
              | Diff.E.E (Best_tip_changed new_best_tip_breadcrumb) ->
                  (* TODO: probably do not use state_hash and use breadcrumb *)
                  let added_to_best_tip_path, removed_from_best_tip_path =
                    get_path_diff transition_frontier new_best_tip_breadcrumb
                      old_best_tip
                  in
                  Logger.debug
                    (Inputs.Transition_frontier.logger transition_frontier)
                    ~module_:__MODULE__ ~location:__LOC__
                    "added %d breadcrumbs and removed %d making path to new \
                     best tip"
                    (List.length added_to_best_tip_path)
                    (List.length removed_from_best_tip_path)
                    ~metadata:
                      [ ( "new_breadcrumbs"
                        , `List
                            (List.map ~f:Breadcrumb.to_yojson
                               added_to_best_tip_path) )
                      ; ( "old_breadcrumbs"
                        , `List
                            (List.map ~f:Breadcrumb.to_yojson
                               removed_from_best_tip_path) ) ] ;
                  let new_user_commands =
                    List.bind added_to_best_tip_path
                      ~f:Breadcrumb.to_user_commands
                    @ new_user_commands
                  in
                  let removed_user_commands =
                    List.bind removed_from_best_tip_path
                      ~f:Breadcrumb.to_user_commands
                    @ removed_user_commands
                  in
                  ( {new_user_commands; removed_user_commands}
                  , new_best_tip_breadcrumb
                  , true ) | Diff.E.E (New_breadcrumb _) ->
                  (acc, old_best_tip, should_broadcast)
              | Diff.E.E (Root_transitioned _) ->
                  (acc, old_best_tip, should_broadcast) )
        in
        Deferred.return @@ Option.some_if should_broadcast view
    end

    (* TODO: write with_side effect diff here *)
  end

  module Broadcast = struct
    open Extensions
    module Root_history = Make_broadcastable (Root_history)
    module Snark_pool_refcount = Make_broadcastable (Snark_pool_refcount)
    module Best_tip_diff = Make_broadcastable (Best_tip_diff)
  end

  type t =
    { root_history: Broadcast.Root_history.t
    ; snark_pool_refcount: Broadcast.Snark_pool_refcount.t
    ; best_tip_diff: Broadcast.Best_tip_diff.t }
  [@@deriving fields]

  let create (breadcrumb : Breadcrumb.t) =
    let%bind root_history = Broadcast.Root_history.create breadcrumb in
    let%bind snark_pool_refcount =
      Broadcast.Snark_pool_refcount.create breadcrumb
    in
    let%map best_tip_diff = Broadcast.Best_tip_diff.create breadcrumb in
    {root_history; snark_pool_refcount; best_tip_diff}

  let update_all (t : t) transition_frontier diffs =
    let run_update (type t)
        (module Broadcast : Broadcast_extension_intf with type t = t)
        (deferred_unit : unit Deferred.t) field =
      let%bind () = deferred_unit in
      let extension = Field.get field t in
      Broadcast.update extension transition_frontier diffs
    in
    let open Broadcast in
    Fields.fold ~init:Deferred.unit
      ~root_history:(run_update (module Root_history))
      ~snark_pool_refcount:(run_update (module Snark_pool_refcount))
      ~best_tip_diff:(run_update (module Best_tip_diff))
end
