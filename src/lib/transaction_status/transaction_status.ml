open Core_kernel
open Coda_base
open Pipe_lib

module State = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Pending | Included | Unknown
        [@@deriving equal, sexp, compare, bin_io, version]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t = Pending | Included | Unknown
  [@@deriving equal, sexp, compare]

  let to_string = function
    | Pending ->
        "PENDING"
    | Included ->
        "INCLUDED"
    | Unknown ->
        "UNKOWN"
end

module type S = sig
  type transition_frontier

  type transaction_pool

  val get_status :
       frontier_broadcast_pipe:transition_frontier Option.t
                               Broadcast_pipe.Reader.t
    -> transaction_pool:transaction_pool
    -> User_command.t
    -> State.t Or_error.t
end

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier : Coda_intf.Transition_frontier_intf

  module Transaction_pool :
    Network_pool.Transaction_pool.S
    with type transition_frontier := Transition_frontier.t
     and type best_tip_diff := Transition_frontier.Diff.Best_tip_diff.view
end

module Make (Inputs : Inputs_intf) :
  S
  with type transition_frontier := Inputs.Transition_frontier.t
   and type transaction_pool := Inputs.Transaction_pool.t = struct
  open Inputs

  let get_status ~frontier_broadcast_pipe ~transaction_pool cmd =
    let open Or_error.Let_syntax in
    let%map check_cmd =
      Result.of_option (User_command.check cmd)
        ~error:(Error.of_string "Invalid signature")
    in
    let resource_pool = Transaction_pool.resource_pool transaction_pool in
    match Broadcast_pipe.Reader.peek frontier_broadcast_pipe with
    | None ->
        State.Unknown
    | Some transition_frontier ->
        with_return (fun {return} ->
            let best_tip_path =
              Transition_frontier.best_tip_path transition_frontier
            in
            let best_tip_user_commands =
              Sequence.fold (Sequence.of_list best_tip_path)
                ~init:User_command.Set.empty ~f:(fun acc_set breadcrumb ->
                  let user_commands =
                    Transition_frontier.Breadcrumb.user_commands breadcrumb
                  in
                  List.fold user_commands ~init:acc_set ~f:Set.add )
            in
            if Set.mem best_tip_user_commands cmd then return State.Included ;
            let all_transactions =
              Transition_frontier.all_user_commands transition_frontier
            in
            if Set.mem all_transactions cmd then return State.Pending ;
            if Transaction_pool.Resource_pool.member resource_pool check_cmd
            then return State.Pending ;
            State.Unknown )
end

module Inputs = struct
  include Transition_frontier.Inputs
  module Transition_frontier = Transition_frontier
  module Transaction_pool = Network_pool.Transaction_pool
end

include Make (Inputs)
