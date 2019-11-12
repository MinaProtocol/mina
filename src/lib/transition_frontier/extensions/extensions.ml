open Async_kernel
open Core_kernel
open Pipe_lib
module Best_tip_diff = Best_tip_diff
module Identity = Identity
module Root_history = Root_history
module Snark_pool_refcount = Snark_pool_refcount
module Transition_registry = Transition_registry

type t =
  { root_history: Root_history.Broadcasted.t
  ; snark_pool_refcount: Snark_pool_refcount.Broadcasted.t
  ; best_tip_diff: Best_tip_diff.Broadcasted.t
  ; transition_registry: Transition_registry.Broadcasted.t
  ; identity: Identity.Broadcasted.t }
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
  let%map identity = Identity.(Broadcasted.create (create ~logger frontier)) in
  { root_history
  ; snark_pool_refcount
  ; best_tip_diff
  ; transition_registry
  ; identity }

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
    ~identity:(close_extension (module Identity.Broadcasted))

let notify (t : t) ~frontier ~diffs =
  let update (type t)
      (module B : Intf.Broadcasted_extension_intf with type t = t) field =
    B.update (Field.get field t) frontier diffs
  in
  Deferred.List.all_unit
    (Fields.to_list
       ~root_history:(update (module Root_history.Broadcasted))
       ~snark_pool_refcount:(update (module Snark_pool_refcount.Broadcasted))
       ~best_tip_diff:(update (module Best_tip_diff.Broadcasted))
       ~transition_registry:(update (module Transition_registry.Broadcasted))
       ~identity:(update (module Identity.Broadcasted)))

type ('ext, 'view) access =
  | Root_history : (Root_history.t, Root_history.view) access
  | Snark_pool_refcount
      : (Snark_pool_refcount.t, Snark_pool_refcount.view) access
  | Best_tip_diff : (Best_tip_diff.t, Best_tip_diff.view) access
  | Transition_registry
      : (Transition_registry.t, Transition_registry.view) access
  | Identity : (Identity.t, Identity.view) access

type ('ext, 'view) broadcated_extension =
  | Broadcasted_extension :
      (module Intf.Broadcasted_extension_intf
         with type t = 't
          and type extension = 'ext
          and type view = 'view)
      * 't
      -> ('ext, 'view) broadcated_extension

let get : type ext view.
    t -> (ext, view) access -> (ext, view) broadcated_extension =
 fun { root_history
     ; snark_pool_refcount
     ; best_tip_diff
     ; transition_registry
     ; identity } -> function
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
  | Identity ->
      Broadcasted_extension ((module Identity.Broadcasted), identity)

let get_extension : type ext view. t -> (ext, view) access -> ext =
 fun t access ->
  let (Broadcasted_extension ((module B), ext)) = get t access in
  B.extension ext

let get_view_pipe : type ext view.
    t -> (ext, view) access -> view Broadcast_pipe.Reader.t =
 fun t access ->
  let (Broadcasted_extension ((module B), ext)) = get t access in
  B.reader ext
