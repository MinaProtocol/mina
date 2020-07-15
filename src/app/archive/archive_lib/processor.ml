module Archive_rpc = Rpc
open Async
open Core
open Caqti_async
open Coda_base
open Coda_state
open Coda_transition
open Pipe_lib
open Signature_lib

module Caqti_type_spec = struct
  type (_, _) t =
    | [] : (unit, unit) t
    | ( :: ) : 'c Caqti_type.t * ('a, 'b) t -> ('c -> 'a, 'c * 'b) t

  let rec to_rep : 'hlist 'tuple. ('hlist, 'tuple) t -> 'tuple Caqti_type.t =
    fun (type hlist tuple) (spec : (hlist, tuple) t) ->
     match spec with
     | [] ->
         (Caqti_type.unit : tuple Caqti_type.t)
     | rep :: spec ->
         Caqti_type.tup2 rep (to_rep spec)

  let rec hlist_to_tuple :
            'hlist 'tuple.    ('hlist, 'tuple) t -> (unit, 'hlist) H_list.t
            -> 'tuple =
    fun (type hlist tuple) (spec : (hlist, tuple) t)
        (l : (unit, hlist) H_list.t) ->
     match (spec, l) with
     | [], [] ->
         (() : tuple)
     | _ :: spec, x :: l ->
         ((x, hlist_to_tuple spec l) : tuple)

  let rec tuple_to_hlist :
            'hlist 'tuple.    ('hlist, 'tuple) t -> 'tuple
            -> (unit, 'hlist) H_list.t =
    fun (type hlist tuple) (spec : (hlist, tuple) t) (t : tuple) ->
     match (spec, t) with
     | [], () ->
         ([] : (unit, hlist) H_list.t)
     | _ :: spec, (x, t) ->
         x :: tuple_to_hlist spec t
end

let rec deferred_result_list_fold ls ~init ~f =
  let open Deferred.Result.Let_syntax in
  match ls with
  | [] ->
      return init
  | h :: t ->
      let%bind init = f init h in
      deferred_result_list_fold t ~init ~f

module Public_key = struct
  let add_if_doesn't_exist (module Conn : CONNECTION)
      (t : Public_key.Compressed.t) =
    let open Deferred.Result.Let_syntax in
    let public_key = Public_key.Compressed.to_base58_check t in
    match%bind
      Conn.find_opt
        (Caqti_request.find_opt Caqti_type.string Caqti_type.int
           "SELECT id FROM public_keys WHERE value = ?")
        public_key
    with
    | Some id ->
        return id
    | None ->
        Conn.find
          (Caqti_request.find Caqti_type.string Caqti_type.int
             "INSERT INTO public_keys (value) VALUES (?) RETURNING id")
          public_key
end

module Snarked_ledger_hash = struct
  let add_if_doesn't_exist (module Conn : CONNECTION)
      (t : Frozen_ledger_hash.t) =
    let open Deferred.Result.Let_syntax in
    let hash = Frozen_ledger_hash.to_string t in
    match%bind
      Conn.find_opt
        (Caqti_request.find_opt Caqti_type.string Caqti_type.int
           "SELECT id FROM snarked_ledger_hashes WHERE value = ?")
        hash
    with
    | Some id ->
        return id
    | None ->
        Conn.find
          (Caqti_request.find Caqti_type.string Caqti_type.int
             "INSERT INTO snarked_ledger_hashes (value) VALUES (?) RETURNING id")
          hash
end

module User_command = struct
  type t =
    { typ: string
    ; fee_payer_id: int
    ; source_id: int
    ; receiver_id: int
    ; fee_token: string
    ; token: string
    ; nonce: int
    ; amount: int option
    ; fee: int
    ; memo: string
    ; hash: string }

  let to_hlist
      { typ
      ; fee_payer_id
      ; source_id
      ; receiver_id
      ; fee_token
      ; token
      ; nonce
      ; amount
      ; fee
      ; memo
      ; hash } =
    H_list.
      [ typ
      ; fee_payer_id
      ; source_id
      ; receiver_id
      ; fee_token
      ; token
      ; nonce
      ; amount
      ; fee
      ; memo
      ; hash ]

  let of_hlist
      ([ typ
       ; fee_payer_id
       ; source_id
       ; receiver_id
       ; fee_token
       ; token
       ; nonce
       ; amount
       ; fee
       ; memo
       ; hash ] :
        (unit, _) H_list.t) =
    { typ
    ; fee_payer_id
    ; source_id
    ; receiver_id
    ; fee_token
    ; token
    ; nonce
    ; amount
    ; fee
    ; memo
    ; hash }

  let typ =
    let open Caqti_type_spec in
    let spec =
      Caqti_type.
        [ string
        ; int
        ; int
        ; int
        ; string
        ; string
        ; int
        ; option int
        ; int
        ; string
        ; string ]
    in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let find (module Conn : CONNECTION) ~(transaction_hash : Transaction_hash.t)
      =
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.string Caqti_type.int
         "SELECT id FROM user_commands WHERE hash = ?")
      (Transaction_hash.to_base58_check transaction_hash)

  let add_if_doesn't_exist (module Conn : CONNECTION) (t : User_command.t) =
    let open Deferred.Result.Let_syntax in
    let transaction_hash = Transaction_hash.hash_user_command t in
    match%bind find (module Conn) ~transaction_hash with
    | Some user_command_id ->
        return user_command_id
    | None ->
        let%bind fee_payer_id =
          Public_key.add_if_doesn't_exist
            (module Conn)
            (User_command.fee_payer_pk t)
        in
        let%bind source_id =
          Public_key.add_if_doesn't_exist
            (module Conn)
            (User_command.source_pk t)
        in
        let%bind receiver_id =
          Public_key.add_if_doesn't_exist
            (module Conn)
            (User_command.receiver_pk t)
        in
        Conn.find
          (Caqti_request.find typ Caqti_type.int
             "INSERT INTO user_commands (type, fee_payer_id, source_id, \
              receiver_id, fee_token, token, nonce, amount, fee, memo, hash) \
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id")
          { typ= User_command.tag_string t
          ; fee_payer_id
          ; source_id
          ; receiver_id
          ; fee_token= User_command.fee_token t |> Token_id.to_string
          ; token= User_command.token t |> Token_id.to_string
          ; nonce= User_command.nonce t |> Unsigned.UInt32.to_int
          ; amount=
              User_command.amount t
              |> Core.Option.map ~f:Currency.Amount.to_int
          ; fee= User_command.fee t |> Currency.Fee.to_int
          ; memo= User_command.memo t |> User_command_memo.to_string
          ; hash= transaction_hash |> Transaction_hash.to_base58_check }
end

module Internal_command = struct
  let find (module Conn : CONNECTION) ~(transaction_hash : Transaction_hash.t)
      =
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.string Caqti_type.int
         "SELECT id FROM internal_commands WHERE hash = ?")
      (Transaction_hash.to_base58_check transaction_hash)
