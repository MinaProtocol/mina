open Async
open Caqti_async
open Coda_base
open Coda_state
open Coda_transition
open Signature_lib

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

module Transaction = struct
  let add (module Conn : CONNECTION) (t : Transaction_hash.t) =
    let hash = Transaction_hash.to_base58_check t in
    Conn.find
      (Caqti_request.find Caqti_type.string Caqti_type.int
         "INSERT INTO transactions (hash) VALUES (?) RETURNING id")
      hash

  let find (module Conn : CONNECTION) ~(transaction_hash : Transaction_hash.t)
      =
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.string Caqti_type.int
         "SELECT id FROM transactions WHERE hash = ?")
      (Transaction_hash.to_base58_check transaction_hash)

  let update_user_command_id (module Conn : CONNECTION) ~(transaction_id : int)
      ~(user_command_id : int) =
    Conn.exec
      (Caqti_request.exec
         Caqti_type.(tup2 int int)
         "UPDATE transactions SET user_command_id = ? WHERE id = ?")
      (user_command_id, transaction_id)

  let update_internal_command_id (module Conn : CONNECTION)
      ~(transaction_id : int) ~(internal_command_id : int) =
    Conn.exec
      (Caqti_request.exec
         Caqti_type.(tup2 int int)
         "UPDATE transactions SET internal_command_id = ? WHERE id = ?")
      (internal_command_id, transaction_id)
end

module User_command = struct
  type t =
    { typ: string
    ; sender_id: int
    ; receiver_id: int
    ; nonce: int
    ; amount: int option
    ; fee: int
    ; memo: string
    ; transaction_id: int }

  let typ =
    let encode t =
      Ok
        ( t.typ
        , ( t.sender_id
          , ( t.receiver_id
            , (t.nonce, (t.amount, (t.fee, (t.memo, (t.transaction_id, ())))))
            ) ) )
    in
    let decode
        ( typ
        , ( sender_id
          , ( receiver_id
            , (nonce, (amount, (fee, (memo, (transaction_id, ()))))) ) ) ) =
      Ok {typ; sender_id; receiver_id; nonce; amount; fee; memo; transaction_id}
    in
    let rep =
      Caqti_type.(
        tup2 string
          (tup2 int
             (tup2 int
                (tup2 int
                   (tup2 (option int) (tup2 int (tup2 string (tup2 int unit))))))))
    in
    Caqti_type.custom ~encode ~decode rep

  let add_if_doesn't_exist (module Conn : CONNECTION) (t : User_command.t) =
    let open Deferred.Result.Let_syntax in
    let transaction_hash = Transaction_hash.hash_user_command t in
    match%bind Transaction.find (module Conn) ~transaction_hash with
    | Some transaction_id ->
        return transaction_id
    | None ->
        let%bind transaction_id =
          Transaction.add (module Conn) transaction_hash
        in
        let%bind sender_id =
          Public_key.add_if_doesn't_exist (module Conn) (User_command.sender t)
        in
        let%bind receiver_id =
          Public_key.add_if_doesn't_exist
            (module Conn)
            (User_command.receiver t)
        in
        let%bind user_command_id =
          Conn.find
            (Caqti_request.find typ Caqti_type.int
               "INSERT INTO user_commands (type, sender_id, receiver_id, \
                nonce, amount, fee, memo, transaction_id) VALUES (?, ?, ?, ?, \
                ?, ?, ?, ?) RETURNING id")
            { typ=
                (if User_command.is_payment t then "payment" else "delegation")
            ; sender_id
            ; receiver_id
            ; nonce= User_command.nonce t |> Unsigned.UInt32.to_int
            ; amount=
                User_command.amount t
                |> Core.Option.map ~f:Currency.Amount.to_int
            ; fee= User_command.fee t |> Currency.Fee.to_int
            ; memo= User_command.memo t |> User_command_memo.to_string
            ; transaction_id }
        in
        let%bind () =
          Transaction.update_user_command_id
            (module Conn)
            ~transaction_id ~user_command_id
        in
        return transaction_id
end

