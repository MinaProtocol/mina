open Async
open Caqti_async
open Coda_base
open Signature_lib

module Public_key = struct
  let add (module Conn : CONNECTION) (t : Public_key.Compressed.t) =
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

module Transaction = struct
  let add (module Conn : CONNECTION) (t : Transaction_hash.t) =
    let hash = Transaction_hash.to_base58_check t in
    Conn.find
      (Caqti_request.find Caqti_type.string Caqti_type.int
         "INSERT INTO transactions (hash) VALUES (?) RETURNING id")
      hash

  let find_user_command (module Conn : CONNECTION) (t : Transaction_hash.t) =
    let hash = Transaction_hash.to_base58_check t in
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.string Caqti_type.int
         "SELECT user_command_id FROM transactions WHERE hash = ?")
      hash

  let find_internal_command (module Conn : CONNECTION) (t : Transaction_hash.t)
      =
    let hash = Transaction_hash.to_base58_check t in
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.string Caqti_type.int
         "SELECT internal_command_id FROM transactions WHERE hash = ?")
      hash

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

  let add (module Conn : CONNECTION) (t : User_command.t) =
    let open Deferred.Result.Let_syntax in
    let hash = Transaction_hash.hash_user_command t in
    match%bind Transaction.find_user_command (module Conn) hash with
    | Some user_command_id ->
        return user_command_id
    | None ->
        let%bind transaction_id = Transaction.add (module Conn) hash in
        let%bind sender_id =
          Public_key.add (module Conn) (User_command.sender t)
        in
        let%bind receiver_id =
          Public_key.add (module Conn) (User_command.receiver t)
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
        return user_command_id
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

  let add (module Conn : CONNECTION) (t : Fee_transfer.Single.t) =
    let open Deferred.Result.Let_syntax in
    let hash = Transaction_hash.hash_fee_transfer t in
    match%bind Transaction.find_internal_command (module Conn) hash with
    | Some internal_command_id ->
        return internal_command_id
    | None ->
        let%bind transaction_id = Transaction.add (module Conn) hash in
        let%bind receiver_id =
          Public_key.add (module Conn) (Fee_transfer.Single.receiver t)
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
        return internal_command_id
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

  let add (module Conn : CONNECTION) (t : Coinbase.t) =
    let open Deferred.Result.Let_syntax in
    let hash = Transaction_hash.hash_coinbase t in
    match%bind Transaction.find_internal_command (module Conn) hash with
    | Some internal_command_id ->
        return internal_command_id
    | None ->
        let%bind transaction_id = Transaction.add (module Conn) hash in
        let%bind receiver_id =
          Public_key.add (module Conn) (Coinbase.proposer t)
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
        return internal_command_id
end

(*
let add_block (module Conn : CONNECTION)
    ({data= block; hash} : (External_transition.t, State_hash.t) With_hash.t) =
  let open Deferred.Result.Let_syntax in
  let transactions = External_transition.transactions block in
  let%bind () = Conn.start () in
  let%bind ids =
    Deferred.Result.all
      (Core.List.map transactions ~f:(function
        | User_command user_command_checked ->
            let user_command =
              User_command.forget_check user_command_checked
            in
            let hash =
              Transaction_hash.hash_user_command user_command
              |> Transaction_hash.to_base58_check
            in
            let%bind transaction_id =
              Conn.find
                (Caqti_request.find Caqti_type.string Caqti_type.int
                   "INSERT INTO transactions (hash) VALUES (?) RETURNING id")
                hash
            in
            (*
            let%bind _user_command_id =
                Conn.find
                  (Caqti_request.find Caqti_type.)
            *)
            failwith "..."
        | Fee_transfer fee_transfer ->
            failwith "..."
        | Coinbase coinbase ->
            failwith "..." ))
  in
  Conn.commit ()

let run t reader =
  Strict_pipe.Reader.iter reader ~f:(function
    | Diff.Transition_frontier (Breadcrumb_added {block; _}) ->
        failwith "..."
    | Transition_frontier _ ->
        failwith "..."
    | Transaction_pool {added; _} ->
        failwith "..." )
*)
