open Core
open Async
open Pipe_lib
open Coda_transition
open Coda_state
open Coda_base
open Signature_lib

module Make (Config : Graphql_lib.Client.Config_intf) = struct
  type t = {hasura_endpoint: Uri.t}

  module Client = Graphql_lib.Client.Make (Config)

  let added_transactions {hasura_endpoint; _} added =
    let open Deferred.Result.Let_syntax in
    let user_commands_with_times = Map.to_alist added in
    let user_commands_with_hashes_and_times =
      List.map user_commands_with_times ~f:(fun (user_command, times) ->
          ( With_hash.of_data user_command
              ~hash_data:Transaction_hash.hash_user_command
          , times ) )
    in
    let user_command_hashes =
      List.map user_commands_with_hashes_and_times
        ~f:(fun ({With_hash.hash; _}, _) -> hash)
    in
    let%bind queried_existing_user_commands =
      let graphql =
        Graphql_query.User_commands.Query_first_seen.make
          ~hashes:
            ( List.map user_command_hashes ~f:Transaction_hash.to_base58_check
            |> Array.of_list )
          ()
      in
      let%map obj = Client.query graphql hasura_endpoint in
      let list =
        Array.map obj#user_commands ~f:(fun obj -> (obj#hash, obj#first_seen))
        |> Array.to_list
      in
      Transaction_hash.Map.of_alist_exn list
    in
    let user_commands =
      List.map user_commands_with_hashes_and_times
        ~f:(fun ((With_hash.{data= _; hash} as user_command_with_hash), time)
           ->
          let current_first_time_opt =
            Option.join (Map.find queried_existing_user_commands hash)
          in
          Types.User_command.encode user_command_with_hash
          @@ Some
               (Option.value_map ~default:time current_first_time_opt
                  ~f:(fun current_time -> Block_time.min current_time time)) )
    in
    let graphql =
      Graphql_query.User_commands.Insert.make
        ~user_commands:(Array.of_list user_commands)
        ()
    in
    let%map _result = Client.query graphql hasura_endpoint in
    ()

  let compute_with_receipt_chains
      (user_commands :
        ((User_command.t, Transaction_hash.t) With_hash.t * Block_time.t option)
        list)
      (sender_receipt_chains_from_parent_ledger :
        Receipt.Chain_hash.t Public_key.Compressed.Map.t) :
      ( (User_command.t, Transaction_hash.t) With_hash.t
      * Block_time.t option
      * Types.Receipt_chain_hash.t option )
      list =
    (* The user commands should be sorted by nonces *)
    let sorted_user_commands =
      List.sort user_commands
        ~compare:
          (Comparable.lift Account.Nonce.compare
             ~f:(fun ({With_hash.data= user_command; _}, _) ->
               User_command.nonce user_command ))
    in
    List.folding_map sorted_user_commands
      ~init:sender_receipt_chains_from_parent_ledger
      ~f:(fun acc_sender_receipt_chains
         ( ({With_hash.data= user_command; _} as user_command_with_hash)
         , block_time )
         ->
        let user_command_payload = User_command.payload user_command in
        let sender = User_command.sender user_command in
        let udpated_sender_receipt_chain, new_receipt_chain =
          Option.value_map ~default:(acc_sender_receipt_chains, None)
            (Map.find acc_sender_receipt_chains sender)
            ~f:(fun previous_receipt_chain ->
              let new_receipt_chain =
                Receipt.Chain_hash.cons user_command_payload
                  previous_receipt_chain
              in
              let updated_receipt_chain_hash =
                Map.set acc_sender_receipt_chains ~key:sender
                  ~data:new_receipt_chain
              in
              let receipt_chain_input =
                Types.
                  { Receipt_chain_hash.value= new_receipt_chain
                  ; parent= previous_receipt_chain }
              in
              (updated_receipt_chain_hash, Some receipt_chain_input) )
        in
        ( udpated_sender_receipt_chain
        , (user_command_with_hash, block_time, new_receipt_chain) ) )

  type 'a graphql_result =
    < parse: Yojson.Basic.json -> 'a
    ; query: string
    ; variables: Yojson.Basic.json >

  let tag_with_first_seen
      ~(get_first_seen : string array -> 'output graphql_result)
      ~(get_obj :
            'output
         -> < hash: Transaction_hash.t ; first_seen: Block_time.t option ; .. >
            array) transactions_with_hash default_block_time hasura_endpoint =
    let open Deferred.Result.Let_syntax in
    let hashes =
      List.map transactions_with_hash
        ~f:(Fn.compose Transaction_hash.to_base58_check With_hash.hash)
    in
    let graphql = get_first_seen (Array.of_list hashes) in
    let%map first_query_response =
      let%map result = Client.query graphql hasura_endpoint in
      Array.to_list (get_obj result)
      |> List.map ~f:(fun obj -> (obj#hash, obj#first_seen))
    in
    let map = Transaction_hash.Map.of_alist_exn first_query_response in
    List.map transactions_with_hash
      ~f:(fun ({With_hash.hash; _} as user_command_with_hash) ->
        let first_seen_in_db = Option.join @@ Map.find map hash in
        ( user_command_with_hash
        , Option.value_map first_seen_in_db ~default:(Some default_block_time)
            ~f:Option.some ) )

  let update_block_confirmations t (parent_state_hash : State_hash.t) =
    let open Deferred.Result.Let_syntax in
    let%bind corrected_block_confirmations =
      let graphql =
        Graphql_query.Blocks.Get_stale_block_confirmations.make
          ~parent_hash:(State_hash.to_base58_check parent_state_hash)
          ()
      in
      let%map state_block_confirmations =
        Client.query graphql t.hasura_endpoint
        >>| fun response -> response#get_stale_block_confirmations
      in
      Array.to_list state_block_confirmations
      |> List.map ~f:(fun stale_block ->
             ((stale_block#state_hash)#value, stale_block#status + 1) )
    in
    let results =
      (* TODO: This code writes Hasura functions in a sequential manner. Hasura
         currently cannot express atomic batch row updates. We would need to
         write a SQL query in order to do this. *)
      List.map corrected_block_confirmations
        ~f:(fun (hash, new_block_confirmation) ->
          let hash = State_hash.to_base58_check hash in
          let graphql =
            Graphql_query.Blocks.Update_block_confirmations.make ~hash
              ~status:new_block_confirmation ()
          in
          Client.query graphql t.hasura_endpoint )
    in
    Deferred.Result.all results |> Deferred.Result.ignore

  let update_new_block t encoded_block =
    let graphql =
      Graphql_query.Blocks.Insert.make
        ~blocks:(Array.of_list [encoded_block])
        ()
    in
    Client.query graphql t.hasura_endpoint |> Deferred.Result.ignore

  let added_transition t
      ({With_hash.data= block; hash= _} as block_with_hash :
        (External_transition.t, State_hash.t) With_hash.t)
      (sender_receipt_chains_from_parent_ledger :
        Receipt.Chain_hash.t Public_key.Compressed.Map.t) =
    let open Deferred.Result.Let_syntax in
    let transactions =
      List.bind (External_transition.transactions block) ~f:(function
        | User_command checked_user_command ->
            [`User_command (User_command.forget_check checked_user_command)]
        | Fee_transfer fee_transfer ->
            One_or_two.map ~f:(fun ft -> `Fee_transfer ft) fee_transfer
            |> One_or_two.to_list
        | Coinbase _ ->
            [] )
    in
    let user_commands, fee_transfers =
      List.fold transactions ~init:([], [])
        ~f:(fun (acc_user_commands, acc_fee_transfers) -> function
        | `User_command user_command ->
            ( With_hash.of_data user_command
                ~hash_data:Transaction_hash.hash_user_command
              :: acc_user_commands
            , acc_fee_transfers )
        | `Fee_transfer fee_transfer ->
            ( acc_user_commands
            , With_hash.of_data fee_transfer
                ~hash_data:Transaction_hash.hash_fee_transfer
              :: acc_fee_transfers ) )
    in
    let block_time =
      Blockchain_state.timestamp @@ External_transition.blockchain_state block
    in
    let%bind user_commands_with_time =
      tag_with_first_seen
        ~get_first_seen:(fun hashes ->
          Graphql_query.User_commands.Query_first_seen.make ~hashes () )
        ~get_obj:(fun result -> result#user_commands)
        user_commands block_time t.hasura_endpoint
    in
    let%bind fee_transfers_with_time =
      tag_with_first_seen
        ~get_first_seen:(fun hashes ->
          Graphql_query.Fee_transfers.Query_first_seen.make ~hashes () )
        ~get_obj:(fun result -> result#fee_transfers)
        fee_transfers block_time t.hasura_endpoint
    in
    let encoded_block =
      Types.Blocks.serialize block_with_hash
        (compute_with_receipt_chains user_commands_with_time
           sender_receipt_chains_from_parent_ledger)
        fee_transfers_with_time
    in
    let%bind () =
      update_block_confirmations t (External_transition.parent_hash block)
    in
    update_new_block t encoded_block

  let create hasura_endpoint = {hasura_endpoint}

  let run t reader =
    Strict_pipe.Reader.iter reader ~f:(function
      | Diff.Transition_frontier
          (Breadcrumb_added {block; sender_receipt_chains_from_parent_ledger})
        -> (
          match%bind
            added_transition t block
              (Public_key.Compressed.Map.of_alist_exn
                 sender_receipt_chains_from_parent_ledger)
          with
          | Error e ->
              Graphql_lib.Client.Connection_error.ok_exn e
          | Ok () ->
              Deferred.return () )
      | Diff.Transition_frontier _ ->
          (* TODO: Implement *)
          Deferred.return ()
      | Transaction_pool {added; removed= _} -> (
          match%bind
            added_transactions t @@ User_command.Map.of_alist_exn added
          with
          | Ok result ->
              Deferred.return result
          | Error e ->
              Graphql_lib.Client.Connection_error.ok_exn e ) )
end