end

module Fee_transfer = struct
  type t = {receiver_id: int; fee: int; token: string; hash: string}

  let typ =
    let encode t =
      Ok (("fee_transfer", t.receiver_id, t.fee, t.token), t.hash)
    in
    let decode ((_, receiver_id, fee, token), hash) =
      Ok {receiver_id; fee; token; hash}
    in
    let rep = Caqti_type.(tup2 (tup4 string int int string) string) in
    Caqti_type.custom ~encode ~decode rep

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (t : Fee_transfer.Single.t) =
    let open Deferred.Result.Let_syntax in
    let transaction_hash = Transaction_hash.hash_fee_transfer t in
    match%bind Internal_command.find (module Conn) ~transaction_hash with
    | Some internal_command_id ->
        return internal_command_id
    | None ->
        let%bind receiver_id =
          Public_key.add_if_doesn't_exist
            (module Conn)
            (Fee_transfer.Single.receiver_pk t)
        in
        Conn.find
          (Caqti_request.find typ Caqti_type.int
             "INSERT INTO internal_commands (type, receiver_id, fee, token, \
              hash) VALUES (?, ?, ?, ?, ?) RETURNING id")
          { receiver_id
          ; fee= Fee_transfer.Single.fee t |> Currency.Fee.to_int
          ; token= Token_id.to_string t.fee_token
          ; hash= transaction_hash |> Transaction_hash.to_base58_check }
end

