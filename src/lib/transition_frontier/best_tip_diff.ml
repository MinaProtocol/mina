(** A transition frontier extension that exposes the changes in the best tip. *)

open Core
open Protocols.Coda_transition_frontier

module Make (Breadcrumb : sig
  type t
end) :
  Transition_frontier_extension_intf0
  with type transition_frontier_breadcrumb := Breadcrumb.t
   and type input = unit
   and type view = Breadcrumb.t Best_tip_diff_view.t Option.t = struct
  type t = unit

  type input = unit

  type view = Breadcrumb.t Best_tip_diff_view.t Option.t

  let create () = ()

  let initial_view = None

  (* View is only None when there haven't been any diffs yet. This is sort of an
     unfortunate hack. *)
  let handle_diff () diff : Breadcrumb.t Best_tip_diff_view.t Option.t Option.t
      =
    Some
      (let open Transition_frontier_diff in
      match diff with
      | New_breadcrumb _ -> None (* We only care about the best tip *)
      | New_best_tip {new_best_tip; old_best_tip; _} ->
          Some {new_best_tip; old_best_tip})
end
