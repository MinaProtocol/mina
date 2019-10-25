open Core
open Async
open Coda_base
open Signature_lib
module Diff0 = Diff

let try_with ~f port =
  Deferred.Or_error.ok_exn
  @@ let%bind result = Monitor.try_with_or_error ~name:"Write Processor" f in
     let%map clear_action =
       Graphql_client.query (Graphql_query.Clear_data.make ()) port
     in
     Or_error.all_unit
       [ result
       ; Result.map_error clear_action ~f:(fun error ->
             Error.createf !"Issue clearing data in database: %{sexp:Error.t}"
             @@ Graphql_client_lib.Connection_error.to_error error )
         |> Result.ignore ]

let port = 9000

let create_added_breadcrumb_diff (type t breadcrumb)
    (module Transition_frontier : Coda_intf.Transition_frontier_intf
      with type t = t
       and type Breadcrumb.t = breadcrumb) ~(root : breadcrumb) breadcrumbs =
  List.folding_map breadcrumbs ~init:root
    ~f:(fun previous_breadcrumb breadcrumb ->
      let sender_receipt_chains_from_parent_ledger =
        let user_commands =
          User_command.Set.of_list
            (Transition_frontier.Breadcrumb.user_commands breadcrumb)
        in
        let senders =
          Public_key.Compressed.Set.map user_commands ~f:User_command.sender
        in
        let ledger =
          Staged_ledger.ledger
          @@ Transition_frontier.Breadcrumb.staged_ledger previous_breadcrumb
        in
        Set.to_map senders ~f:(fun sender ->
            Option.value_exn
              (let open Option.Let_syntax in
              let%bind ledger_location =
                Ledger.location_of_key ledger sender
              in
              let%map {receipt_chain_hash; _} =
                Ledger.get ledger ledger_location
              in
              receipt_chain_hash) )
      in
      let block =
        fst @@ Transition_frontier.Breadcrumb.validated_transition breadcrumb
      in
      let diff =
        Diff0.(
          Transition_frontier
            (Breadcrumb_added {block; sender_receipt_chains_from_parent_ledger}))
      in
      (breadcrumb, diff) )