module Coinbase = struct
  type t = {receiver_id: int; amount: int; hash: string}

  let typ =
    let encode t =
      Ok
        ( ("coinbase", t.receiver_id, t.amount, Token_id.(to_string default))
        , t.hash )
    in
    let decode ((_, receiver_id, amount, _), hash) =
      Ok {receiver_id; amount; hash}
    in
    let rep = Caqti_type.(tup2 (tup4 string int int string) string) in
    Caqti_type.custom ~encode ~decode rep

  let add_if_doesn't_exist (module Conn : CONNECTION) (t : Coinbase.t) =
    let open Deferred.Result.Let_syntax in
    let transaction_hash = Transaction_hash.hash_coinbase t in
    match%bind Internal_command.find (module Conn) ~transaction_hash with
    | Some internal_command_id ->
        return internal_command_id
    | None ->
        let%bind receiver_id =
          Public_key.add_if_doesn't_exist
            (module Conn)
            (Coinbase.receiver_pk t)
        in
        Conn.find
          (Caqti_request.find typ Caqti_type.int
             "INSERT INTO internal_commands (type, receiver_id, fee, token, \
              hash) VALUES (?, ?, ?, ?, ?) RETURNING id")
          { receiver_id
          ; amount= Coinbase.amount t |> Currency.Amount.to_int
          ; hash= transaction_hash |> Transaction_hash.to_base58_check }
end

module Block_and_Internal_command = struct
  let add (module Conn : CONNECTION) ~block_id ~internal_command_id =
    Conn.exec
      (Caqti_request.exec
         Caqti_type.(tup2 int int)
         "INSERT INTO blocks_internal_commands (block_id, \
          internal_command_id) VALUES (?, ?)")
      (block_id, internal_command_id)
end

module Block_and_User_command = struct
  let add (module Conn : CONNECTION) ~block_id ~user_command_id =
    Conn.exec
      (Caqti_request.exec
         Caqti_type.(tup2 int int)
         "INSERT INTO blocks_user_commands (block_id, user_command_id) VALUES \
          (?, ?)")
      (block_id, user_command_id)
end

