(* test_common.ml -- code common to tests *)

open Integration_test_lib
open Core_kernel
open Async
open Mina_transaction

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs

  (* Call [f] [n] times in sequence *)
  let repeat_seq ~n ~f =
    let open Malleable_error.Let_syntax in
    let rec go n =
      if n = 0 then return ()
      else
        let%bind () = f () in
        go (n - 1)
    in
    go n

  let send_payments ~logger ~sender_pub_key ~receiver_pub_key ~amount ~fee ~node
      n =
    let open Malleable_error.Let_syntax in
    let rec go n hashlist =
      if n = 0 then return hashlist
      else
        let%bind hash =
          let%map { hash; nonce; _ } =
            Integration_test_lib.Graphql_requests.must_send_online_payment
              ~logger ~sender_pub_key ~receiver_pub_key ~amount ~fee
              (Engine.Network.Node.get_ingress_uri node)
          in
          [%log info]
            "sending multiple payments: payment #%d sent with hash of %s and \
             nonce of %d."
            n
            (Transaction_hash.to_base58_check hash)
            (Unsigned.UInt32.to_int nonce) ;
          hash
        in
        go (n - 1) (List.append hashlist [ hash ])
    in
    go n []

  let wait_for_payments ~logger ~dsl ~hashlist n =
    let open Malleable_error.Let_syntax in
    let rec go n hashlist =
      if n = 0 then return ()
      else
        (* confirm payment *)
        let%bind () =
          let hash = List.hd_exn hashlist in
          let%map () =
            Dsl.wait_for dsl
              (Dsl.Wait_condition.signed_command_to_be_included_in_frontier
                 ~txn_hash:hash ~node_included_in:`Any_node )
          in
          [%log info]
            "wait for multiple payments: payment #%d with hash %s successfully \
             included in frontier."
            n
            (Transaction_hash.to_base58_check hash) ;
          ()
        in
        go (n - 1) (List.tl_exn hashlist)
    in
    go n hashlist

  (* let pub_key_of_node node =
     let open Signature_lib in
     match Engine.Network.Node.network_keypair node with
     | Some nk ->
         Malleable_error.return (nk.keypair.public_key |> Public_key.compress)
     | None ->
         Malleable_error.hard_error_format
           "Node '%s' did not have a network keypair, if node is a block \
            producer this should not happen"
           (Engine.Network.Node.id node) *)

  let make_get_key ~f node =
    match Engine.Network.Node.network_keypair node with
    | Some nk ->
        Malleable_error.return (f nk)
    | None ->
        Malleable_error.hard_error_format
          "Node '%s' did not have a network keypair, if node is a block \
           producer this should not happen"
          (Engine.Network.Node.id node)

  let pub_key_of_node =
    make_get_key ~f:(fun nk ->
        nk.keypair.public_key |> Signature_lib.Public_key.compress )

  let priv_key_of_node = make_get_key ~f:(fun nk -> nk.keypair.private_key)

  let check_common_prefixes ~tolerance ~logger chains =
    assert (List.length chains > 1) ;
    let hashset_chains =
      List.map chains ~f:(Hash_set.of_list (module String))
    in
    let longest_chain_length =
      chains |> List.map ~f:List.length
      |> List.max_elt ~compare:Int.compare
      |> Option.value_exn
    in
    let common_prefixes =
      List.reduce hashset_chains ~f:Hash_set.inter |> Option.value_exn
    in
    let common_prefixes_length = Hash_set.length common_prefixes in
    let length_difference = longest_chain_length - common_prefixes_length in
    if length_difference = 0 || length_difference <= tolerance then
      Malleable_error.return ()
    else
      let error_str =
        sprintf
          "Chains have common prefix of %d blocks, longest absolute chain is \
           %d blocks.  the difference is %d blocks, which is greater than \
           allowed tolerance of %d blocks"
          common_prefixes_length longest_chain_length length_difference
          tolerance
      in
      [%log error] "%s" error_str ;
      Malleable_error.soft_error ~value:() (Error.of_string error_str)

  module X = struct
    include String

    type display = string [@@deriving yojson]

    let display = Fn.id

    let name = Fn.id
  end

  module G = Visualization.Make_ocamlgraph (X)

  let graph_of_adjacency_list (adj : (string * string list) list) =
    List.fold adj ~init:G.empty ~f:(fun acc (x, xs) ->
        let acc = G.add_vertex acc x in
        List.fold xs ~init:acc ~f:(fun acc y ->
            let acc = G.add_vertex acc y in
            G.add_edge acc x y ) )

  let fetch_connectivity_data ~logger nodes =
    let open Malleable_error.Let_syntax in
    Malleable_error.List.map nodes ~f:(fun node ->
        let%map response =
          Integration_test_lib.Graphql_requests.must_get_peer_id ~logger
            (Engine.Network.Node.get_ingress_uri node)
        in
        (node, response) )

  let assert_peers_completely_connected nodes_and_responses =
    (* this check checks if every single peer in the network is connected to every other peer, in graph theory this network would be a complete graph.  this property will only hold true on small networks *)
    let check_peer_connected_to_all_others ~nodes_by_peer_id ~peer_id
        ~connected_peers =
      let get_node_id p =
        p |> String.Map.find_exn nodes_by_peer_id |> Engine.Network.Node.id
      in
      let expected_peers =
        nodes_by_peer_id |> String.Map.keys
        |> List.filter ~f:(fun p -> not (String.equal p peer_id))
      in
      Malleable_error.List.iter expected_peers ~f:(fun p ->
          let error =
            Printf.sprintf "node %s (id=%s) is not connected to node %s (id=%s)"
              (get_node_id peer_id) peer_id (get_node_id p) p
            |> Error.of_string
          in
          Malleable_error.ok_if_true
            (List.mem connected_peers p ~equal:String.equal)
            ~error_type:`Hard ~error )
    in

    let nodes_by_peer_id =
      nodes_and_responses
      |> List.map ~f:(fun (node, (peer_id, _)) -> (peer_id, node))
      |> String.Map.of_alist_exn
    in
    Malleable_error.List.iter nodes_and_responses
      ~f:(fun (_, (peer_id, connected_peers)) ->
        check_peer_connected_to_all_others ~nodes_by_peer_id ~peer_id
          ~connected_peers )

  let assert_peers_cant_be_partitioned ~max_disconnections nodes_and_responses =
    (* this check checks that the network does NOT become partitioned into isolated subgraphs, even if n nodes are hypothetically removed from the network.*)
    let _, responses = List.unzip nodes_and_responses in
    let open Graph_algorithms in
    let () =
      Out_channel.with_file "/tmp/network-graph.dot" ~f:(fun c ->
          G.output_graph c (graph_of_adjacency_list responses) )
    in
    (* Check that the network cannot be disconnected by removing up to max_disconnections number of nodes. *)
    match
      Nat.take
        (Graph_algorithms.connectivity (module String) responses)
        max_disconnections
    with
    | `Failed_after n ->
        Malleable_error.hard_error_format
          "The network could be disconnected by removing %d node(s)" n
    | `Ok ->
        Malleable_error.return ()

  let send_zkapp_batch ~logger node_uri zkapp_commands =
    List.iter zkapp_commands ~f:(fun zkapp_command ->
        [%log info] "Sending zkApp"
          ~metadata:
            [ ("zkapp_command", Mina_base.Zkapp_command.to_yojson zkapp_command)
            ; ( "memo"
              , `String
                  (Mina_base.Signed_command_memo.to_string_hum
                     zkapp_command.memo ) )
            ] ) ;
    match%bind.Deferred
      Integration_test_lib.Graphql_requests.send_zkapp_batch ~logger node_uri
        ~zkapp_commands
    with
    | Ok _zkapp_ids ->
        [%log info] "ZkApp transactions sent" ;
        Malleable_error.return ()
    | Error err ->
        let err_str = Error.to_string_mach err in
        [%log error] "Error sending zkApp transactions"
          ~metadata:[ ("error", `String err_str) ] ;
        Malleable_error.hard_error_format "Error sending zkApp transactions: %s"
          err_str

  let send_zkapp ~logger node zkapp_command =
    send_zkapp_batch ~logger node [ zkapp_command ]

  let send_invalid_zkapp ~logger node_uri zkapp_command substring =
    [%log info] "Sending zkApp, expected to fail" ;
    match%bind.Deferred
      Integration_test_lib.Graphql_requests.send_zkapp_batch ~logger node_uri
        ~zkapp_commands:[ zkapp_command ]
    with
    | Ok _zkapp_ids ->
        [%log error] "ZkApp transaction succeeded, expected error \"%s\""
          substring ;
        Malleable_error.hard_error_format
          "ZkApp transaction succeeded, expected error \"%s\"" substring
    | Error err ->
        let err_str = Error.to_string_mach err in
        if String.is_substring ~substring err_str then (
          [%log info] "ZkApp transaction failed as expected"
            ~metadata:[ ("error", `String err_str) ] ;
          Malleable_error.return () )
        else (
          [%log error]
            "Error sending zkApp, for a reason other than the expected \"%s\""
            substring
            ~metadata:[ ("error", `String err_str) ] ;
          Malleable_error.hard_error_format
            "ZkApp transaction failed: %s, but expected \"%s\"" err_str
            substring )

  let send_invalid_payment ~logger node_uri ~sender_pub_key ~receiver_pub_key
      ~amount ~fee ~nonce ~memo ~valid_until ~raw_signature ~expected_failure :
      unit Malleable_error.t =
    [%log info] "Sending payment, expected to fail" ;
    let expected_failure = String.lowercase expected_failure in
    match%bind.Deferred
      Integration_test_lib.Graphql_requests.send_payment_with_raw_sig ~logger
        node_uri ~sender_pub_key ~receiver_pub_key ~amount ~fee ~nonce ~memo
        ~valid_until ~raw_signature
    with
    | Ok _ ->
        [%log error] "Payment succeeded, expected error \"%s\"" expected_failure ;
        Malleable_error.hard_error_format
          "Payment transaction succeeded, expected error \"%s\""
          expected_failure
    | Error err ->
        let err_str = Error.to_string_mach err |> String.lowercase in
        if String.is_substring ~substring:expected_failure err_str then (
          [%log info] "Payment failed as expected"
            ~metadata:[ ("error", `String err_str) ] ;
          Malleable_error.return () )
        else (
          [%log error]
            "Error sending payment, for a reason other than the expected \"%s\""
            expected_failure
            ~metadata:[ ("error", `String err_str) ] ;
          Malleable_error.hard_error_format
            "Payment failed: %s, but expected \"%s\"" err_str expected_failure )

  let get_account_permissions ~logger node_uri account_id =
    [%log info] "Getting permissions for account"
      ~metadata:[ ("account_id", Mina_base.Account_id.to_yojson account_id) ] ;
    match%bind.Deferred
      Integration_test_lib.Graphql_requests.get_account_permissions ~logger
        node_uri ~account_id
    with
    | Ok permissions ->
        [%log info] "Got account permissions" ;
        Malleable_error.return permissions
    | Error err ->
        let err_str = Error.to_string_mach err in
        [%log error] "Error getting account permissions"
          ~metadata:[ ("error", `String err_str) ] ;
        Malleable_error.hard_error (Error.of_string err_str)

  let get_account_update ~logger node_uri account_id =
    [%log info] "Getting update for account"
      ~metadata:[ ("account_id", Mina_base.Account_id.to_yojson account_id) ] ;
    match%bind.Deferred
      Integration_test_lib.Graphql_requests.get_account_update ~logger node_uri
        ~account_id
    with
    | Ok update ->
        [%log info] "Got account update" ;
        Malleable_error.return update
    | Error err ->
        let err_str = Error.to_string_mach err in
        [%log error] "Error getting account update"
          ~metadata:[ ("error", `String err_str) ] ;
        Malleable_error.hard_error (Error.of_string err_str)

  let get_pooled_zkapp_commands ~logger node_uri pk =
    [%log info] "Getting pooled zkApp commands"
      ~metadata:
        [ ("pub_key", Signature_lib.Public_key.Compressed.to_yojson pk) ] ;
    match%bind.Deferred
      Integration_test_lib.Graphql_requests.get_pooled_zkapp_commands ~logger
        node_uri ~pk
    with
    | Ok zkapp_commands ->
        [%log info] "Got pooled zkApp commands" ;
        Malleable_error.return zkapp_commands
    | Error err ->
        let err_str = Error.to_string_mach err in
        [%log error] "Error getting pooled zkApp commands"
          ~metadata:[ ("error", `String err_str) ] ;
        Malleable_error.hard_error (Error.of_string err_str)

  let compatible_item req_item ledg_item ~equal =
    match (req_item, ledg_item) with
    | Mina_base.Zkapp_basic.Set_or_keep.Keep, _ ->
        true
    | Set v1, Mina_base.Zkapp_basic.Set_or_keep.Set v2 ->
        equal v1 v2
    | Set _, Keep ->
        false

  let compatible_updates ~(ledger_update : Mina_base.Account_update.Update.t)
      ~(requested_update : Mina_base.Account_update.Update.t) : bool =
    (* the "update" in the ledger is derived from the account

       if the requested update has `Set` for a field, we
       should see `Set` for the same value in the ledger update

       if the requested update has `Keep` for a field, any
       value in the ledger update is acceptable

       for the app state, we apply this principle element-wise
    *)
    let app_states_compat =
      let fs_requested =
        Pickles_types.Vector.Vector_8.to_list requested_update.app_state
      in
      let fs_ledger =
        Pickles_types.Vector.Vector_8.to_list ledger_update.app_state
      in
      List.for_all2_exn fs_requested fs_ledger ~f:(fun req ledg ->
          compatible_item req ledg ~equal:Pickles.Backend.Tick.Field.equal )
    in
    let delegates_compat =
      compatible_item requested_update.delegate ledger_update.delegate
        ~equal:Signature_lib.Public_key.Compressed.equal
    in
    let verification_keys_compat =
      compatible_item requested_update.verification_key
        ledger_update.verification_key
        ~equal:
          [%equal:
            ( Pickles.Side_loaded.Verification_key.t
            , Pickles.Backend.Tick.Field.t )
            With_hash.t]
    in
    let permissions_compat =
      compatible_item requested_update.permissions ledger_update.permissions
        ~equal:Mina_base.Permissions.equal
    in
    let zkapp_uris_compat =
      compatible_item requested_update.zkapp_uri ledger_update.zkapp_uri
        ~equal:String.equal
    in
    let token_symbols_compat =
      compatible_item requested_update.token_symbol ledger_update.token_symbol
        ~equal:String.equal
    in
    let timings_compat =
      compatible_item requested_update.timing ledger_update.timing
        ~equal:Mina_base.Account_update.Update.Timing_info.equal
    in
    let voting_fors_compat =
      compatible_item requested_update.voting_for ledger_update.voting_for
        ~equal:Mina_base.State_hash.equal
    in
    List.for_all
      [ app_states_compat
      ; delegates_compat
      ; verification_keys_compat
      ; permissions_compat
      ; zkapp_uris_compat
      ; token_symbols_compat
      ; timings_compat
      ; voting_fors_compat
      ]
      ~f:Fn.id

  (* [logs] is a string containing the entire replayer output *)
  let check_replayer_logs ~logger logs =
    let log_level_substring level = sprintf {|"level":"%s"|} level in
    let error_log_substring = log_level_substring "Error" in
    let fatal_log_substring = log_level_substring "Fatal" in
    let info_log_substring = log_level_substring "Info" in
    let split_logs = String.split logs ~on:'\n' in
    let error_logs =
      split_logs
      |> List.filter ~f:(fun log ->
             String.is_substring log ~substring:error_log_substring
             || String.is_substring log ~substring:fatal_log_substring )
    in
    let info_logs =
      split_logs
      |> List.filter ~f:(fun log ->
             String.is_substring log ~substring:info_log_substring )
    in
    if Mina_stdlib.List.Length.Compare.(info_logs < 25) then
      Malleable_error.hard_error_string
        (sprintf "Replayer output contains suspiciously few (%d) Info logs"
           (List.length info_logs) )
    else if List.is_empty error_logs then (
      [%log info] "The replayer encountered no errors" ;
      Malleable_error.return () )
    else
      let error = String.concat error_logs ~sep:"\n  " in
      Malleable_error.hard_error_string ("Replayer errors:\n  " ^ error)
end
