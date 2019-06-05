open Core_kernel
open Async_kernel
open Pipe_lib
open Coda_base
open Signature_lib

module Make (Inputs : Intf.Inputs) = struct
  open Inputs

  type t =
    { subscribed_payment_users:
        (User_command.t Pipe.Reader.t * User_command.t Pipe.Writer.t)
        Public_key.Compressed.Table.t
    ; subscribed_block_users:
        ( (Filtered_external_transition.t, State_hash.t) With_hash.t
          Pipe.Reader.t
        * (Filtered_external_transition.t, State_hash.t) With_hash.t
          Pipe.Writer.t )
        Public_key.Compressed.Table.t }

  let create ~logger ~wallets ~time_controller ~external_transition_database
      ~new_blocks =
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
    Strict_pipe.Reader.iter new_blocks
      ~f:(fun ({With_hash.data= _; hash} as new_block_with_hash) ->
        match
          Filtered_external_transition.of_transition
            ~tracked_participants:
              ( Public_key.Compressed.Set.of_list
              @@ Hashtbl.keys subscribed_block_users )
            new_block_with_hash
        with
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
              "Could not process transactions in valid external_transition "
              ~module_:__MODULE__ ~location:__LOC__
              ~metadata:
                [ ( "error"
                  , `String (Staged_ledger.Pre_diff_info.Error.to_string e) )
                ] ;
            Deferred.unit )
    |> don't_wait_for ;
    {subscribed_payment_users; subscribed_block_users}

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
end
