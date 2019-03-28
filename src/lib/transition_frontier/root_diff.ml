open Coda_base
open Protocols.Coda_transition_frontier

module Make (Breadcrumb : sig
  type t

  val state_hash : t -> State_hash.t

  val to_user_commands : t -> User_command.t list
end) :
  Transition_frontier_extension_intf0
  with type transition_frontier_breadcrumb := Breadcrumb.t
   and type input = unit
   and type view = User_command.t Root_diff_view.t = struct
  type t = unit

  type input = unit

  type view = User_command.t Root_diff_view.t

  let create () = ()

  let initial_view () = Root_diff_view.{user_commands= []; root_length= None}

  let handle_diff () diff =
    match diff with
    | Transition_frontier_diff.New_breadcrumb _ -> None
    | Transition_frontier_diff.New_frontier root ->
        Some
          Root_diff_view.
            { user_commands= Breadcrumb.to_user_commands root
            ; root_length= Some 0 }
    | Transition_frontier_diff.New_best_tip
        {old_root; new_root; old_root_length; _} ->
        if
          State_hash.equal
            (Breadcrumb.state_hash old_root)
            (Breadcrumb.state_hash new_root)
        then None
        else
          Some
            Root_diff_view.
              { user_commands= Breadcrumb.to_user_commands new_root
              ; root_length= Some (1 + old_root_length) }
end