module Block = struct
  type t =
    { state_hash: string
    ; parent_id: int option
    ; creator_id: int
    ; snarked_ledger_hash_id: int
    ; ledger_hash: string
    ; height: int
    ; timestamp: int64
    ; coinbase_id: int option }

  let to_hlist
      { state_hash
      ; parent_id
      ; creator_id
      ; snarked_ledger_hash_id
      ; ledger_hash
      ; height
      ; timestamp
      ; coinbase_id } =
    H_list.
      [ state_hash
      ; parent_id
      ; creator_id
      ; snarked_ledger_hash_id
      ; ledger_hash
      ; height
      ; timestamp
      ; coinbase_id ]

  let of_hlist
      ([ state_hash
       ; parent_id
       ; creator_id
       ; snarked_ledger_hash_id
       ; ledger_hash
       ; height
       ; timestamp
       ; coinbase_id ] :
        (unit, _) H_list.t) =
    { state_hash
    ; parent_id
    ; creator_id
    ; snarked_ledger_hash_id
    ; ledger_hash
    ; height
    ; timestamp
    ; coinbase_id }

  let typ =
    let open Caqti_type_spec in
    let spec =
      Caqti_type.[string; option int; int; int; string; int; int64; option int]
    in
    let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
    let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
    Caqti_type.custom ~encode ~decode (to_rep spec)

  let find (module Conn : CONNECTION) ~(state_hash : State_hash.t) =
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.string Caqti_type.int
         "SELECT id FROM blocks WHERE state_hash = ?")
      (State_hash.to_string state_hash)

  let load (module Conn : CONNECTION) ~(id : int) =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         "SELECT state_hash, parent_id, creator_id, snarked_ledger_hash_id, \
          ledger_hash, height, timestamp, coinbase_id FROM blocks WHERE id = ?")
      id

  let add_if_doesn't_exist (module Conn : CONNECTION) ~constraint_constants
      ({data= t; hash} : (External_transition.t, State_hash.t) With_hash.t) =
    let open Deferred.Result.Let_syntax in
    match%bind find (module Conn) ~state_hash:hash with
    | Some block_id ->
        return block_id
    | None ->
        let%bind parent_id =
          find (module Conn) ~state_hash:(External_transition.parent_hash t)
        in
        let%bind creator_id =
          Public_key.add_if_doesn't_exist
            (module Conn)
            (External_transition.block_producer t)
        in
        let%bind snarked_ledger_hash_id =
          Snarked_ledger_hash.add_if_doesn't_exist
            (module Conn)
            ( External_transition.blockchain_state t
            |> Blockchain_state.snarked_ledger_hash )
        in
        let%bind block_id =
          Conn.find
            (Caqti_request.find typ Caqti_type.int
               "INSERT INTO blocks (state_hash, parent_id, creator_id, \
                snarked_ledger_hash_id, ledger_hash, height, timestamp, \
                coinbase_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING id")
            { state_hash= hash |> State_hash.to_string
            ; parent_id
            ; creator_id
            ; snarked_ledger_hash_id
            ; ledger_hash=
                External_transition.blockchain_state t
                |> Blockchain_state.staged_ledger_hash
                |> Staged_ledger_hash.ledger_hash |> Ledger_hash.to_string
            ; height=
                External_transition.blockchain_length t
                |> Unsigned.UInt32.to_int
            ; timestamp= External_transition.timestamp t |> Block_time.to_int64
            ; coinbase_id= None }
        in
        let transactions =
          External_transition.transactions ~constraint_constants t
        in
        let user_commands, fee_transfers, coinbases =
          Core.List.fold transactions ~init:([], [], [])
            ~f:(fun (acc_user_commands, acc_fee_transfers, acc_coinbases) ->
            function
            | Coda_base.Transaction.User_command user_command_checked ->
                let user_command =
                  Coda_base.User_command.forget_check user_command_checked
                in
                ( user_command :: acc_user_commands
                , acc_fee_transfers
                , acc_coinbases )
            | Fee_transfer fee_transfer_bundled ->
                let fee_transfers =
                  Coda_base.Fee_transfer.to_list fee_transfer_bundled
                in
                ( acc_user_commands
                , fee_transfers @ acc_fee_transfers
                , acc_coinbases )
            | Coinbase coinbase -> (
              match Coda_base.Coinbase.fee_transfer coinbase with
              | None ->
                  ( acc_user_commands
                  , acc_fee_transfers
                  , coinbase :: acc_coinbases )
              | Some {receiver_pk; fee} ->
                  ( acc_user_commands
                  , Coda_base.Fee_transfer.Single.create ~receiver_pk ~fee
                      ~fee_token:Token_id.default
                    :: acc_fee_transfers
                  , coinbase :: acc_coinbases ) ) )
        in
        let%bind user_command_ids =
          deferred_result_list_fold user_commands ~init:[]
            ~f:(fun acc user_command ->
              let%map id =
                User_command.add_if_doesn't_exist (module Conn) user_command
              in
              id :: acc )
        in
        let%bind () =
          deferred_result_list_fold user_command_ids ~init:()
            ~f:(fun () user_command_id ->
              Block_and_User_command.add
                (module Conn)
                ~block_id ~user_command_id
              >>| ignore )
        in
        (* For technique reasons, there might be multiple fee transfers for
           one receiver. As suggested by deepthi, I combine all the fee transfer
           that goes to one public key here *)
        let fee_transfer_table = Core.Hashtbl.create (module Account_id) in
        let () =
          let open Coda_base in
          Core.List.iter fee_transfers ~f:(fun fee_transfer ->
              let receiver = Fee_transfer.Single.receiver fee_transfer in
              Base.Hashtbl.update fee_transfer_table receiver ~f:(function
                | None ->
                    fee_transfer
                | Some acc ->
                    Fee_transfer.Single.create
                      ~receiver_pk:fee_transfer.receiver_pk
                      ~fee_token:fee_transfer.fee_token
                      ~fee:
                        ( Currency.Fee.add
                            (Fee_transfer.Single.fee acc)
                            (Fee_transfer.Single.fee fee_transfer)
                        |> Core.Option.value_exn ) ) )
        in
        let combined_fee_transfers = Core.Hashtbl.data fee_transfer_table in
        let%bind fee_transfer_ids =
          deferred_result_list_fold combined_fee_transfers ~init:[]
            ~f:(fun acc fee_transfer ->
              let%map id =
                Fee_transfer.add_if_doesn't_exist (module Conn) fee_transfer
              in
              id :: acc )
        in
        let%bind () =
          deferred_result_list_fold fee_transfer_ids ~init:()
            ~f:(fun () fee_transfer_id ->
              Block_and_Internal_command.add
                (module Conn)
                ~block_id ~internal_command_id:fee_transfer_id
              >>| ignore )
        in
        (* For technical reasons, each block might have up to 2 coinbases.
           I would combine the coinbases if there are 2 of them.
        *)
        let%bind () =
          if List.length coinbases = 0 then return ()
          else
            let%bind combined_coinbase =
              match coinbases with
              | [coinbase] ->
                  return coinbase
              | [coinbase1; coinbase2] ->
                  let open Coda_base in
                  Coinbase.create
                    ~amount:
                      ( Currency.Amount.add
                          (Coinbase.amount coinbase1)
                          (Coinbase.amount coinbase2)
                      |> Core.Option.value_exn )
                    ~receiver:(Coinbase.receiver_pk coinbase1)
                    ~fee_transfer:None
                  |> Core.Result.map_error ~f:(fun _ ->
                         failwith "Coinbase_combination_failed" )
                  |> Deferred.return
              | _ ->
                  failwith "There_can't_be_more_than_2_coinbases"
            in
            let%bind coinbase_id =
              Coinbase.add_if_doesn't_exist (module Conn) combined_coinbase
            in
            let%bind () =
              Block_and_Internal_command.add
                (module Conn)
                ~block_id ~internal_command_id:coinbase_id
            in
            Conn.exec
              (Caqti_request.exec
                 Caqti_type.(tup2 int int)
                 "UPDATE blocks SET coinbase_id = ? WHERE id = ?")
              (coinbase_id, block_id)
        in
        return block_id

  let delete_if_older_than ?height ?num_blocks ?timestamp
      (module Conn : CONNECTION) =
    let open Deferred.Result.Let_syntax in
    let%bind height =
      match (height, num_blocks) with
      | Some height, _ ->
          return height
      | None, Some num_blocks -> (
          match%map
            Conn.find_opt
              (Caqti_request.find_opt Caqti_type.unit Caqti_type.int
                 "SELECT MAX(height) FROM blocks")
              ()
          with
          | Some max_block_height ->
              max_block_height - num_blocks
          | _ ->
              0 )
      | None, None ->
          return 0
    in
    let timestamp = Option.value ~default:Int64.zero timestamp in
    let%bind () =
      (* Delete user commands *)
      Conn.exec
        (Caqti_request.exec
           Caqti_type.(tup2 int int64)
           "DELETE FROM user_commands USING blocks_user_commands, blocks \
            WHERE blocks.id = blocks_user_commands.block_id AND \
            user_commands.id = blocks_user_commands.user_command_id AND \
            (blocks.height < ? OR blocks.timestamp < ?)")
        (height, timestamp)
    in
    let%bind () =
      (* Delete internal commands *)
      Conn.exec
        (Caqti_request.exec
           Caqti_type.(tup2 int int64)
           "DELETE FROM internal_commands USING blocks_internal_commands, \
            blocks WHERE blocks.id = blocks_internal_commands.block_id AND \
            internal_commands.id = \
            blocks_internal_commands.internal_command_id AND (blocks.height < \
            ? OR blocks.timestamp < ?)")
        (height, timestamp)
    in
    let%bind () =
      (* Delete block user command relationship *)
      Conn.exec
        (Caqti_request.exec
           Caqti_type.(tup2 int int64)
           "DELETE FROM blocks_user_commands USING blocks WHERE blocks.id = \
            blocks_user_commands.block_id AND (blocks.height < ? OR \
            blocks.timestamp < ?)")
        (height, timestamp)
    in
    let%bind () =
      (* Delete block internal command relationship *)
      Conn.exec
        (Caqti_request.exec
           Caqti_type.(tup2 int int64)
           "DELETE FROM blocks_internal_commands USING blocks WHERE blocks.id \
            = blocks_internal_commands.block_id AND (blocks.height < ? OR \
            blocks.timestamp < ?)")
        (height, timestamp)
    in
    let%bind () =
      (* Remove block references. *)
      Conn.exec
        (Caqti_request.exec
           Caqti_type.(tup2 int int64)
           "UPDATE blocks AS b SET parent_id = NULL FROM blocks WHERE \
            b.parent_id = blocks.id AND (blocks.height < ? OR \
            blocks.timestamp < ?)")
        (height, timestamp)
    in
    (* Delete blocks *)
    Conn.exec
      (Caqti_request.exec
         Caqti_type.(tup2 int int64)
         "DELETE FROM blocks WHERE blocks.height < ? OR blocks.timestamp < ?")
      (height, timestamp)
