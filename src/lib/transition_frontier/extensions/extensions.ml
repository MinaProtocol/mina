open Async_kernel
open Core_kernel
open Pipe_lib
module Best_tip_diff = Best_tip_diff
module Identity = Identity
module Root_history = Root_history
module Snark_pool_refcount = Snark_pool_refcount
module Transition_registry = Transition_registry
module New_breadcrumbs = New_breadcrumbs
module Ledger_table = Ledger_table

type t =
  { root_history : Root_history.Broadcasted.t
  ; snark_pool_refcount : Snark_pool_refcount.Broadcasted.t
  ; best_tip_diff : Best_tip_diff.Broadcasted.t
  ; transition_registry : Transition_registry.Broadcasted.t
  ; ledger_table : Ledger_table.Broadcasted.t
  ; identity : Identity.Broadcasted.t
  ; new_breadcrumbs : New_breadcrumbs.Broadcasted.t
  }
[@@deriving fields]

let create ~logger frontier : t Deferred.t =
  let open Deferred.Let_syntax in
  let%bind root_history =
    Root_history.(Broadcasted.create (create ~logger frontier))
  in
  let%bind snark_pool_refcount =
    Snark_pool_refcount.(Broadcasted.create (create ~logger frontier))
  in
  let%bind best_tip_diff =
    Best_tip_diff.(Broadcasted.create (create ~logger frontier))
  in
  let%bind transition_registry =
    Transition_registry.(Broadcasted.create (create ~logger frontier))
  in
  let%bind identity = Identity.(Broadcasted.create (create ~logger frontier)) in
  let%bind new_breadcrumbs =
    New_breadcrumbs.(Broadcasted.create (create ~logger frontier))
  in
  let%bind ledger_table =
    Ledger_table.(Broadcasted.create (create ~logger frontier))
  in
  return
    { root_history
    ; snark_pool_refcount
    ; best_tip_diff
    ; transition_registry
    ; identity
    ; ledger_table
    ; new_breadcrumbs
    }

(* HACK: A way to ensure that all the pipes are closed in a type-safe manner *)
let close t : unit =
  let close_extension (type t)
      (module B : Intf.Broadcasted_extension_intf with type t = t) field =
    B.close (Field.get field t)
  in
  Fields.iter
    ~root_history:(close_extension (module Root_history.Broadcasted))
    ~snark_pool_refcount:
      (close_extension (module Snark_pool_refcount.Broadcasted))
    ~best_tip_diff:(close_extension (module Best_tip_diff.Broadcasted))
    ~transition_registry:
      (close_extension (module Transition_registry.Broadcasted))
    ~ledger_table:(close_extension (module Ledger_table.Broadcasted))
    ~identity:(close_extension (module Identity.Broadcasted))
    ~new_breadcrumbs:(close_extension (module New_breadcrumbs.Broadcasted))

let notify (t : t) ~frontier ~diffs_with_mutants =
  let update (type t)
      (module B : Intf.Broadcasted_extension_intf with type t = t) field =
    B.update (Field.get field t) frontier diffs_with_mutants
  in
  Deferred.List.all_unit
    (Fields.to_list
       ~root_history:(update (module Root_history.Broadcasted))
       ~snark_pool_refcount:(update (module Snark_pool_refcount.Broadcasted))
       ~best_tip_diff:(update (module Best_tip_diff.Broadcasted))
       ~transition_registry:(update (module Transition_registry.Broadcasted))
       ~ledger_table:(update (module Ledger_table.Broadcasted))
       ~new_breadcrumbs:(update (module New_breadcrumbs.Broadcasted))
       ~identity:(update (module Identity.Broadcasted)) )

type ('ext, 'view) access =
  | Root_history : (Root_history.t, Root_history.view) access
  | Snark_pool_refcount
      : (Snark_pool_refcount.t, Snark_pool_refcount.view) access
  | Best_tip_diff : (Best_tip_diff.t, Best_tip_diff.view) access
  | Transition_registry
      : (Transition_registry.t, Transition_registry.view) access
  | Ledger_table : (Ledger_table.t, Ledger_table.view) access
  | Identity : (Identity.t, Identity.view) access
  | New_breadcrumbs : (New_breadcrumbs.t, New_breadcrumbs.view) access

type ('ext, 'view) broadcasted_extension =
  | Broadcasted_extension :
      (module Intf.Broadcasted_extension_intf
         with type t = 't
          and type extension = 'ext
          and type view = 'view )
      * 't
      -> ('ext, 'view) broadcasted_extension

let get :
    type ext view. t -> (ext, view) access -> (ext, view) broadcasted_extension
    =
 fun { root_history
     ; snark_pool_refcount
     ; best_tip_diff
     ; transition_registry
     ; ledger_table
     ; new_breadcrumbs
     ; identity
     } -> function
  | Root_history ->
      Broadcasted_extension ((module Root_history.Broadcasted), root_history)
  | Snark_pool_refcount ->
      Broadcasted_extension
        ((module Snark_pool_refcount.Broadcasted), snark_pool_refcount)
  | Best_tip_diff ->
      Broadcasted_extension ((module Best_tip_diff.Broadcasted), best_tip_diff)
  | Transition_registry ->
      Broadcasted_extension
        ((module Transition_registry.Broadcasted), transition_registry)
  | Ledger_table ->
      Broadcasted_extension ((module Ledger_table.Broadcasted), ledger_table)
  | Identity ->
      Broadcasted_extension ((module Identity.Broadcasted), identity)
  | New_breadcrumbs ->
      Broadcasted_extension
        ((module New_breadcrumbs.Broadcasted), new_breadcrumbs)

let get_extension : type ext view. t -> (ext, view) access -> ext =
 fun t access ->
  let (Broadcasted_extension ((module B), ext)) = get t access in
  B.extension ext

let get_view_pipe :
    type ext view. t -> (ext, view) access -> view Broadcast_pipe.Reader.t =
 fun t access ->
  let (Broadcasted_extension ((module B), ext)) = get t access in
  B.reader ext