module Fee_transfer = struct
  type t = {receiver_id: int; fee: int; transaction_id: int}

  let typ =
    let encode t =
      Ok ("fee_transfer", t.receiver_id, t.fee, t.transaction_id)
    in
    let decode (_, receiver_id, fee, transaction_id) =
      Ok {receiver_id; fee; transaction_id}
    in
    let rep = Caqti_type.(tup4 string int int int) in
    Caqti_type.custom ~encode ~decode rep

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (t : Fee_transfer.Single.t) =
    let open Deferred.Result.Let_syntax in
    let transaction_hash = Transaction_hash.hash_fee_transfer t in
    match%bind Transaction.find (module Conn) ~transaction_hash with
    | Some transaction_id ->
        return transaction_id
    | None ->
        let%bind transaction_id =
          Transaction.add (module Conn) transaction_hash
        in
        let%bind receiver_id =
          Public_key.add_if_doesn't_exist
            (module Conn)
            (Fee_transfer.Single.receiver t)
        in
        let%bind internal_command_id =
          Conn.find
            (Caqti_request.find typ Caqti_type.int
               "INSERT INTO internal_commands (type, receiver_id, fee, \
                transaction_id) VALUES (?, ?, ?, ?) RETURNING id")
            { receiver_id
            ; fee= Fee_transfer.Single.fee t |> Currency.Fee.to_int
            ; transaction_id }
        in
        let%bind () =
          Transaction.update_internal_command_id
            (module Conn)
            ~transaction_id ~internal_command_id
        in
        return transaction_id
end

module Coinbase = struct
  type t = {receiver_id: int; amount: int; transaction_id: int}

  let typ =
    let encode t =
      Ok ("coinbase", t.receiver_id, t.amount, t.transaction_id)
    in
    let decode (_, receiver_id, amount, transaction_id) =
      Ok {receiver_id; amount; transaction_id}
    in
    let rep = Caqti_type.(tup4 string int int int) in
    Caqti_type.custom ~encode ~decode rep

  let add_if_doesn't_exist (module Conn : CONNECTION) (t : Coinbase.t) =
    let open Deferred.Result.Let_syntax in
    let transaction_hash = Transaction_hash.hash_coinbase t in
    match%bind Transaction.find (module Conn) ~transaction_hash with
    | Some transaction_id ->
        return transaction_id
    | None ->
        let%bind transaction_id =
          Transaction.add (module Conn) transaction_hash
        in
        let%bind receiver_id =
          Public_key.add_if_doesn't_exist (module Conn) (Coinbase.proposer t)
        in
        let%bind internal_command_id =
          Conn.find
            (Caqti_request.find typ Caqti_type.int
               "INSERT INTO internal_commands (type, receiver_id, fee, \
                transaction_id) VALUES (?, ?, ?, ?) RETURNING id")
            { receiver_id
            ; amount= Coinbase.amount t |> Currency.Amount.to_int
            ; transaction_id }
        in
        let%bind () =
          Transaction.update_internal_command_id
            (module Conn)
            ~transaction_id ~internal_command_id
        in
        return transaction_id
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

  let typ =
    let encode t =
      Ok
        ( t.state_hash
        , ( t.parent_id
          , ( t.creator_id
            , ( t.snarked_ledger_hash_id
              , (t.ledger_hash, (t.height, (t.timestamp, (t.coinbase_id, ()))))
              ) ) ) )
    in
    let decode
        ( state_hash
        , ( parent_id
          , ( creator_id
            , ( snarked_ledger_hash_id
              , (ledger_hash, (height, (timestamp, (coinbase_id, ())))) ) ) )
        ) =
      Ok
        { state_hash
        ; parent_id
        ; creator_id
        ; snarked_ledger_hash_id
        ; ledger_hash
        ; height
        ; timestamp
        ; coinbase_id }
    in
    let rep =
      Caqti_type.(
        tup2 string
          (tup2 (option int)
             (tup2 int
                (tup2 int
                   (tup2 string
                      (tup2 int (tup2 int64 (tup2 (option int) unit))))))))
    in
    Caqti_type.custom ~encode ~decode rep

  let find (module Conn : CONNECTION) ~(state_hash : State_hash.t) =
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.string Caqti_type.int
         "SELECT id FROM blocks WHERE state_hash = ?")
      (State_hash.to_string state_hash)

  let add_if_doesn't_exist (module Conn : CONNECTION)
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
            (External_transition.proposer t)
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
        let transactions = External_transition.transactions t in
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
                let fee_transfers = One_or_two.to_list fee_transfer_bundled in
                ( acc_user_commands
                , fee_transfers @ acc_fee_transfers
                , acc_coinbases )
            | Coinbase coinbase -> (
              match Coda_base.Coinbase.fee_transfer coinbase with
              | None ->
                  ( acc_user_commands
                  , acc_fee_transfers
                  , coinbase :: acc_coinbases )
              | Some fee_transfer ->
                  ( acc_user_commands
                  , fee_transfer :: acc_fee_transfers
                  , coinbase :: acc_coinbases ) ) )
        in
        let%bind user_command_ids =
          Deferred.Result.all
            (Core.List.map user_commands
               ~f:(User_command.add_if_doesn't_exist (module Conn)))
        in
        let%bind fee_transfer_ids =
          Deferred.Result.all
            (Core.List.map fee_transfers
               ~f:(Fee_transfer.add_if_doesn't_exist (module Conn)))
        in
        return block_id
end
