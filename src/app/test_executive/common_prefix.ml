open Core_kernel
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine

  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config =
    let open Test_config in
    { default with
      block_producers=
        [ {balance= "1000"; timing= Untimed}
        ; {balance= "1000"; timing= Untimed}
        ; {balance= "1000"; timing= Untimed}
        ; {balance= "1000"; timing= Untimed}
        ; {balance= "1000"; timing= Untimed} ] }

  let take xall n =
    match xall with
    | [] ->
        []
    | x :: xs ->
        if n = zero then [] else x :: take xs (n - 1)

  let check_common_prefixes prefixes =
    let recent_chains =
      List.map prefixes ~f:(take prefixes 5 |> Hash_set.of_list (module String))
    in
    let common_prefixes =
      List.fold_left Hash_set.inter (List.hd recent_chains)
        (List.tl recent_chains)
    in
    if Hash_set.length = 0 then
      Malleable_error.of_string_hard_error
        "Chains don't have common prefixes among their most recent 5 blocks"
    else Malleable_error.return ()

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let block_producers = Network.block_producers network in
    let%bind () =
      Malleable_error.List.iter block_producers ~f:(fun bp ->
          wait_for t @@ Wait_condition.node_to_initialize bp )
    in
    let%bind.Async.Deferred.Let_syntax () =
      Async.after (Time.Span.of_min runtime_min)
    in
    let%bind prefixes =
      Malleable_error.List.map block_producers ~f:(fun bp ->
          Node.get_best_tip_path ~logger bp )
    in
    check_common_prefixes prefixes
end
