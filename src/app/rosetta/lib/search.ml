open Core_kernel
open Async
module Mina_currency = Currency
open Rosetta_lib
module Rosetta_lib_block = Block
open Rosetta_models
open Commands_common

module Transaction_query = struct
  module Filter = struct
    type account_identifier = { address : string; token_id : string }
    [@@deriving to_yojson]

    type t =
      { transaction_hash : string option
      ; account_identifier : account_identifier option
      ; op_status : string option
      ; op_type : Operation_types.t option
      ; success : bool option
      ; address : string option
      }
    [@@deriving to_yojson, make]
  end

  type operator = [ `And | `Or ] [@@deriving to_yojson]

  type t =
    { max_block : int64 option
    ; offset : int64 option
    ; limit : int64 option
    ; operator : operator option
    ; filter : Filter.t
    }
  [@@deriving to_yojson, make]

  module T (M : Monad_fail.S) = struct
    module Token_id = Amount_of.Token_id.T (M)

    let of_search_transaction_request (req : Search_transactions_request.t) =
      let open M.Let_syntax in
      let operator =
        Option.map req.operator ~f:(function `_and -> `And | `_or -> `Or)
      in
      let transaction_hash =
        Option.map req.transaction_identifier ~f:(fun { hash } -> hash)
      in
      let%bind account_identifier =
        Option.value_map req.account_identifier ~default:(M.return None)
          ~f:(fun { address; metadata; _ } ->
            let%bind token_id = Token_id.decode metadata in
            Option.value_map token_id
              ~default:(M.fail @@ Errors.create @@ `Exception "Invalid token_id")
              ~f:(fun token_id -> M.return @@ Some { Filter.address; token_id }) )
      in
      let op_status = req.status in
      let%map op_type =
        Option.value_map req._type ~default:(M.return None) ~f:(fun op_name ->
            Option.value_map
              ~default:
                (M.fail @@ Errors.create @@ `Exception "Invalid operation type")
              (Operation_types.of_name op_name)
              ~f:(fun op_type -> M.return @@ Some op_type) )
      in
      let address = req.address in
      let success = req.success in
      let filter =
        { Filter.transaction_hash
        ; account_identifier
        ; op_status
        ; op_type
        ; address
        ; success
        }
      in
      { max_block = req.max_block
      ; offset = req.offset
      ; limit = req.limit
      ; operator
      ; filter
      }
  end
end

module Make_info_with_block_id (Info : sig
  type t [@@deriving to_yojson]

  module T (M : Monad_fail.S) : sig
    val to_transaction : t -> (Transaction.t, Errors.t) M.t
  end

  val dummies : t list
end) =
struct
  type t = { info : Info.t; block_hash : string; block_height : int64 }
  [@@deriving to_yojson]

  module T (M : Monad_fail.S) = struct
    include Info.T (M)

    let to_indexer_transaction info =
      let open M.Let_syntax in
      let%map transaction = to_transaction info.info in
      let block_identifier =
        Block_identifier.create info.block_height info.block_hash
      in
      { Block_transaction.transaction; block_identifier }
  end

  let dummies =
    List.map Info.dummies ~f:(fun info ->
        { info; block_hash = "HASH"; block_height = 0L } )
end

module Internal_command_info = Make_info_with_block_id (Internal_command_info)
module User_command_info = Make_info_with_block_id (User_command_info)
module Zkapp_command_info = Make_info_with_block_id (Zkapp_command_info)
module Zkapp_account_update_info = Commands_common.Zkapp_account_update_info

module Transactions_info = struct
  type t =
    { total_count : int64
    ; internal_commands : Internal_command_info.t list
    ; user_commands : User_command_info.t list
    ; zkapp_commands : Zkapp_command_info.t list
    }

  let dummy =
    { total_count =
        Int64.of_int
        @@ List.length Internal_command_info.dummies
           + List.length User_command_info.dummies
           + List.length Zkapp_command_info.dummies
    ; internal_commands = Internal_command_info.dummies
    ; user_commands = User_command_info.dummies
    ; zkapp_commands = Zkapp_command_info.dummies
    }

  module T (M : Monad_fail.S) = struct
    module Internal_command_info_ops = Internal_command_info.T (M)
    module User_command_info_ops = User_command_info.T (M)
    module Zkapp_command_info_ops = Zkapp_command_info.T (M)

    let to_transactions info =
      let open M.Let_syntax in
      let%bind internal_transactions =
        List.fold info.internal_commands ~init:(M.return [])
          ~f:(fun acc' info ->
            let%bind transaction =
              Internal_command_info_ops.to_indexer_transaction info
            in
            let%map acc = acc' in
            transaction :: acc )
        |> M.map ~f:List.rev
      in
      let%bind user_transactions =
        List.fold info.user_commands ~init:(M.return []) ~f:(fun acc' info ->
            let%bind transaction =
              User_command_info_ops.to_indexer_transaction info
            in
            let%map acc = acc' in
            transaction :: acc )
        |> M.map ~f:List.rev
      in
      let%map zkapp_command_transactions =
        List.fold info.zkapp_commands ~init:(M.return []) ~f:(fun acc' cmd ->
            let%bind transaction =
              Zkapp_command_info_ops.to_indexer_transaction cmd
            in
            let%map acc = acc' in
            transaction :: acc )
        |> M.map ~f:List.rev
      in
      internal_transactions @ user_transactions @ zkapp_command_transactions
  end
