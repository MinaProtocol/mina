open Core
open Async
open Pipe_lib
open Coda_base
open Signature_lib

type t = {uri: Uri.t}

let receiver user_command =
  Public_key.Compressed.to_base58_check
  @@
  match (User_command.payload user_command).body with
  | Payment payment ->
      payment.receiver
  | Stake_delegation (Set_delegate delegation) ->
      delegation.new_delegate

module type Data_intf = sig
  type t [@@deriving compare]

  include Comparable.S with type t := t
end

module type Graphql_obj_intf = sig
  type t

  type hash

  val id : t -> int

  val hash : t -> hash
end

module type Inputs_intf = sig
  module Hash : Data_intf

  module Data : sig
    type t
  end

  module Graphql_query_result : Graphql_obj_intf with type hash := Hash.t

  val get_existing :
    t -> Hash.t array -> Graphql_query_result.t array Deferred.Or_error.t

  val update :
       t
    -> Data.t Hash.Map.t
    -> Graphql_query_result.t Hash.Map.t
    -> unit Deferred.Or_error.t

  val insert :
       t
    -> Data.t Hash.Map.t
    -> Graphql_query_result.t array option Deferred.Or_error.t
end

module Make_upsert (Inputs : Inputs_intf) = struct
  open Inputs

  let upsert t (hash_to_data_map : Data.t Hash.Map.t) =
    let open Deferred.Result.Let_syntax in
    let hash_set = Hash.Set.of_map_keys hash_to_data_map in
    let%bind existing_graphql_objects_map =
      let%map graphql_objs = get_existing t (Set.to_array hash_set) in
      Array.map graphql_objs ~f:(fun obj -> (Graphql_query_result.hash obj, obj)
      )
      |> Array.to_list |> Hash.Map.of_alist_exn
    in
    let%bind () = update t hash_to_data_map existing_graphql_objects_map in
    let%map inserted_items =
      let existing_hashes = Set.of_map_keys existing_graphql_objects_map in
      let data_to_insert =
        Map.filter_keys hash_to_data_map
          ~f:(Fn.compose not (Set.mem existing_hashes))
      in
      let%map response_opt = insert t data_to_insert in
      Option.map response_opt ~f:(fun response ->
          Hash.Map.of_alist_exn
            ( Array.map response ~f:(fun obj ->
                  (Graphql_query_result.hash obj, obj) )
            |> Array.to_list ) )
    in
    match inserted_items with
    | Some new_public_keys_to_ids ->
        Map.merge existing_graphql_objects_map new_public_keys_to_ids
          ~f:(fun ~key:_ -> function
          | `Both _ ->
              failwith "impossible"
          | `Left x ->
              Some x
          | `Right x ->
              Some x )
    | None ->
        existing_graphql_objects_map
end

module Public_key_upsert = Make_upsert (struct
  module Hash = Public_key.Compressed
  module Data = Public_key.Compressed

  module Graphql_query_result = struct
    type t = < id: int ; value: Public_key.Compressed.t >

    let id obj = obj#id

    let hash obj = obj#value
  end

  let get_existing {uri; _} public_keys =
    let open Deferred.Result.Let_syntax in
    let%map result =
      Graphql_client_lib.query_or_error
        (Graphql_commands.Public_keys.Get_existing.make
           ~public_keys:
             (Array.map public_keys ~f:Public_key.Compressed.to_base58_check)
           ())
        uri
    in
    result#public_keys

  let update _ _ _ = Deferred.Result.return ()

  let insert {uri} hash_to_data_map =
    let open Deferred.Result.Let_syntax in
    let%map result =
      Graphql_client_lib.query_or_error
        (Graphql_commands.Public_keys.Insert.make
           ~public_keys:
             ( Public_key.Compressed.Map.keys hash_to_data_map
             |> Array.of_list
             |> Array.map ~f:Types.Public_key.encode )
           ())
        uri
    in
    let open Option.Let_syntax in
    let%map result = result#insert_public_keys in
    result#returning
end)

let upsert_public_keys t public_keys =
  let public_keys_map = Set.to_map public_keys ~f:Fn.id in
  Public_key_upsert.upsert t public_keys_map

module User_commands_upsert = Make_upsert (struct
  module Hash = Transaction_hash

  module Data = struct
    type t = User_command.t * Block_time.t
  end

  module Graphql_query_result = struct
    type t =
      < first_seen: Block_time.t sexp_option
      ; hash: Transaction_hash.t
      ; id: int >

    let id obj = obj#id

    let hash obj = obj#hash
  end

  let get_existing {uri} transaction_hashes =
    let open Deferred.Result.Let_syntax in
    let%map existing =
      Graphql_client_lib.query_or_error
        (Graphql_commands.User_commands.Get_existing.make
           ~hashes:
             (Array.map transaction_hashes ~f:Transaction_hash.to_base58_check)
           ())
        uri
    in
    existing#user_commands

  let update {uri} (user_commands_map : Data.t Hash.Map.t)
      (existing_graphql_results : Graphql_query_result.t Hash.Map.t) =
    let user_commands_to_update =
      Hash.Map.filter_mapi user_commands_map
        ~f:(fun ~key:hash ~data:(_, first_time_seen) ->
          let open Option.Let_syntax in
          let%bind graphql_result = Map.find existing_graphql_results hash in
          match graphql_result#first_seen with
          | None ->
              Some (graphql_result#id, first_time_seen)
          | Some stored_time ->
              Option.some_if
                Block_time.(first_time_seen <= stored_time)
                (graphql_result#id, first_time_seen) )
    in
    Map.data user_commands_to_update
    |> List.map ~f:(fun (current_id, new_first_seen) ->
           let open Deferred.Result.Let_syntax in
           let graphql =
             Graphql_commands.User_commands.Update.make ~current_id
               ~new_first_seen:
                 ( Types.Bitstring.to_yojson
                 @@ Types.Block_time.serialize new_first_seen )
               ()
           in
           let%bind result = Graphql_client_lib.query_or_error graphql uri in
           let%bind affected_rows =
             Result.of_option result#update_user_commands
               ~error:
                 (Error.of_string
                    "Expected to get non null error from updating user_command")
             |> Deferred.return
           in
           Result.ok_if_true
             (affected_rows#affected_rows = 1)
             ~error:(Error.of_string "Expected to update only one row")
           |> Deferred.return )
    |> Deferred.Result.all_unit

  let insert t (user_commands_to_be_added : Data.t Hash.Map.t) =
    let open Deferred.Result.Let_syntax in
    let participants =
      Map.fold user_commands_to_be_added ~init:Public_key.Compressed.Set.empty
        ~f:(fun ~key:_ ~data:(user_command, _) acc_participants ->
          let extra_participants =
            User_command.accounts_accessed user_command
          in
          Set.union acc_participants
            (Public_key.Compressed.Set.of_list extra_participants) )
    in
    let%bind public_keys_to_ids = upsert_public_keys t participants in
    let new_user_commands =
      Map.to_alist user_commands_to_be_added
      |> List.map ~f:(fun (hash, (user_command, first_time_seen)) ->
             let sender = User_command.sender user_command in
             let receiver =
               match user_command.payload.body with
               | Payment payment ->
                   payment.receiver
               | Stake_delegation (Set_delegate {new_delegate}) ->
                   new_delegate
             in
             Types.User_command.encode
               ~sender:(Map.find_exn public_keys_to_ids sender)#id
               ~receiver:(Map.find_exn public_keys_to_ids receiver)#id
               {With_hash.hash; data= user_command}
               first_time_seen )
      |> Array.of_list
    in
    let graphql =
      Graphql_commands.User_commands.Insert.make
        ~user_commands:new_user_commands ()
    in
    let%map result = Graphql_client_lib.query_or_error graphql t.uri in
    Option.map result#insert_user_commands ~f:(fun result -> result#returning)
end)

let run t reader =
  Strict_pipe.Reader.iter reader ~f:(function
    | Diff.Transition_frontier _ ->
        (* TODO: Implement *)
        Deferred.return ()
    | Transaction_pool {added; removed= _} ->
        let map =
          Map.to_alist added
          |> List.map ~f:(fun (user_command, time) ->
                 ( Transaction_hash.hash_user_command user_command
                 , (user_command, time) ) )
          |> Transaction_hash.Map.of_alist_exn
        in
        Deferred.Or_error.ok_exn (User_commands_upsert.upsert t map)
        |> Deferred.ignore )
