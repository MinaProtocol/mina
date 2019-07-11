open Core_kernel
open Coda_base
open Pipe_lib

module State = struct
  type t = Pending | Included | Unknown
end

module type S = sig
  type t

  type transition_frontier

  type transaction_pool

  val create :
       frontier_broadcast_pipe:transition_frontier Option.t
                               Broadcast_pipe.Reader.t
    -> transaction_pool:transaction_pool
    -> t

  val get_status : t -> User_command.t -> State.t
end

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier :
    Coda_intf.Transition_frontier_intf
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

  module Transaction_pool :
    Network_pool.Transaction_pool.S
    with type transition_frontier := Transition_frontier.t
     and type best_tip_diff := Transition_frontier.Diff.Best_tip_diff.view
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs

  let error_if_true bool ~error = if bool then Error error else Ok ()

  let get_status ~transition_frontier_pipe ~transaction_pool cmd =
    let check_cmd = User_command.check cmd |> Option.value_exn in
    let resource_pool = Transaction_pool.resource_pool transaction_pool in
    let indexed_pool = Transaction_pool.Resource_pool.pool resource_pool in
    match Broadcast_pipe.Reader.peek transition_frontier_pipe with
    | None ->
        if Network_pool.Indexed_pool.member indexed_pool check_cmd then
          State.Unknown
        else State.Pending
    | Some transition_frontier -> (
        let resulting_status =
          (* HACK: Leveraging the result monad to expressively compute the
             status of a transaction. If a condition is true, we would like to
             abort the computation early and return the status reprenting the
             condition *)
          let open Result.Let_syntax in
          let best_tip_path =
            Transition_frontier.best_tip_path transition_frontier
          in
          let best_tip_user_commands =
            Sequence.fold (Sequence.of_list best_tip_path)
              ~init:User_command.Set.empty ~f:(fun acc_set breadcrumb ->
                let external_transition =
                  Transition_frontier.Breadcrumb.external_transition breadcrumb
                in
                let user_commands =
                  External_transition.Validated.user_commands
                    external_transition
                in
                List.fold user_commands ~init:acc_set ~f:Set.add )
          in
          let%bind () =
            error_if_true
              (Set.mem best_tip_user_commands cmd)
              ~error:State.Included
          in
          let all_transactions =
            Transition_frontier.all_user_commands transition_frontier
          in
          let%bind () =
            error_if_true (Set.mem all_transactions cmd) ~error:State.Pending
          in
          error_if_true
            (Network_pool.Indexed_pool.member indexed_pool check_cmd)
            ~error:State.Pending
        in
        match resulting_status with
        | Error result ->
            result
        | Ok () ->
            State.Unknown )
end

module Inputs = struct
  include Transition_frontier.Inputs
  module Transition_frontier = Transition_frontier
  module Transaction_pool = Network_pool.Transaction_pool
end

include Make (Inputs)