end

module Sql = struct
  module Params = struct
    type t =
      { max_block : int64 option
      ; txn_hash : string option
      ; account_address : string option
      ; account_token_id : string option
      ; op_status : string option
      ; success : string option
      ; address : string option
      }
    [@@deriving hlist, to_yojson]

    let typ =
      let open Mina_caqti.Type_spec in
      let spec =
        Caqti_type.
          [ option int64
          ; option string
          ; option string
          ; option string
          ; option string
          ; option string
          ; option string
          ]
      in
      custom_type ~to_hlist ~of_hlist spec

    let of_query { max_block; Transaction_query.filter; _ } =
      let account_address, account_token_id =
        Option.value_map filter.Transaction_query.Filter.account_identifier
          ~default:(None, None) ~f:(fun { address; token_id } ->
            (Some address, Some token_id) )
      in
      let success =
        Option.map filter.success ~f:(function
          | true ->
              Archive_lib.Processor.applied_str
          | false ->
              Archive_lib.Processor.failed_str )
      in
      { max_block
      ; txn_hash = filter.transaction_hash
      ; account_address
      ; account_token_id
      ; op_status = filter.op_status
      ; success
      ; address = filter.address
      }
  end

  let sql_operators_from_query_operator = function
    | None | Some `And ->
        ("AND", "OR", "IS")
    | Some `Or ->
        ("OR", "AND", "IS NOT")

  let offset_sql offset =
    Option.value_map offset ~default:"0" ~f:Int64.to_string

  let limit_sql limit = Option.value_map limit ~default:"ALL" ~f:Int64.to_string

  let sql_filters ~block_height_field ~txn_hash_field ~account_identifier_fields
      ~op_status_field ~address_fields ~op_type_filters operator =
    let values_for_filter = function
      | `Block_height ->
          ("<=", 1, None)
      | `Txn_hash ->
          ("=", 2, None)
      | `Account_identifier_pk ->
          ("=", 3, None)
      | `Account_identifier_token ->
          ("=", 4, None)
      | `Op_status ->
          ("=", 5, Some "transaction_status")
      | `Success ->
          ("=", 6, Some "transaction_status")
      | `Address ->
          ("=", 7, None)
    in
    let gen_filter (op_1, op_2, null_cmp) l =
      String.concat ~sep:[%string " %{op_1} "]
      @@ List.map l ~f:(function
           | ((_, (_, n, _)) :: _) :: _ as field_n_l ->
               let filters =
                 String.concat ~sep:" OR "
                 @@ List.map field_n_l ~f:(fun l ->
                        String.concat ~sep:" AND "
                        @@ List.map l
                             ~f:(fun (field', (cmp_op, n', cast_opt)) ->
                               Option.value_map cast_opt
                                 ~default:
                                   [%string "%{field'} %{cmp_op} $%{n'#Int}"]
                                 ~f:(fun cast ->
                                   [%string
                                     "%{field'} %{cmp_op} CAST($%{n'#Int} AS \
                                      %{cast})"] ) ) )
               in
               [%string "($%{n#Int} %{null_cmp} NULL %{op_2} (%{filters}))"]
           | _ ->
               "" )
    in
    let block_filter =
      gen_filter
        (sql_operators_from_query_operator (Some `And))
        [ [ [ (block_height_field, values_for_filter `Block_height) ] ] ]
    in
    let ((op_1, _, _) as ops) = sql_operators_from_query_operator operator in
    let gen_filter = gen_filter ops in
    let filters =
      gen_filter
        [ [ [ (txn_hash_field, values_for_filter `Txn_hash) ] ]
        ; List.map account_identifier_fields ~f:(fun (address, token) ->
              [ (address, values_for_filter `Account_identifier_pk)
              ; (token, values_for_filter `Account_identifier_token)
              ] )
        ; [ [ (op_status_field, values_for_filter `Op_status) ] ]
        ; [ [ (op_status_field, values_for_filter `Success) ] ]
        ; List.map address_fields ~f:(fun address ->
              [ (address, values_for_filter `Address) ] )
        ]
    in
    let filters' =
      Option.value_map op_type_filters ~default:filters
        ~f:(fun op_type_filter ->
          [%string "%{filters} %{op_1} (%{op_type_filter})"] )
    in
    [%string "%{block_filter} AND (%{filters'})"]

  let request_to_string ?params req =
    let buffer = Buffer.create 128 in
    let ppf = Format.formatter_of_buffer buffer in
    let () =
      Option.value_map params ~default:(Caqti_request.pp ppf req)
        ~f:(fun params -> Caqti_request.make_pp_with_param () ppf (req, params))
    in
    let () = Format.pp_print_flush ppf () in
    Buffer.contents buffer

  module Block_extras = struct
    type t = { block_hash : string; block_height : int64 }
    [@@deriving hlist, fields]

    let fields = String.concat ~sep:"," [ "b.state_hash"; "b.height" ]

    let typ =
      Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
        Caqti_type.[ string; int64 ]
  end

  module User_commands = struct
    module Cte = struct
      type t =
        { id : int
        ; signed_command : Archive_lib.Processor.User_command.Signed_command.t
        ; block_id : int
        ; sequence_no : int
        ; status : string
        ; failure_reason : string option
        ; state_hash : string
        ; chain_status : string
        ; height : int64
        }
      [@@deriving hlist, fields]

      let fields' =
        List.map
          ( "id"
          :: Archive_lib.Processor.User_command.Signed_command.Fields.names )
          ~f:(fun n -> "u." ^ n)

      let fields =
        String.concat ~sep:"," @@ fields'
        @ [ "buc.block_id"
          ; "buc.sequence_no"
          ; "buc.status"
          ; "buc.failure_reason"
          ; "b.state_hash"
          ; "b.chain_status"
          ; "b.height"
          ]

      let typ =
        Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
          Caqti_type.
            [ int
            ; Archive_lib.Processor.User_command.Signed_command.typ
            ; int
            ; int
            ; string
            ; option string
            ; string
            ; string
            ; int64
            ]

      let query_string operator op_type =
        let op_type_filters =
          Option.map op_type ~f:(function
            | `Fee_payment ->
                "TRUE" (* fees are always paid *)
            | `Payment_source_dec | `Payment_receiver_inc ->
                [%string "u.command_type = 'payment'"]
            | `Delegate_change ->
                [%string "u.command_type = 'delegation'"]
            | `Fee_payer_dec
            | `Account_creation_fee_via_payment
            | `Account_creation_fee_via_fee_receiver
            | `Zkapp_fee_payer_dec
            | `Zkapp_balance_update
            | `Fee_receiver_inc
            | `Coinbase_inc ->
                "FALSE" )
        in
        let default_token =
          [%string "'%{Mina_base.Token_id.(to_string default)}'"]
        in
        let filters =
          sql_filters ~block_height_field:"b.height" ~txn_hash_field:"u.hash"
            ~account_identifier_fields:[ ("pk.value", default_token) ]
            ~op_status_field:"buc.status" ~address_fields:[ "pk.value" ]
            ~op_type_filters operator
        in
        [%string
          {sql|
            SELECT DISTINCT ON (buc.block_id, buc.user_command_id, buc.sequence_no) %{fields}
            FROM user_commands u
            INNER JOIN blocks_user_commands buc
              ON buc.user_command_id = u.id
            INNER JOIN public_keys pk
              ON pk.id = u.fee_payer_id
                OR (buc.status = 'applied' AND (pk.id = u.source_id OR pk.id = u.receiver_id))
            INNER JOIN blocks b
              ON buc.block_id = b.id
            WHERE %{filters}
          |sql}]
    end

    type t =
      { command : Cte.t
      ; fee_payer : string
      ; source : string
      ; receiver : string
      ; account_creation_fee_paid : int64 option
      }
    [@@deriving hlist, fields]

    let fields =
      String.concat ~sep:"," @@ Cte.fields'
      @ [ "u.block_id"
        ; "u.sequence_no"
        ; "u.status"
        ; "u.failure_reason"
        ; "u.state_hash"
        ; "u.chain_status"
        ; "u.height"
        ; "pk_payer.value as fee_payer"
        ; "pk_source.value as source"
        ; "pk_receiver.value as receiver"
        ; "ac.creation_fee"
        ]

    let fee_payer t = `Pk t.fee_payer

    let receiver t = `Pk t.receiver

    let source t = `Pk t.source

    let typ =
      Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
        Caqti_type.[ Cte.typ; string; string; string; option int64 ]

    let query_string ~offset ~limit op_type operator =
      let fields = String.concat ~sep:"," [ "id_count.total_count"; fields ] in
      let offset = offset_sql offset in
      let limit = limit_sql limit in
      [%string
        {sql|
          WITH
            canonical_blocks AS (SELECT * FROM blocks WHERE chain_status = 'canonical'),
            max_canonical_height AS (SELECT MAX(height) as max_height FROM canonical_blocks),
            pending_blocks AS (SELECT b.* FROM blocks b, max_canonical_height WHERE height > max_height AND chain_status = 'pending'),
            blocks AS (SELECT * FROM canonical_blocks UNION ALL SELECT * FROM pending_blocks),
            user_command_info AS (
              %{Cte.query_string operator op_type}
            ),
            id_count AS (
              SELECT COUNT(*) AS total_count FROM user_command_info
            )
            SELECT %{fields}
            FROM id_count,
                (SELECT * FROM user_command_info ORDER BY block_id, id, sequence_no LIMIT %{limit} OFFSET %{offset}) AS u
            INNER JOIN public_keys pk_payer
              ON pk_payer.id = u.fee_payer_id
            INNER JOIN public_keys pk_source
              ON pk_source.id = u.source_id
            INNER JOIN public_keys pk_receiver
              ON pk_receiver.id = u.receiver_id
            /* Account creation fees are attributed to the first successful command in the
              block that mentions the account with the following LEFT JOINs */
            LEFT JOIN account_identifiers ai_receiver
              ON ai_receiver.public_key_id = u.receiver_id
            LEFT JOIN accounts_created ac
              ON u.block_id = ac.block_id
              AND ai_receiver.id = ac.account_identifier_id
              AND u.status = 'applied'
              AND u.sequence_no =
                (SELECT LEAST(
                    (SELECT min(bic2.sequence_no)
                    FROM blocks_internal_commands bic2
                    INNER JOIN internal_commands ic2
                        ON bic2.internal_command_id = ic2.id
                    WHERE ic2.receiver_id = u.receiver_id
                        AND bic2.block_id = u.block_id
                        AND bic2.status = 'applied'),
                    (SELECT min(buc2.sequence_no)
                      FROM blocks_user_commands buc2
                      INNER JOIN user_commands uc2
                        ON buc2.user_command_id = uc2.id
                      WHERE uc2.receiver_id = u.receiver_id
                        AND buc2.block_id = u.block_id
                        AND buc2.status = 'applied')))
            ORDER BY u.block_id, u.id, u.sequence_no
        |sql}]

    let run (module Conn : Mina_caqti.CONNECTION) ~logger ~offset ~limit input =
      let open Deferred.Result.Let_syntax in
      let params = Params.of_query input in
      let query_string =
        query_string ~offset ~limit
          Transaction_query.(input.filter.Filter.op_type)
          input.operator
      in
      let query =
        Mina_caqti.collect_req Params.typ Caqti_type.(t2 int64 typ) query_string
      in
      [%log debug] "Running SQL query $query"
        ~metadata:[ ("query", `String (request_to_string ~params query)) ] ;
      match%map Conn.collect_list query params with
      | [] ->
          (0L, [])
      | (total_count, _) :: _ as user_commands ->
          (total_count, List.map user_commands ~f:snd)

    let to_info ({ command = { signed_command = uc; _ } as command; _ } as t) =
      let open Result.Let_syntax in
      let%bind kind =
        match
          uc.Archive_lib.Processor.User_command.Signed_command.command_type
        with
        | "payment" ->
            Result.return `Payment
        | "delegation" ->
            Result.return `Delegation
        | other ->
            Result.fail
              (Errors.create
                 ~context:
                   [%string
                     "The archive database is storing user commands with \
                      %{other}; this is not a known type. Please report a bug!"]
                 `Invariant_violation )
      in
      (* TODO: do we want to mention tokens at all here? *)
      let fee_token = Mina_base.Token_id.(to_string default) in
      let token = Mina_base.Token_id.(to_string default) in
      let%map failure_status =
        match Cte.failure_reason command with
        | None -> (
            match account_creation_fee_paid t with
            | None ->
                Result.return
                @@ `Applied
                     Commands_common.User_command_info
                     .Account_creation_fees_paid
                     .By_no_one
            | Some receiver ->
                Result.return
                @@ `Applied
                     (Commands_common.User_command_info
                      .Account_creation_fees_paid
                      .By_receiver
                        (Unsigned.UInt64.of_int64 receiver) ) )
        | Some status ->
            Result.return @@ `Failed status
      in
      let info =
        { Commands_common.User_command_info.kind
        ; fee_payer = fee_payer t
        ; source = source t
        ; receiver = receiver t
        ; fee_token = `Token_id fee_token
        ; token = `Token_id token
        ; nonce = Unsigned.UInt32.of_int64 uc.nonce
        ; amount = Option.map ~f:Unsigned.UInt64.of_string uc.amount
        ; fee = Unsigned.UInt64.of_string uc.fee
        ; hash = uc.hash
        ; failure_status = Some failure_status
        ; valid_until = Option.map ~f:Unsigned.UInt32.of_int64 uc.valid_until
        ; memo = (if String.equal uc.memo "" then None else Some uc.memo)
        }
      in
      { User_command_info.info
      ; block_hash = Cte.state_hash command
      ; block_height = Cte.height command
      }
  end

  module Internal_commands = struct
    module Filtered_commands_cte = struct
      type t =
        { internal_command_id : int
        ; raw_internal_command : Archive_lib.Processor.Internal_command.t
        ; receiver : string
        ; coinbase_receiver : string option
        ; sequence_no : int
        ; secondary_sequence_no : int
        ; block_id : int
        ; block_hash : string
        ; block_height : int64
        }
      [@@deriving hlist, fields]

      let fields' =
        String.concat ~sep:","
        @@ List.map
             ~f:(fun n -> "i." ^ n)
             Archive_lib.Processor.Internal_command.Fields.names

      let fields =
        String.concat ~sep:","
          [ "i.id"
          ; fields'
          ; "pk.value as receiver"
          ; "cri.coinbase_receiver"
          ; "bic.sequence_no"
          ; "bic.secondary_sequence_no"
          ; "bic.block_id"
          ; "b.state_hash"
          ; "b.height"
          ]

      let receiver t = `Pk t.receiver

      let coinbase_receiver t =
        Option.map ~f:(fun pk -> `Pk pk) t.coinbase_receiver

      let typ =
        Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
          Caqti_type.
            [ int
            ; Archive_lib.Processor.Internal_command.typ
            ; string
            ; option string
            ; int
            ; int
            ; int
            ; string
            ; int64
            ]

      let query_string filters =
        [%string
          {sql|
            SELECT DISTINCT ON (bic.block_id, bic.internal_command_id, bic.sequence_no, bic.secondary_sequence_no) %{fields}
            FROM internal_commands i
            INNER JOIN blocks_internal_commands bic
              ON bic.internal_command_id = i.id
            INNER JOIN public_keys pk
              ON pk.id = i.receiver_id
            INNER JOIN blocks b
              ON bic.block_id = b.id
            LEFT JOIN coinbase_receiver_info cri
              ON bic.block_id = cri.block_id
                AND bic.internal_command_id = cri.internal_command_id
                AND bic.sequence_no = cri.sequence_no
                AND bic.secondary_sequence_no = cri.secondary_sequence_no
            WHERE %{filters}
        |sql}]
    end

    type t =
      { internal_command : Filtered_commands_cte.t
      ; receiver_account_creation_fee_paid : int64 option
      }
    [@@deriving hlist, fields]

    let fields =
      String.concat ~sep:"," [ Filtered_commands_cte.fields; "ac.creation_fee" ]

    let typ =
      Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
        Caqti_type.[ Filtered_commands_cte.typ; option int64 ]

    let query_string ~offset ~limit op_type operator =
      let fields =
        String.concat ~sep:","
          [ "id_count.total_count"; "i.*"; "ac.creation_fee" ]
      in
      let op_type_filters =
        Option.map op_type ~f:(function
          | `Coinbase_inc ->
              "i.command_type = 'coinbase'"
          | `Fee_receiver_inc ->
              "i.command_type = 'fee_transfer' OR i.command_type = \
               'fee_transfer_via_coinbase'"
          | `Fee_payer_dec ->
              "i.command_type = 'fee_transfer_via_coinbase'"
          | `Account_creation_fee_via_fee_receiver ->
              "ac.creation_fee IS NOT NULL"
          | `Account_creation_fee_via_payment
          | `Payment_source_dec
          | `Payment_receiver_inc
          | `Fee_payment
          | `Delegate_change
          | `Zkapp_fee_payer_dec
          | `Zkapp_balance_update ->
              "FALSE" )
      in
      let default_token =
        [%string "'%{Mina_base.Token_id.(to_string default)}'"]
      in
      let filters =
        let address_fields = [ "pk.value"; "cri.coinbase_receiver" ] in
        sql_filters ~block_height_field:"b.height" ~txn_hash_field:"i.hash"
          ~account_identifier_fields:
            (List.map ~f:(fun field -> (field, default_token)) address_fields)
          ~op_status_field:"bic.status" ~address_fields ~op_type_filters
          operator
      in
      let offset = offset_sql offset in
      let limit = limit_sql limit in
      [%string
        {sql|
            WITH canonical_blocks AS (SELECT * FROM blocks WHERE chain_status = 'canonical'),
            max_canonical_height AS (SELECT MAX(height) as max_height FROM canonical_blocks),
            pending_blocks AS (SELECT b.* FROM blocks b, max_canonical_height WHERE height > max_height AND chain_status = 'pending'),
            blocks AS (SELECT * FROM canonical_blocks UNION ALL SELECT * FROM pending_blocks),
            coinbase_receiver_info AS (
                SELECT bic.block_id, bic.internal_command_id, bic.sequence_no, bic.secondary_sequence_no, coinbase_receiver_pk.value as coinbase_receiver
                FROM blocks_internal_commands bic
                INNER JOIN internal_commands ic ON bic.internal_command_id = ic.id
                INNER JOIN blocks_internal_commands bic_coinbase_receiver
                    ON bic.block_id = bic_coinbase_receiver.block_id
                        AND (bic.internal_command_id <> bic_coinbase_receiver.internal_command_id
                            OR bic.sequence_no <> bic_coinbase_receiver.sequence_no
                            OR bic.secondary_sequence_no <> bic_coinbase_receiver.secondary_sequence_no)
                INNER JOIN internal_commands ic_coinbase_receiver
                    ON ic.command_type = 'fee_transfer_via_coinbase'
                        AND ic_coinbase_receiver.command_type = 'coinbase'
                        AND ic_coinbase_receiver.id = bic_coinbase_receiver.internal_command_id
                INNER JOIN public_keys coinbase_receiver_pk ON ic_coinbase_receiver.receiver_id = coinbase_receiver_pk.id
            ),
            internal_commands_info AS (%{Filtered_commands_cte.query_string filters}),
            id_count AS (
              SELECT COUNT(*) AS total_count FROM internal_commands_info
            )
            SELECT %{fields}
            FROM id_count, (SELECT * FROM internal_commands_info ORDER BY block_id, id, sequence_no, secondary_sequence_no LIMIT %{limit} OFFSET %{offset}) i
            LEFT JOIN account_identifiers ai
              ON ai.public_key_id = receiver_id
            LEFT JOIN accounts_created ac
              ON ac.account_identifier_id = ai.id
              AND ac.block_id = i.block_id
              AND i.sequence_no =
                  (SELECT LEAST(
                      (SELECT min(bic2.sequence_no)
                      FROM blocks_internal_commands bic2
                      INNER JOIN internal_commands ic2
                          ON bic2.internal_command_id = ic2.id
                      WHERE ic2.receiver_id = i.receiver_id
                          AND bic2.block_id = i.block_id
                          AND bic2.status = 'applied'),
                      (SELECT min(buc2.sequence_no)
                        FROM blocks_user_commands buc2
                        INNER JOIN user_commands uc2
                          ON buc2.user_command_id = uc2.id
                        WHERE uc2.receiver_id = i.receiver_id
                          AND buc2.block_id = i.block_id
                          AND buc2.status = 'applied')))
            ORDER BY i.block_id, i.id, i.sequence_no, i.secondary_sequence_no
          |sql}]

    let run (module Conn : Mina_caqti.CONNECTION) ~logger ~offset ~limit input =
      let open Deferred.Result.Let_syntax in
      let params = Params.of_query input in
      let query =
        Mina_caqti.collect_req Params.typ Caqti_type.(t2 int64 typ)
        @@ query_string ~offset ~limit input.filter.op_type input.operator
      in
      [%log debug] "Running SQL query $query"
        ~metadata:[ ("query", `String (request_to_string ~params query)) ] ;
      match%map Conn.collect_list query params with
      | [] ->
          (0L, [])
      | (total_count, _) :: _ as internal_commands ->
          (total_count, List.map internal_commands ~f:snd)

    let to_info ({ internal_command; _ } as t : t) =
      let open Result.Let_syntax in
      let%map info =
        Rosetta_lib_block.Sql.Internal_commands.Cte.to_info
          ~coinbase_receiver:
            (Filtered_commands_cte.coinbase_receiver internal_command)
          { Rosetta_lib_block.Sql.Internal_commands.Cte.internal_command_id =
              internal_command.internal_command_id
          ; raw_internal_command = internal_command.raw_internal_command
          ; receiver = internal_command.receiver
          ; sequence_no = internal_command.sequence_no
          ; secondary_sequence_no = internal_command.secondary_sequence_no
          ; receiver_account_creation_fee_paid =
              receiver_account_creation_fee_paid t
          }
      in
      { Internal_command_info.info
      ; block_hash = internal_command.block_hash
      ; block_height = internal_command.block_height
      }
  end

  module Zkapp_commands = struct
    type t =
      { zkapp_command : Rosetta_lib_block.Sql.Zkapp_commands.t
      ; block_id : int
      ; block_hash : string
      ; block_height : int64
      }
    [@@deriving hlist]

    let fields =
      String.concat ~sep:","
        [ Rosetta_lib_block.Sql.Zkapp_commands.fields
        ; "bzc.block_id"
        ; "b.state_hash"
        ; "b.height"
        ]

    let typ =
      Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
        Caqti_type.
          [ Rosetta_lib_block.Sql.Zkapp_commands.typ; int; string; int64 ]

    let cte_query_string filters =
      [%string
        {sql|
            SELECT %{fields}
            FROM zkapp_commands zc
            INNER JOIN blocks_zkapp_commands bzc
              ON zc.id = bzc.zkapp_command_id
            INNER JOIN zkapp_fee_payer_body zfpb
              ON zc.zkapp_fee_payer_body_id = zfpb.id
            INNER JOIN public_keys pk_fee_payer
              ON zfpb.public_key_id = pk_fee_payer.id
            INNER JOIN blocks b
              ON bzc.block_id = b.id
            LEFT JOIN zkapp_account_update zau
              ON zau.id = ANY (zc.zkapp_account_updates_ids)
            INNER JOIN zkapp_account_update_body zaub
              ON zaub.id = zau.body_id
            INNER JOIN account_identifiers ai_update_body
              ON zaub.account_identifier_id = ai_update_body.id
            INNER JOIN public_keys pk_update_body
              ON ai_update_body.public_key_id = pk_update_body.id
            INNER JOIN tokens token_update_body
              ON token_update_body.id = ai_update_body.token_id
            WHERE %{filters}
        |sql}]

    let query_string ~offset ~limit ~filters =
      let fields = String.concat ~sep:"," [ "id_count.total_count"; "zc.*" ] in
      let ctes_string =
        String.concat ~sep:","
          [ "canonical_blocks AS (SELECT * FROM blocks WHERE chain_status = \
             'canonical')"
          ; "max_canonical_height AS (SELECT MAX(height) as max_height FROM \
             canonical_blocks)"
          ; "pending_blocks AS (SELECT b.* FROM blocks b, max_canonical_height \
             WHERE height > max_height AND chain_status = 'pending')"
          ; "blocks AS (SELECT * FROM canonical_blocks UNION ALL SELECT * FROM \
             pending_blocks)"
          ; [%string "zkapp_commands_info AS (%{cte_query_string filters})"]
          ; "zkapp_commands_ids AS (SELECT DISTINCT id, block_id, sequence_no \
             FROM zkapp_commands_info)"
          ; "id_count AS (SELECT COUNT(*) AS total_count FROM \
             zkapp_commands_ids)"
          ]
      in
      [%string
        {sql|
          WITH %{ctes_string}
          SELECT %{fields}
          FROM id_count, (SELECT * FROM zkapp_commands_ids ORDER BY block_id, id, sequence_no LIMIT %{limit} OFFSET %{offset}) as ids
          INNER JOIN zkapp_commands_info zc ON ids.id = zc.id AND ids.block_id = zc.block_id AND ids.sequence_no = zc.sequence_no
          ORDER BY block_id, id, sequence_no
        |sql}]

    let query ~offset ~limit op_type operator =
      let offset = offset_sql offset in
      let limit = limit_sql limit in
      let op_type_filters =
        Option.map op_type ~f:(function
          | `Zkapp_fee_payer_dec ->
              "TRUE"
          | `Zkapp_balance_update ->
              "zaub.id IS NOT NULL"
          | `Fee_payer_dec
          | `Fee_receiver_inc
          | `Coinbase_inc
          | `Account_creation_fee_via_payment
          | `Account_creation_fee_via_fee_receiver
          | `Payment_source_dec
          | `Payment_receiver_inc
          | `Fee_payment
          | `Delegate_change ->
              "FALSE" )
      in
      let filters =
        let default_token =
          [%string "'%{Mina_base.Token_id.(to_string default)}'"]
        in
        sql_filters ~block_height_field:"b.height" ~txn_hash_field:"zc.hash"
          ~account_identifier_fields:
            [ ("pk_fee_payer.value", default_token)
            ; ("pk_update_body.value", "token_update_body.value")
            ]
          ~op_status_field:"bzc.status"
          ~address_fields:[ "pk_fee_payer.value"; "pk_update_body.value" ]
          ~op_type_filters operator
      in
      Mina_caqti.collect_req Params.typ Caqti_type.(t2 int64 typ)
      @@ query_string ~offset ~limit ~filters

    let run (module Conn : Mina_caqti.CONNECTION) ~logger ~offset ~limit input =
      let open Deferred.Result.Let_syntax in
      let params = Params.of_query input in
      let query = query ~offset ~limit input.filter.op_type input.operator in
      [%log debug] "Running SQL query $query"
        ~metadata:[ ("query", `String (request_to_string ~params query)) ] ;
      match%map Conn.collect_list query params with
      | [] ->
          (0L, [])
      | (total_count, _) :: _ as res ->
          (total_count, List.map res ~f:snd)

    include Rosetta_lib_block.Sql.Zkapp_commands.Make_common (struct
      type command = t

      type account_update_info = Zkapp_account_update_info.t

      type info = Zkapp_command_info.t

      let is_same_command t_1 t_2 =
        t_1.block_id = t_2.block_id
        && t_1.zkapp_command.zkapp_command_id
           = t_2.zkapp_command.zkapp_command_id
        && t_1.zkapp_command.zkapp_command_extras.sequence_no
           = t_2.zkapp_command.zkapp_command_extras.sequence_no

      let to_account_update_info command =
        Rosetta_lib_block.Sql.Zkapp_commands.to_account_update_info
          command.zkapp_command

      let account_updates_and_command_to_info account_updates
          { zkapp_command; block_hash; block_height; _ } =
        let info =
          Rosetta_lib_block.Sql.Zkapp_commands
          .account_updates_and_command_to_info account_updates zkapp_command
        in
        { Zkapp_command_info.info; block_hash; block_height }
    end)
  end

  let run (module Conn : Mina_caqti.CONNECTION) ~logger query =
    let module Result = struct
      include Result

      module List = struct
        let map ~f l =
          map ~f:List.rev
          @@ List.fold_result l ~init:[] ~f:(fun acc x ->
                 f x >>| fun x -> x :: acc )
      end
    end in
    let module M = Deferred.Result in
    let open M.Let_syntax in
    let offset = query.Transaction_query.offset in
    let limit = query.limit in
    let%bind user_commands_count, raw_user_commands =
      User_commands.run ~logger ~offset ~limit (module Conn) query
      |> Errors.Lift.sql ~context:"Finding user commands with transaction query"
    in
    let offset =
      Option.map offset ~f:(fun offset ->
          Int64.(max 0L (offset - user_commands_count)) )
    in
    let limit =
      Option.map limit ~f:(fun limit ->
          Int64.(max 0L (limit - user_commands_count)) )
    in
    let%bind internal_commands_count, raw_internal_commands =
      Internal_commands.run (module Conn) ~logger ~offset ~limit query
      |> Errors.Lift.sql ~context:"Finding internal commands within block"
    in
    let offset =
      Option.map offset ~f:(fun offset ->
          Int64.(max 0L (offset - user_commands_count)) )
    in
    let limit =
      Option.map limit ~f:(fun limit ->
          Int64.(max 0L (limit - user_commands_count)) )
    in
    let%bind zkapp_commands_count, raw_zkapp_commands =
      Zkapp_commands.run (module Conn) ~logger ~offset ~limit query
      |> Errors.Lift.sql ~context:"Finding zkapp commands within block"
    in
    let%bind internal_commands =
      Deferred.return
      @@ Result.List.map raw_internal_commands ~f:Internal_commands.to_info
    in
    let%map user_commands =
      Deferred.return
      @@ Result.List.map raw_user_commands ~f:User_commands.to_info
    in
    let zkapp_commands = Zkapp_commands.to_command_infos raw_zkapp_commands in
    { total_count =
        Int64.(
          user_commands_count + internal_commands_count + zkapp_commands_count)
    ; Transactions_info.internal_commands
    ; user_commands
    ; zkapp_commands
    }
