module Archive_rpc = Rpc
open Async
open Core
open Caqti_async
open Coda_base
open Coda_state
open Coda_transition
open Pipe_lib
open Signature_lib
open Pickles_types

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

let rec vector : type t n.
    n Nat.t -> t Caqti_type.t -> (t, n) Vector.t Caqti_type.t =
 fun n t ->
  match n with
  | Z ->
      Caqti_type.(custom unit)
        ~encode:(fun Vector.[] -> Ok ())
        ~decode:(fun () -> Ok Vector.[])
  | S n ->
      let r = vector n t in
      Caqti_type.(custom (tup2 t r))
        ~encode:(fun Vector.(x :: xs) -> Ok (x, xs))
        ~decode:(fun (x, xs) -> Ok (x :: xs))

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

module Command_transaction = struct
  module Signed_command = struct
    type t =
      { typ: string
      ; fee_payer_id: int
      ; source_id: int
      ; receiver_id: int
      ; fee_token: int
      ; token: int
      ; nonce: int
      ; amount: int option
      ; fee: int
      ; memo: string
      ; hash: string
      ; status: string option
      ; failure_reason: string option }
    [@@deriving hlist]

    let typ =
      let open Caqti_type_spec in
      let spec =
        Caqti_type.
          [ string
          ; int
          ; int
          ; int
          ; int
          ; int
          ; int
          ; option int
          ; int
          ; string
          ; string
          ; option string
          ; option string ]
      in
      let encode t = Ok (hlist_to_tuple spec (to_hlist t)) in
      let decode t = Ok (of_hlist (tuple_to_hlist spec t)) in
      Caqti_type.custom ~encode ~decode (to_rep spec)

    let find (module Conn : CONNECTION)
        ~(transaction_hash : Transaction_hash.t) =
      Conn.find_opt
        (Caqti_request.find_opt Caqti_type.string Caqti_type.int
           "SELECT id FROM user_commands WHERE hash = ?")
        (Transaction_hash.to_base58_check transaction_hash)

    let add_if_doesn't_exist (module Conn : CONNECTION) (t : Signed_command.t) =
      let open Deferred.Result.Let_syntax in
      let transaction_hash = Transaction_hash.hash_command (Signed_command t) in
      match%bind find (module Conn) ~transaction_hash with
      | Some user_command_id ->
          return user_command_id
      | None ->
          let%bind fee_payer_id =
            Public_key.add_if_doesn't_exist
              (module Conn)
              (Signed_command.fee_payer_pk t)
          in
          let%bind source_id =
            Public_key.add_if_doesn't_exist
              (module Conn)
              (Signed_command.source_pk t)
          in
          let%bind receiver_id =
            Public_key.add_if_doesn't_exist
              (module Conn)
              (Signed_command.receiver_pk t)
          in
          (* TODO: Converting these uint64s to int can overflow; see #5419 *)
          Conn.find
            (Caqti_request.find typ Caqti_type.int
               "INSERT INTO user_commands (type, fee_payer_id, source_id, \
                receiver_id, fee_token, token, nonce, amount, fee, memo, \
                hash, status, failure_reason) VALUES (?, ?, ?, ?, ?, ?, ?, ?, \
                ?, ?, ?, ?, ?) RETURNING id")
            { typ= Signed_command.tag_string t
            ; fee_payer_id
            ; source_id
            ; receiver_id
            ; fee_token=
                Signed_command.fee_token t |> Token_id.to_uint64
                |> Unsigned.UInt64.to_int
            ; token=
                Signed_command.token t |> Token_id.to_uint64
                |> Unsigned.UInt64.to_int
            ; nonce= Signed_command.nonce t |> Unsigned.UInt32.to_int
            ; amount=
                Signed_command.amount t
                |> Core.Option.map ~f:Currency.Amount.to_int
            ; fee= Signed_command.fee t |> Currency.Fee.to_int
            ; memo= Signed_command.memo t |> Signed_command_memo.to_string
            ; hash= transaction_hash |> Transaction_hash.to_base58_check
            ; status= None
            ; failure_reason= None }

    let add_with_status (module Conn : CONNECTION) (t : Signed_command.t)
        (status : User_command_status.t) =
      let open Deferred.Result.Let_syntax in
      let%bind user_command_id = add_if_doesn't_exist (module Conn) t in
      let ( status_str
          , failure_reason
          , fee_payer_account_creation_fee_paid
          , receiver_account_creation_fee_paid
          , created_token ) =
        match status with
        | Applied
            { fee_payer_account_creation_fee_paid
            ; receiver_account_creation_fee_paid
            ; created_token } ->
            let amount_to_int64 x =
              Unsigned.UInt64.to_int64 (Currency.Amount.to_uint64 x)
            in
            ( "applied"
            , None
            , Option.map ~f:amount_to_int64 fee_payer_account_creation_fee_paid
            , Option.map ~f:amount_to_int64 receiver_account_creation_fee_paid
            , Option.map created_token ~f:(fun tid ->
                  Unsigned.UInt64.to_int64 (Token_id.to_uint64 tid) ) )
        | Failed failure ->
            ( "failed"
            , Some (User_command_status.Failure.to_string failure)
            , None
            , None
            , None )
      in
      let%map () =
        Conn.exec
          (Caqti_request.exec
             Caqti_type.(
               tup3
                 (tup2 (option string) (option string))
                 (tup3 (option int64) (option int64) (option int64))
                 int)
             "UPDATE user_commands \n\
              SET status = ?, \n\
             \    failure_reason = ?, \n\
             \    fee_payer_account_creation_fee_paid = ?, \n\
             \    receiver_account_creation_fee_paid = ?, \n\
             \    created_token = ? \n\
              WHERE id = ?")
          ( (Some status_str, failure_reason)
          , ( fee_payer_account_creation_fee_paid
            , receiver_account_creation_fee_paid
            , created_token )
          , user_command_id )
      in
      user_command_id
  end

  let as_user_command (t : Command_transaction.t) : Coda_base.Signed_command.t =
    match t with
    | Signed_command c ->
        c
    | Snapp_command c ->
        let module S = Coda_base.Snapp_command in
        let ({source; receiver; amount} : S.transfer) = S.as_transfer c in
        let fee_payer = S.fee_payer c in
        { signature= Signature.dummy
        ; signer= Snark_params.Tick.Field.(zero, zero)
        ; payload=
            { common=
                { fee= S.fee_exn c
                ; fee_token= Account_id.token_id fee_payer
                ; fee_payer_pk= Account_id.public_key fee_payer
                ; nonce=
                    Option.value (S.nonce c)
                      ~default:Coda_numbers.Account_nonce.zero
                ; valid_until= Coda_numbers.Global_slot.max_value
                ; memo= Signed_command_memo.create_from_string_exn "snapp" }
            ; body=
                Payment
                  { source_pk= source
                  ; receiver_pk= receiver
                  ; token_id= S.token_id c
                  ; amount } } }

  let add_if_doesn't_exist conn (t : Command_transaction.t) =
    Signed_command.add_if_doesn't_exist conn (as_user_command t)

  let add_with_status conn (t : Command_transaction.t)
      (status : User_command_status.t) =
    Signed_command.add_with_status conn (as_user_command t) status

  let find conn ~(transaction_hash : Transaction_hash.t) =
    Signed_command.find conn ~transaction_hash
end

module Internal_command = struct
  type t = {typ: string; receiver_id: int; fee: int; token: int64; hash: string}

  let typ =
    let encode t = Ok ((t.typ, t.receiver_id, t.fee, t.token), t.hash) in
    let decode ((typ, receiver_id, fee, token), hash) =
      Ok {typ; receiver_id; fee; token; hash}
    in
    let rep = Caqti_type.(tup2 (tup4 string int int int64) string) in
    Caqti_type.custom ~encode ~decode rep

  let find (module Conn : CONNECTION) ~(transaction_hash : Transaction_hash.t)
      =
    Conn.find_opt
      (Caqti_request.find_opt Caqti_type.string Caqti_type.int
         "SELECT id FROM internal_commands WHERE hash = ?")
      (Transaction_hash.to_base58_check transaction_hash)
end

module Fee_transfer = struct
  type t =
    { kind: [`Normal | `Via_coinbase]
    ; receiver_id: int
    ; fee: int
    ; token: int64
    ; hash: string }

  let typ =
    let encode t =
      let kind =
        match t.kind with
        | `Normal ->
            "fee_transfer"
        | `Via_coinbase ->
            "fee_transfer_via_coinbase"
      in
      Ok ((kind, t.receiver_id, t.fee, t.token), t.hash)
    in
    let decode ((kind, receiver_id, fee, token), hash) =
      let open Result.Let_syntax in
      let%bind kind =
        match kind with
        | "fee_transfer" ->
            return `Normal
        | "fee_transfer_via_coinbase" ->
            return `Via_coinbase
        | s ->
            Result.fail (sprintf "Bad kind %s in decode attempt" s)
      in
      Ok {kind; receiver_id; fee; token; hash}
    in
    let rep = Caqti_type.(tup2 (tup4 string int int int64) string) in
    Caqti_type.custom ~encode ~decode rep

  let add_if_doesn't_exist (module Conn : CONNECTION)
      (t : Fee_transfer.Single.t) (kind : [`Normal | `Via_coinbase]) =
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
          { kind
          ; receiver_id
          ; fee= Fee_transfer.Single.fee t |> Currency.Fee.to_int
          ; token= Token_id.to_string t.fee_token |> Int64.of_string
          ; hash= transaction_hash |> Transaction_hash.to_base58_check }
end

module Coinbase = struct
  type t = {receiver_id: int; amount: int; hash: string}

  let typ =
    let encode t =
      Ok
        ( ( "coinbase"
          , t.receiver_id
          , t.amount
          , Token_id.(to_string default) |> Int64.of_string )
        , t.hash )
    in
    let decode ((_, receiver_id, amount, _), hash) =
      Ok {receiver_id; amount; hash}
    in
    let rep = Caqti_type.(tup2 (tup4 string int int int64) string) in
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

module Block_and_signed_command = struct
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
        let commands, fee_transfers, coinbases =
          Core.List.fold transactions ~init:([], [], [])
            ~f:(fun (acc_commands, acc_fee_transfers, acc_coinbases) ->
            function
            | { Coda_base.With_status.status
              ; data= Coda_base.Transaction.Command command } ->
                let command = {Coda_base.With_status.status; data= command} in
                (command :: acc_commands, acc_fee_transfers, acc_coinbases)
            | {data= Fee_transfer fee_transfer_bundled; status= _} ->
                let fee_transfers =
                  Coda_base.Fee_transfer.to_list fee_transfer_bundled
                  |> List.map ~f:(fun x -> (`Normal, x))
                in
                (acc_commands, fee_transfers @ acc_fee_transfers, acc_coinbases)
            | {data= Coinbase coinbase; status= _} -> (
              match Coda_base.Coinbase.fee_transfer coinbase with
              | None ->
                  (acc_commands, acc_fee_transfers, coinbase :: acc_coinbases)
              | Some {receiver_pk; fee} ->
                  ( acc_commands
                  , ( `Via_coinbase
                    , Coda_base.Fee_transfer.Single.create ~receiver_pk ~fee
                        ~fee_token:Token_id.default )
                    :: acc_fee_transfers
                  , coinbase :: acc_coinbases ) ) )
        in
        let%bind command_ids =
          deferred_result_list_fold commands ~init:[] ~f:(fun acc command ->
              let%map id =
                Command_transaction.add_with_status
                  (module Conn)
                  command.data command.status
              in
              id :: acc )
        in
        let%bind () =
          deferred_result_list_fold command_ids ~init:()
            ~f:(fun () user_command_id ->
              Block_and_signed_command.add
                (module Conn)
                ~block_id ~user_command_id
              >>| ignore )
        in
        let%bind fee_transfer_ids =
          deferred_result_list_fold fee_transfers ~init:[]
            ~f:(fun acc (kind, fee_transfer) ->
              let%map id =
                Fee_transfer.add_if_doesn't_exist
                  (module Conn)
                  fee_transfer kind
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
    if height > 0 || Int64.(timestamp > 0L) then
      let%bind () =
        (* Delete user commands from old blocks. *)
        Conn.exec
          (Caqti_request.exec
             Caqti_type.(tup2 int int64)
             "DELETE FROM user_commands\n\
              WHERE id IN\n\
              (SELECT user_command_id FROM blocks_user_commands\n\
              INNER JOIN blocks ON blocks.id = block_id\n\
              WHERE (blocks.height < ? OR blocks.timestamp < ?))")
          (height, timestamp)
      in
      let%bind () =
        (* Delete old blocks. *)
        Conn.exec
          (Caqti_request.exec
             Caqti_type.(tup2 int int64)
             "DELETE FROM blocks WHERE blocks.height < ? OR blocks.timestamp \
              < ?")
          (height, timestamp)
      in
      let%bind () =
        (* Delete orphaned internal commands. *)
        Conn.exec
          (Caqti_request.exec Caqti_type.unit
             "DELETE FROM internal_commands\n\
              WHERE id NOT IN\n\
              (SELECT internal_commands.id FROM internal_commands\n\
              INNER JOIN blocks_internal_commands ON\n\
              internal_command_id = internal_commands.id)")
          ()
      in
      let%bind () =
        (* Delete orphaned snarked ledger hashes. *)
        Conn.exec
          (Caqti_request.exec Caqti_type.unit
             "DELETE FROM snarked_ledger_hashes\n\
              WHERE id NOT IN\n\
              (SELECT snarked_ledger_hash_id FROM blocks)")
          ()
      in
      let%bind () =
        (* Delete orphaned public keys. *)
        Conn.exec
          (Caqti_request.exec Caqti_type.unit
             "DELETE FROM public_keys\n\
              WHERE id NOT IN (SELECT fee_payer_id FROM user_commands)\n\
              AND id NOT IN (SELECT source_id FROM user_commands)\n\
              AND id NOT IN (SELECT receiver_id FROM user_commands)\n\
              AND id NOT IN (SELECT receiver_id FROM internal_commands)\n\
              AND id NOT IN (SELECT creator_id FROM blocks)")
          ()
      in
      return ()
    else return ()
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
            [%log warn]
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
        Deferred.List.iter added ~f:(fun command ->
            Command_transaction.add_if_doesn't_exist (module Conn) command
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
      [%log error]
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
                 [%log error]
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
                     [%log error]
                       "Exception while handling RPC server request from \
                        $address: $error"
                       ~metadata:
                         [ ("error", `String (Core.Exn.to_string_mach exn))
                         ; ("context", `String "rpc_server")
                         ; ( "address"
                           , `String (Unix.Inet_addr.to_string address) ) ] ;
                     Deferred.unit )) )
      |> don't_wait_for ;
      [%log info] "Archive process ready. Clients can now connect" ;
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