end

let run (module Conn : CONNECTION) reader ~constraint_constants ~logger
    ~delete_older_than =
  Strict_pipe.Reader.iter reader ~f:(function
    | Diff.Transition_frontier (Breadcrumb_added {block; _}) -> (
        match%bind
          let open Deferred.Result.Let_syntax in
          let%bind () = Conn.start () in
          let%bind _ =
            Block.add_if_doesn't_exist ~constraint_constants
              (module Conn)
              block
          in
          match delete_older_than with
          | Some num_blocks ->
              Block.delete_if_older_than ~num_blocks (module Conn)
          | None ->
              return ()
        with
        | Error e ->
            Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
              ~metadata:
                [ ("block", With_hash.hash block |> State_hash.to_yojson)
                ; ("error", `String (Caqti_error.show e)) ]
              "Failed to archive block: $block, see $error" ;
            Conn.rollback () >>| ignore
        | Ok _ ->
            Conn.commit () >>| ignore )
    | Transition_frontier _ ->
        Deferred.return ()
    | Transaction_pool {added; removed= _} ->
        Deferred.List.iter added ~f:(fun user_command ->
            User_command.add_if_doesn't_exist (module Conn) user_command
            >>| ignore ) )

let setup_server ~constraint_constants ~logger ~postgres_address ~server_port
    ~delete_older_than =
  let where_to_listen =
    Async.Tcp.Where_to_listen.bind_to All_addresses (On_port server_port)
  in
  let reader, writer = Strict_pipe.create ~name:"archive" Synchronous in
  let implementations =
    [ Async.Rpc.Rpc.implement Archive_rpc.t (fun () archive_diff ->
          Strict_pipe.Writer.write writer archive_diff ) ]
  in
  match%bind Caqti_async.connect postgres_address with
  | Error e ->
      Logger.error logger ~module_:__MODULE__ ~location:__LOC__
        "Failed to connect to postgresql database, see error: $error"
        ~metadata:[("error", `String (Caqti_error.show e))] ;
      Deferred.unit
  | Ok conn ->
      run ~constraint_constants conn reader ~logger ~delete_older_than
      |> don't_wait_for ;
      Deferred.ignore
      @@ Tcp.Server.create
           ~on_handler_error:
             (`Call
               (fun _net exn ->
                 Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                   "Exception while handling TCP server request: $error"
                   ~metadata:
                     [ ("error", `String (Core.Exn.to_string_mach exn))
                     ; ("context", `String "rpc_tcp_server") ] ))
           where_to_listen
           (fun address reader writer ->
             let address = Socket.Address.Inet.addr address in
             Async.Rpc.Connection.server_with_close reader writer
               ~implementations:
                 (Async.Rpc.Implementations.create_exn ~implementations
                    ~on_unknown_rpc:`Raise)
               ~connection_state:(fun _ -> ())
               ~on_handshake_error:
                 (`Call
                   (fun exn ->
                     Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                       "Exception while handling RPC server request from \
                        $address: $error"
                       ~metadata:
                         [ ("error", `String (Core.Exn.to_string_mach exn))
                         ; ("context", `String "rpc_server")
                         ; ( "address"
                           , `String (Unix.Inet_addr.to_string address) ) ] ;
                     Deferred.unit )) )
      |> don't_wait_for ;
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__
        "Archive process ready. Clients can now connect" ;
      Async.never ()

module For_test = struct
  let assert_parent_exist ~parent_id ~parent_hash conn =
    let open Deferred.Result.Let_syntax in
    match parent_id with
    | Some id ->
        let%map Block.{state_hash= actual; _} = Block.load conn ~id in
        [%test_result: string]
          ~expect:(parent_hash |> State_hash.to_base58_check)
          actual
    | None ->
        failwith "Failed to find parent block in database"
end