end

module Specific = struct
  module Env = struct
    (* All side-effects go in the env so we can mock them out later *)
    module T (M : Monad_fail.S) = struct
      type 'gql t =
        { db_transactions :
            Transaction_query.t -> (Transactions_info.t, Errors.t) M.t
        ; validate_network_choice :
               network_identifier:Network_identifier.t
            -> minimum_user_command_fee:Mina_currency.Fee.t
            -> graphql_uri:Uri.t
            -> (unit, Errors.t) M.t
        }
    end

    (* The real environment does things asynchronously *)
    module Real = T (Deferred.Result)

    (* But for tests, we want things to go fast *)
    module Mock = T (Result)

    let real :
        logger:Logger.t -> db:(module Mina_caqti.CONNECTION) -> 'gql Real.t =
     fun ~logger ~db ->
      { db_transactions = Sql.run ~logger db
      ; validate_network_choice = Network.Validate_choice.Real.validate
      }

    let mock : 'gql Mock.t =
      { db_transactions = (fun _query -> Result.return Transactions_info.dummy)
      ; validate_network_choice = Network.Validate_choice.Mock.succeed
      }
  end

  module Impl (M : Monad_fail.S) = struct
    module Query = Transaction_query.T (M)
    module Internal_command_info_ops = Internal_command_info.T (M)
    module User_command_info_ops = User_command_info.T (M)
    module Zkapp_command_info_ops = Zkapp_command_info.T (M)

    let handle :
           graphql_uri:Uri.t
        -> minimum_user_command_fee:Mina_currency.Fee.t
        -> env:'gql Env.T(M).t
        -> Search_transactions_request.t
        -> (Search_transactions_response.t, Errors.t) M.t =
     fun ~graphql_uri ~minimum_user_command_fee ~env req ->
      let open M.Let_syntax in
      let%bind query = Query.of_search_transaction_request req in
      let%bind () =
        env.validate_network_choice ~network_identifier:req.network_identifier
          ~graphql_uri ~minimum_user_command_fee
      in
      let%bind transactions_info = env.db_transactions query in
      let%bind internal_transactions =
        List.fold transactions_info.internal_commands ~init:(M.return [])
          ~f:(fun macc info ->
            let%bind transaction =
              Internal_command_info_ops.to_indexer_transaction info
            in
            let%map acc = macc in
            transaction :: acc )
        |> M.map ~f:List.rev
      in
      let%bind user_transactions =
        List.fold transactions_info.user_commands ~init:(M.return [])
          ~f:(fun acc' cmd ->
            let%bind transaction =
              User_command_info_ops.to_indexer_transaction cmd
            in
            let%map acc = acc' in
            transaction :: acc )
        |> M.map ~f:List.rev
      in
      let%map zkapp_transactions =
        List.fold transactions_info.zkapp_commands ~init:(M.return [])
          ~f:(fun acc' cmd ->
            let%bind transaction =
              Zkapp_command_info_ops.to_indexer_transaction cmd
            in
            let%map acc = acc' in
            transaction :: acc )
        |> M.map ~f:List.rev
      in
      let next_offset =
        Option.bind query.limit ~f:(fun limit ->
            let offset = Option.value query.offset ~default:0L in
            let next_offset = Int64.(offset + limit) in
            if Int64.(next_offset >= transactions_info.total_count) then None
            else Some next_offset )
      in
      { Search_transactions_response.next_offset
      ; total_count = transactions_info.total_count
      ; transactions =
          internal_transactions @ user_transactions @ zkapp_transactions
      }
  end

  module Real = Impl (Deferred.Result)
end

let router ~graphql_uri ~minimum_user_command_fee ~logger ~with_db
    (route : string list) body =
  let open Async.Deferred.Result.Let_syntax in
  [%log debug] "Handling /search/ $route"
    ~metadata:[ ("route", `List (List.map route ~f:(fun s -> `String s))) ] ;
  [%log info] "Search $params" ~metadata:[ ("params", body) ] ;
  match route with
  | [ "transactions" ] ->
      with_db (fun ~db ->
          let%bind req =
            Errors.Lift.parse ~context:"Request"
            @@ Search_transactions_request.of_yojson body
            |> Errors.Lift.wrap
          in
          let%map res =
            Specific.Real.handle ~graphql_uri ~minimum_user_command_fee
              ~env:(Specific.Env.real ~logger ~db)
              req
            |> Errors.Lift.wrap
          in
          Search_transactions_response.to_yojson res )
  | _ ->
      Deferred.Result.fail `Page_not_found
