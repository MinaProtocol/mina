(** A transition frontier extension that exposes the changes in the transactions
    in the best tip. *)

open Core
open Coda_base
open Protocols.Coda_transition_frontier

module Make (Breadcrumb : sig
  type t

  val to_user_commands : t -> User_command.t list
end) :
  Transition_frontier_extension_intf0
  with type transition_frontier_breadcrumb := Breadcrumb.t
   and type input = unit
   and type view = User_command.t Best_tip_diff_view.t = struct
  type t = unit

  type input = unit

  type view = User_command.t Best_tip_diff_view.t

  let create () = ()

  let initial_view () : view =
    {new_user_commands= []; removed_user_commands= []; best_tip_length= -1}

  let handle_diff () diff : User_command.t Best_tip_diff_view.t Option.t =
    let open Transition_frontier_diff in
    match diff with
    | New_breadcrumb _ -> None (* We only care about the best tip *)
    | New_best_tip
        { added_to_best_tip_path
        ; removed_from_best_tip_path
        ; new_best_tip_length; _ } ->
        Some
          { new_user_commands=
              List.bind
                (Non_empty_list.to_list added_to_best_tip_path)
                ~f:Breadcrumb.to_user_commands
          ; removed_user_commands=
              List.bind removed_from_best_tip_path
                ~f:Breadcrumb.to_user_commands
          ; best_tip_length= new_best_tip_length }
end
