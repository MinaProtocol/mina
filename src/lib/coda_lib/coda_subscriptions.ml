open Core_kernel
open Async_kernel
open Pipe_lib
open Coda_base
open Signature_lib
open Auxiliary_database

type 'a reader_and_writer = 'a Pipe.Reader.t * 'a Pipe.Writer.t

type t =
  { subscribed_payment_users:
      User_command.t reader_and_writer Public_key.Compressed.Table.t
  ; subscribed_block_users:
      (Filtered_external_transition.t, State_hash.t) With_hash.t
      reader_and_writer
      Public_key.Compressed.Table.t
  ; mutable reorganization_subscription: [`Changed] reader_and_writer list }

let create ~logger ~wallets ~time_controller ~external_transition_database
    ~new_blocks ~transition_frontier ~is_storing_all =
  let subscribed_block_users =
    Public_key.Compressed.Table.of_alist_exn
    @@ List.map (Secrets.Wallets.pks wallets) ~f:(fun wallet ->
           let reader, writer = Pipe.create () in
           (wallet, (reader, writer)) )
  in
  let subscribed_payment_users =
    Public_key.Compressed.Table.of_alist_exn
    @@ List.map (Secrets.Wallets.pks wallets) ~f:(fun wallet ->
           let reader, writer = Pipe.create () in
           (wallet, (reader, writer)) )
  in
  Strict_pipe.Reader.iter new_blocks ~f:(fun new_block ->
      let hash =
        new_block |> Coda_transition.External_transition.Validated.state_hash
      in
      let filtered_external_transition_result =
        if is_storing_all then
          Filtered_external_transition.of_transition `All new_block
        else
          Filtered_external_transition.of_transition
            (`Some
              ( Public_key.Compressed.Set.of_list
              @@ Hashtbl.keys subscribed_block_users ))
            new_block
      in
      match filtered_external_transition_result with
      | Ok filtered_external_transition ->
          let block_time = Block_time.now time_controller in
          let filtered_external_transition_with_hash =
            {With_hash.data= filtered_external_transition; hash}
          in
          let participants =
            Filtered_external_transition.participants
              filtered_external_transition
          in
          Set.iter participants ~f:(fun participant ->
              (* Send block to subscribed partipants *)
              Hashtbl.find_and_call subscribed_block_users participant
                ~if_found:(fun (_, writer) ->
                  Pipe.write_without_pushback writer
                    filtered_external_transition_with_hash )
                ~if_not_found:ignore ;
              (* Send payments to subscribed partipants *)
              Hashtbl.find_and_call subscribed_payment_users participant
                ~if_found:(fun (_, writer) ->
                  let user_commands =
                    User_command.filter_by_participant
                      (Filtered_external_transition.user_commands
                         filtered_external_transition)
                      participant
                  in
                  List.iter user_commands ~f:(fun user_command ->
                      Pipe.write_without_pushback writer user_command ) )
                ~if_not_found:ignore ) ;
          External_transition_database.add external_transition_database
            filtered_external_transition_with_hash block_time ;
          Deferred.unit
      | Error e ->
          Logger.error logger
            "Staged ledger had error with transactions in block for state \
             $state_hash: $error"
            ~module_:__MODULE__ ~location:__LOC__
            ~metadata:
              [ ( "error"
                , `String (Staged_ledger.Pre_diff_info.Error.to_string e) )
              ; ("state_hash", State_hash.to_yojson hash) ] ;
          Deferred.unit )
  |> don't_wait_for ;
  let reorganization_subscription = [] in
  let reader, writer =
    Strict_pipe.create ~name:"Reorganization subscription"
      Strict_pipe.(Buffered (`Capacity 1, `Overflow Drop_head))
  in
  let t =
    { subscribed_payment_users
    ; subscribed_block_users
    ; reorganization_subscription }
  in
  don't_wait_for
  @@ Broadcast_pipe.Reader.iter transition_frontier
       ~f:
         (Option.value_map ~default:Deferred.unit
            ~f:(fun transition_frontier ->
              let best_tip_diff_pipe =
                Transition_frontier.best_tip_diff_pipe transition_frontier
              in
              Broadcast_pipe.Reader.iter best_tip_diff_pipe
                ~f:(fun {reorg_best_tip; _} ->
                  if reorg_best_tip then Strict_pipe.Writer.write writer () ;
                  Deferred.unit ) )) ;
  Strict_pipe.Reader.iter reader ~f:(fun () ->
      List.iter t.reorganization_subscription ~f:(fun (_, writer) ->
          Pipe.write_without_pushback writer `Changed ) ;
      Deferred.unit )
  |> don't_wait_for ;
  t

(* When you subscribe to a block, you will also subscribe to it's payments *)
let add_block_subscriber t public_key =
  let block_reader, block_writer = Pipe.create () in
  Hashtbl.set t.subscribed_block_users ~key:public_key
    ~data:(block_reader, block_writer) ;
  block_reader

let add_payment_subscriber t public_key =
  let payment_reader, payment_writer = Pipe.create () in
  Hashtbl.set t.subscribed_payment_users ~key:public_key
    ~data:(payment_reader, payment_writer) ;
  payment_reader

let add_reorganization_subscriber t =
  let reader, writer = Pipe.create () in
  t.reorganization_subscription
  <- (reader, writer) :: t.reorganization_subscription ;
  reader
