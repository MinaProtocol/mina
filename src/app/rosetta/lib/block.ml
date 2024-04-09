open Core_kernel
open Async
open Rosetta_lib
open Rosetta_models

let account_id = User_command_info.account_id

module Block_query = struct
  type t = ([ `Height of int64 ], [ `Hash of string ]) These.t option

  module T (M : Monad_fail.S) = struct
    let of_partial_identifier (identifier : Partial_block_identifier.t) =
      match (identifier.index, identifier.hash) with
      | None, None ->
          M.return None
      | Some index, None ->
          M.return (Some (`This (`Height index)))
      | None, Some hash ->
          M.return (Some (`That (`Hash hash)))
      | Some index, Some hash ->
          M.return (Some (`Those (`Height index, `Hash hash)))

    let of_partial_identifier' (identifier : Partial_block_identifier.t option)
        =
      of_partial_identifier
        (Option.value identifier
           ~default:{ Partial_block_identifier.index = None; hash = None } )
  end

  let to_string : t -> string = function
    | Some (`This (`Height h)) ->
        sprintf "height = %Ld" h
    | Some (`That (`Hash h)) ->
        sprintf "hash = %s" h
    | Some (`Those (`Height height, `Hash hash)) ->
        sprintf "height = %Ld, hash = %s" height hash
    | None ->
        sprintf "(no height or hash given)"
end

module Op = User_command_info.Op

(* TODO: Populate postgres DB with at least one of each kind of transaction and
 * then make sure ops make sense: #5501 *)

module Internal_command_info = struct
  module Kind = struct
    type t = [ `Coinbase | `Fee_transfer | `Fee_transfer_via_coinbase ]
    [@@deriving equal, to_yojson]

    let to_string (t : t) =
      match t with
      | `Coinbase ->
          "coinbase"
      | `Fee_transfer ->
          "fee_transfer"
      | `Fee_transfer_via_coinbase ->
          "fee_transfer_via_coinbase"
  end

  type t =
    { kind : Kind.t
    ; receiver : [ `Pk of string ]
    ; receiver_account_creation_fee_paid : Unsigned_extended.UInt64.t option
    ; fee : Unsigned_extended.UInt64.t
    ; token : [ `Token_id of string ]
    ; sequence_no : int
    ; secondary_sequence_no : int
    ; hash : string
    }
  [@@deriving to_yojson]

  module T (M : Monad_fail.S) = struct
    module Op_build = Op.T (M)

    let to_operations ~coinbase_receiver (t : t) :
        (Operation.t list, Errors.t) M.t =
      (* We choose to represent the dec-side of fee transfers from txns from the
       * canonical user command that created them so we are able consistently
       * produce more balance changing operations in the mempool or a block.
       * *)
      let plan : 'a Op.t list =
        let mk_account_creation_fee related =
          match t.receiver_account_creation_fee_paid with
          | None ->
              []
          | Some fee ->
              [ { Op.label = `Account_creation_fee_via_fee_receiver fee
                ; related_to = Some related
                }
              ]
        in
        match t.kind with
        | `Coinbase ->
            (* The coinbase transaction is really incrementing by the coinbase
               * amount *)
            [ { Op.label = `Coinbase_inc; related_to = None } ]
            @ mk_account_creation_fee `Coinbase_inc
        | `Fee_transfer ->
            [ { Op.label = `Fee_receiver_inc; related_to = None } ]
            @ mk_account_creation_fee `Fee_receiver_inc
        | `Fee_transfer_via_coinbase ->
            [ { Op.label = `Fee_receiver_inc; related_to = None }
            ; { Op.label = `Fee_payer_dec; related_to = Some `Fee_receiver_inc }
            ]
            @ mk_account_creation_fee `Fee_receiver_inc
      in
      Op_build.build
        ~a_eq:
          [%equal:
            [ `Coinbase_inc
            | `Fee_payer_dec
            | `Fee_receiver_inc
            | `Account_creation_fee_via_fee_receiver of Unsigned.UInt64.t ]]
        ~plan ~f:(fun ~related_operations ~operation_identifier op ->
          (* All internal commands succeed if they're in blocks *)
          let status = Some (Operation_statuses.name `Success) in
          match op.label with
          | `Coinbase_inc ->
              M.return
                { Operation.operation_identifier
                ; related_operations
                ; status
                ; account =
                    Some
                      (account_id t.receiver
                         (`Token_id Amount_of.Token_id.default) )
                ; _type = Operation_types.name `Coinbase_inc
                ; amount =
                    Some
                      (Amount_of.token (`Token_id Amount_of.Token_id.default)
                         t.fee )
                ; coin_change = None
                ; metadata = None
                }
          | `Fee_receiver_inc ->
              M.return
                { Operation.operation_identifier
                ; related_operations
                ; status
                ; account = Some (account_id t.receiver t.token)
                ; _type = Operation_types.name `Fee_receiver_inc
                ; amount = Some (Amount_of.token t.token t.fee)
                ; coin_change = None
                ; metadata = None
                }
          | `Fee_payer_dec ->
              let open M.Let_syntax in
              let%map coinbase_receiver =
                match coinbase_receiver with
                | Some r ->
                    M.return r
                | None ->
                    M.fail
                      (Errors.create
                         ~context:
                           "This operation existing (fee payer dec within \
                            Internal_command) demands a coinbase receiver to \
                            exist. Please report this bug."
                         `Invariant_violation )
              in
              { Operation.operation_identifier
              ; related_operations
              ; status
              ; account =
                  Some
                    (account_id coinbase_receiver
                       (`Token_id Amount_of.Token_id.default) )
              ; _type = Operation_types.name `Fee_payer_dec
              ; amount = Some Amount_of.(negated (mina t.fee))
              ; coin_change = None
              ; metadata = None
              }
          | `Account_creation_fee_via_fee_receiver account_creation_fee ->
              M.return
                { Operation.operation_identifier
                ; related_operations
                ; status
                ; account =
                    Some
                      (account_id t.receiver
                         (`Token_id Amount_of.Token_id.default) )
                ; _type =
                    Operation_types.name `Account_creation_fee_via_fee_receiver
                ; amount = Some Amount_of.(negated @@ mina account_creation_fee)
                ; coin_change = None
                ; metadata = None
                } )
  end

  let dummies =
    [ { kind = `Coinbase
      ; receiver = `Pk "Eve"
      ; receiver_account_creation_fee_paid = None
      ; fee = Unsigned.UInt64.of_int 20_000_000_000
      ; token = `Token_id Amount_of.Token_id.default
      ; sequence_no = 1
      ; secondary_sequence_no = 0
      ; hash = "COINBASE_1"
      }
    ; { kind = `Fee_transfer
      ; receiver = `Pk "Alice"
      ; receiver_account_creation_fee_paid = None
      ; fee = Unsigned.UInt64.of_int 30_000_000_000
      ; token = `Token_id Amount_of.Token_id.default
      ; sequence_no = 1
      ; secondary_sequence_no = 0
      ; hash = "FEE_TRANSFER"
      }
    ]
end

module Zkapp_account_update_info = struct
  type t =
    { authorization_kind : string
    ; account : [ `Pk of string ]
    ; balance_change : string
    ; increment_nonce : bool
    ; may_use_token : string
    ; call_depth : Unsigned_extended.UInt64.t
    ; use_full_commitment : bool
    ; status : [ `Success | `Failed ]
    ; token : [ `Token_id of string ]
    }
  [@@deriving to_yojson, equal]

  let dummies =
    [ { authorization_kind = "OK"
      ; account = `Pk "Eve"
      ; balance_change = "-1000000"
      ; increment_nonce = false
      ; may_use_token = "no"
      ; call_depth = Unsigned.UInt64.of_int 10
      ; use_full_commitment = true
      ; status = `Success
      ; token = `Token_id Amount_of.Token_id.default
      }
    ; { authorization_kind = "NOK"
      ; account = `Pk "Alice"
      ; balance_change = "20000000"
      ; increment_nonce = true
      ; may_use_token = "no"
      ; call_depth = Unsigned.UInt64.of_int 20
      ; use_full_commitment = false
      ; status = `Failed
      ; token = `Token_id Amount_of.Token_id.default
      }
    ]
end

module Zkapp_command_info = struct
  type t =
    { fee : Unsigned_extended.UInt64.t
    ; fee_payer : [ `Pk of string ]
    ; valid_until : Unsigned_extended.UInt32.t option
    ; nonce : Unsigned_extended.UInt32.t
    ; token : [ `Token_id of string ]
    ; sequence_no : int
    ; memo : string option
    ; hash : string
    ; failure_reasons : string list
    ; account_updates : Zkapp_account_update_info.t list
    }
  [@@deriving to_yojson]

  module T (M : Monad_fail.S) = struct
    module Op_build = Op.T (M)

    let to_operations (t : t) =
      Op_build.build
        ~a_eq:
          [%equal:
            [ `Zkapp_fee_payer_dec
            | `Zkapp_account_update of Zkapp_account_update_info.t ]]
        ~plan:
          ( { Op.label = `Zkapp_fee_payer_dec; related_to = None }
          :: List.map t.account_updates ~f:(fun upd ->
                 { Op.label = `Zkapp_account_update upd; related_to = None } )
          )
        ~f:(fun ~related_operations ~operation_identifier op ->
          match op.label with
          | `Zkapp_fee_payer_dec ->
              M.return
                { Operation.operation_identifier
                ; related_operations
                ; status = Some (Operation_statuses.name `Success)
                ; account =
                    Some
                      (account_id t.fee_payer
                         (`Token_id Amount_of.Token_id.default) )
                ; _type = Operation_types.name `Zkapp_fee_payer_dec
                ; amount =
                    Some
                      Amount_of.(
                        negated
                        @@ token (`Token_id Amount_of.Token_id.default) t.fee)
                ; coin_change = None
                ; metadata = None
                }
          | `Zkapp_account_update upd ->
              let status = Some (Operation_statuses.name upd.status) in
              let amount =
                match String.chop_prefix ~prefix:"-" upd.balance_change with
                | Some amount ->
                    Some
                      Amount_of.(
                        negated @@ token upd.token
                        @@ Unsigned_extended.UInt64.of_string amount)
                | None ->
                    Some
                      Amount_of.(
                        token upd.token
                        @@ Unsigned_extended.UInt64.of_string upd.balance_change)
              in
              M.return
                { Operation.operation_identifier
                ; related_operations
                ; status
                ; account = Some (account_id upd.account upd.token)
                ; _type = Operation_types.name `Zkapp_balance_update
                ; amount
                ; coin_change = None
                ; metadata = None
                } )
  end

  let dummies =
    [ { fee_payer = `Pk "Eve"
      ; fee = Unsigned.UInt64.of_int 20_000_000_000
      ; token = `Token_id Amount_of.Token_id.default
      ; sequence_no = 1
      ; hash = "COMMAND_1"
      ; failure_reasons = []
      ; valid_until = Some (Unsigned.UInt32.of_int 10_000)
      ; nonce = Unsigned.UInt32.of_int 3
      ; memo = Some "Hey"
      ; account_updates = Zkapp_account_update_info.dummies
      }
    ; { fee_payer = `Pk "Alice"
      ; fee = Unsigned.UInt64.of_int 10_000_000_000
      ; token = `Token_id Amount_of.Token_id.default
      ; sequence_no = 2
      ; hash = "COMMAND_2"
      ; failure_reasons = [ "Failure1" ]
      ; valid_until = Some (Unsigned.UInt32.of_int 20_000)
      ; nonce = Unsigned.UInt32.of_int 2
      ; memo = None
      ; account_updates = Zkapp_account_update_info.dummies
      }
    ]
end

module Block_info = struct
  (* TODO: should timestamp be string?; Block_time.t is an unsigned 64-bit int *)
  type t =
    { block_identifier : Block_identifier.t
    ; parent_block_identifier : Block_identifier.t
    ; creator : [ `Pk of string ]
    ; winner : [ `Pk of string ]
    ; timestamp : int64
    ; internal_info : Internal_command_info.t list
    ; user_commands : User_command_info.t list
    ; zkapp_commands : Zkapp_command_info.t list
    }

  let creator_metadata { creator = `Pk pk; _ } =
    `Assoc [ ("creator", `String pk) ]

  let block_winner_metadata { winner = `Pk pk; _ } =
    `Assoc [ ("winner", `String pk) ]

  let dummy =
    { block_identifier =
        Block_identifier.create (Int64.of_int_exn 4) "STATE_HASH_BLOCK"
    ; creator = `Pk "Alice"
    ; winner = `Pk "Babu"
    ; parent_block_identifier =
        Block_identifier.create (Int64.of_int_exn 3) "STATE_HASH_PARENT"
    ; timestamp = Int64.of_int_exn 1594937771
    ; internal_info = Internal_command_info.dummies
    ; user_commands = User_command_info.dummies
    ; zkapp_commands = Zkapp_command_info.dummies
    }
end

module Sql = struct
  module Block = struct
    module Extras = struct
      let creator (creator, _) = `Pk creator

      let winner (_, winner) = `Pk winner

      let typ = Caqti_type.(tup2 string string)
    end

    let typ = Caqti_type.(tup3 int Archive_lib.Processor.Block.typ Extras.typ)

    let block_fields ?prefix () =
      let names = Archive_lib.Processor.Block.Fields.names in
      let fields =
        Option.value_map prefix ~default:names ~f:(fun prefix ->
            List.map ~f:(fun n -> prefix ^ n) names )
      in
      String.concat ~sep:"," fields

    let query_count_canonical_at_height =
      Caqti_request.find Caqti_type.int64 Caqti_type.int64
        {sql| SELECT COUNT(*) FROM blocks
              WHERE height = ?
              AND chain_status = 'canonical'
        |sql}

    let query_height_canonical =
      let c_fields = block_fields ~prefix:"c." () in
      Caqti_request.find_opt Caqti_type.int64 typ
        (* The archive database will only reconcile the canonical columns for
         * blocks older than k + epsilon
         *)
        (sprintf
           {|
         SELECT c.id,
                %s,
                pk.value as creator,
                bw.value as winner
         FROM blocks c
         INNER JOIN public_keys pk
           ON pk.id = c.creator_id
         INNER JOIN public_keys bw
           ON bw.id = c.block_winner_id
         WHERE c.height = ?
           AND c.chain_status = 'canonical'
        |}
           c_fields )

    let query_height_pending =
      let fields = block_fields () in
      let b_fields = block_fields ~prefix:"b." () in
      let c_fields = block_fields ~prefix:"c." () in
      Caqti_request.find_opt Caqti_type.int64 typ
        (* According to the clarification of the Rosetta spec here
         * https://community.rosetta-api.org/t/querying-block-by-just-its-index/84/3 ,
         * it is important to select only the block on the canonical chain for a
         * given height, and not an arbitrary one.
         *
         * This query recursively traverses the blockchain from the longest tip
         * backwards until it reaches a block of the given height.
         *
         * This query is best used only for _short_ (around ~k blocks back
         * + epsilon)
         * requests since recursive queries stress PostgreSQL.
         *)
        (sprintf
           {|
         WITH RECURSIVE chain AS (
           (SELECT id, %s
           FROM blocks
           WHERE height = (select MAX(height) from blocks)
           ORDER BY timestamp ASC, state_hash ASC
           LIMIT 1)

         UNION ALL

           SELECT b.id, %s
           FROM blocks b
           INNER JOIN chain
             ON b.id = chain.parent_id
             AND chain.id <> chain.parent_id
             AND chain.chain_status <> 'canonical')

         SELECT c.id,
                %s,
                pk.value as creator,
                bw.value as winner
         FROM chain c
         INNER JOIN public_keys pk
           ON pk.id = c.creator_id
         INNER JOIN public_keys bw
           ON bw.id = c.block_winner_id
         WHERE c.height = ?
       |}
           fields b_fields c_fields )

    let query_hash =
      let b_fields = block_fields ~prefix:"b." () in
      Caqti_request.find_opt Caqti_type.string typ
        (sprintf
           {|
         SELECT b.id,
                %s,
                pk.value as creator,
                bw.value as winner
         FROM blocks b
         INNER JOIN public_keys pk
         ON pk.id = b.creator_id
         INNER JOIN public_keys bw
         ON bw.id = b.block_winner_id
         WHERE b.state_hash = ?
        |}
           b_fields )

    let query_both =
      let b_fields = block_fields ~prefix:"b." () in
      Caqti_request.find_opt
        Caqti_type.(tup2 string int64)
        typ
        (sprintf
           {|
         SELECT b.id,
                %s,
                pk.value as creator,
                bw.value as winner
         FROM blocks b
         INNER JOIN public_keys pk
           ON pk.id = b.creator_id
         INNER JOIN public_keys bw
           ON bw.id = b.block_winner_id
         WHERE b.state_hash = ?
           AND b.height = ?
        |}
           b_fields )

    let query_by_id =
      let b_fields = block_fields ~prefix:"b." () in
      Caqti_request.find_opt Caqti_type.int typ
        (sprintf
           {|
         SELECT b.id,
                %s,
                pk.value as creator,
                bw.value as winner
         FROM blocks b
         INNER JOIN public_keys pk
           ON pk.id = b.creator_id
         INNER JOIN public_keys bw
           ON bw.id = b.block_winner_id
         WHERE b.id = ?
        |}
           b_fields )

    let query_best =
      let b_fields = block_fields ~prefix:"b." () in
      Caqti_request.find_opt Caqti_type.unit typ
        (sprintf
           {|
         SELECT b.id,
                %s,
                pk.value as creator,
                bw.value as winner
         FROM blocks b
         INNER JOIN public_keys pk
           ON pk.id = b.creator_id
         INNER JOIN public_keys bw
           ON bw.id = b.block_winner_id
         WHERE b.height = (select MAX(b.height) from blocks b)
         ORDER BY timestamp ASC, state_hash ASC
         LIMIT 1
        |}
           b_fields )

    let run_by_id (module Conn : Caqti_async.CONNECTION) id =
      Conn.find_opt query_by_id id

    let run_has_canonical_height (module Conn : Caqti_async.CONNECTION) ~height
        =
      let open Deferred.Result.Let_syntax in
      let%map num_canonical_at_height =
        Conn.find query_count_canonical_at_height height
      in
      Int64.( > ) num_canonical_at_height Int64.zero

    let run (module Conn : Caqti_async.CONNECTION) = function
      | Some (`This (`Height h)) ->
          let open Deferred.Result.Let_syntax in
          let%bind has_canonical_height =
            run_has_canonical_height (module Conn) ~height:h
          in
          if has_canonical_height then Conn.find_opt query_height_canonical h
          else
            let%bind max_height =
              Conn.find
                (Caqti_request.find Caqti_type.unit Caqti_type.int64
                   {sql| SELECT MAX(height) FROM blocks |sql} )
                ()
            in
            let max_queryable_height =
              Int64.( - ) max_height Network.Sql.max_height_delta
            in
            if Int64.( <= ) h max_queryable_height then
              Conn.find_opt query_height_pending h
            else return None
      | Some (`That (`Hash h)) ->
          Conn.find_opt query_hash h
      | Some (`Those (`Height height, `Hash hash)) ->
          Conn.find_opt query_both (hash, height)
      | None ->
          Conn.find_opt query_best ()
  end

  module User_commands = struct
    module Extras = struct
      (* TODO: A few of these actually aren't used; should we leave in for future or remove? *)
      type t =
        { fee_payer : string
        ; source : string
        ; receiver : string
        ; status : string option
        ; failure_reason : string option
        ; account_creation_fee_paid : int64 option
        }
      [@@deriving hlist]

      let fee_payer t = `Pk t.fee_payer

      let source t = `Pk t.source

      let receiver t = `Pk t.receiver

      let status t = t.status

      let failure_reason t = t.failure_reason

      let account_creation_fee_paid t = t.account_creation_fee_paid

      let typ =
        Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
          Caqti_type.
            [ string
            ; string
            ; string
            ; option string
            ; option string
            ; option int64
            ]
    end

    let typ =
      Caqti_type.(
        tup3 int Archive_lib.Processor.User_command.Signed_command.typ
          Extras.typ)

    let query =
      let fields =
        String.concat ~sep:","
        @@ List.map
             ~f:(fun n -> "u." ^ n)
             Archive_lib.Processor.User_command.Signed_command.Fields.names
      in
      Caqti_request.collect
        Caqti_type.(tup2 int string)
        typ
        (sprintf
           {|
         SELECT u.id,
                %s,
                pk_payer.value as fee_payer,
                pk_source.value as source,
                pk_receiver.value as receiver,
                buc.status,
                buc.failure_reason,
                ac.creation_fee
         FROM user_commands u
         INNER JOIN blocks_user_commands buc
           ON buc.user_command_id = u.id
         INNER JOIN public_keys pk_payer
           ON pk_payer.id = u.fee_payer_id
         INNER JOIN public_keys pk_source
           ON pk_source.id = u.source_id
         INNER JOIN public_keys pk_receiver
           ON pk_receiver.id = u.receiver_id
         LEFT JOIN account_identifiers ai_receiver
           ON ai_receiver.public_key_id = pk_receiver.id
        /* Account creation fees are attributed to the first successful command in the
           block that mentions the account with the following LEFT JOIN */
         LEFT JOIN accounts_created ac
           ON buc.block_id = ac.block_id
           AND ai_receiver.id = ac.account_identifier_id
           AND buc.status = 'applied'
           AND buc.sequence_no =
             (SELECT LEAST(
                (SELECT min(bic2.sequence_no)
                 FROM blocks_internal_commands bic2
                 INNER JOIN internal_commands ic2
                    ON bic2.internal_command_id = ic2.id
                 WHERE ic2.receiver_id = u.receiver_id
                    AND bic2.block_id = buc.block_id
                    AND bic2.status = 'applied'),
                 (SELECT min(buc2.sequence_no)
                  FROM blocks_user_commands buc2
                  INNER JOIN user_commands uc2
                    ON buc2.user_command_id = uc2.id
                  WHERE uc2.receiver_id = u.receiver_id
                    AND buc2.block_id = buc.block_id
                    AND buc2.status = 'applied')))
         LEFT JOIN tokens t
           ON t.id = ai_receiver.token_id
         WHERE buc.block_id = ?
           AND (t.value = ? OR t.id IS NULL)
        |}
           fields )

    let run (module Conn : Caqti_async.CONNECTION) id =
      Conn.collect_list query (id, Mina_base.Token_id.(to_string default))
  end

  module Internal_commands = struct
    module Extras = struct
      let receiver (_, x, _, _) = `Pk x

      let receiver_account_creation_fee_paid (fee, _, _, _) = fee

      let sequence_no (_, _, seq_no, _) = seq_no

      let secondary_sequence_no (_, _, _, secondary_seq_no) = secondary_seq_no

      let typ = Caqti_type.(tup4 (option int64) string int int)
    end

    let typ =
      Caqti_type.(
        tup3 int Archive_lib.Processor.Internal_command.typ Extras.typ)

    let query =
      let fields =
        String.concat ~sep:","
        @@ List.map
             ~f:(fun n -> "i." ^ n)
             Archive_lib.Processor.Internal_command.Fields.names
      in
      Caqti_request.collect
        Caqti_type.(tup2 int string)
        typ
        (sprintf
           {|
         SELECT DISTINCT ON (i.hash,i.command_type,bic.sequence_no,bic.secondary_sequence_no)
           i.id,
           %s,
           ac.creation_fee,
           pk.value as receiver,
           bic.sequence_no,
           bic.secondary_sequence_no
         FROM internal_commands i
         INNER JOIN blocks_internal_commands bic
           ON bic.internal_command_id = i.id
         INNER JOIN public_keys pk
           ON pk.id = i.receiver_id
         INNER JOIN account_identifiers ai
           ON ai.public_key_id = receiver_id
         LEFT JOIN accounts_created ac
           ON ac.account_identifier_id = ai.id
           AND ac.block_id = bic.block_id
           AND bic.sequence_no =
               (SELECT LEAST(
                   (SELECT min(bic2.sequence_no)
                    FROM blocks_internal_commands bic2
                    INNER JOIN internal_commands ic2
                       ON bic2.internal_command_id = ic2.id
                    WHERE ic2.receiver_id = i.receiver_id
                       AND bic2.block_id = bic.block_id
                       AND bic2.status = 'applied'),
                    (SELECT min(buc2.sequence_no)
                     FROM blocks_user_commands buc2
                     INNER JOIN user_commands uc2
                       ON buc2.user_command_id = uc2.id
                     WHERE uc2.receiver_id = i.receiver_id
                       AND buc2.block_id = bic.block_id
                       AND buc2.status = 'applied')))
         INNER JOIN tokens t
           ON t.id = ai.token_id
         WHERE bic.block_id = ?
          AND t.value = ?
      |}
           fields )

    let run (module Conn : Caqti_async.CONNECTION) id =
      Conn.collect_list query (id, Mina_base.Token_id.(to_string default))
  end

  module Zkapp_commands = struct
    module Extras = struct
      type t =
        { memo : string
        ; hash : string
        ; fee_payer : string
        ; fee : string
        ; valid_until : int64 option
        ; nonce : int64
        ; sequence_no : int
        ; status : string
        ; failure_reasons : string array option
        }
      [@@deriving hlist]

      let memo t = t.memo

      let hash t = t.hash

      let fee_payer t = `Pk t.fee_payer

      let fee t = t.fee

      let typ =
        Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
          Caqti_type.
            [ string
            ; string
            ; string
            ; string
            ; option int64
            ; int64
            ; int
            ; string
            ; option Mina_caqti.array_string_typ
            ]
    end

    let typ = Caqti_type.(tup2 int Extras.typ)

    let query =
      Caqti_request.collect Caqti_type.int typ
        {| 
         SELECT zc.id,
                zc.memo,
                zc.hash,
                pk_fee_payer.value as fee_payer,
                zfpb.fee,
                zfpb.valid_until,
                zfpb.nonce,
                bzc.sequence_no,
                bzc.status,
                array(SELECT unnest(zauf.failures)
                      FROM zkapp_account_update_failures zauf
                      WHERE zauf.id = ANY (bzc.failure_reasons_ids))
         FROM blocks_zkapp_commands bzc
         INNER JOIN zkapp_commands zc
           ON zc.id = bzc.zkapp_command_id
         INNER JOIN zkapp_fee_payer_body zfpb
           ON zc.zkapp_fee_payer_body_id = zfpb.id
         INNER JOIN public_keys pk_fee_payer
           ON zfpb.public_key_id = pk_fee_payer.id
         WHERE bzc.block_id = ?
      |}

    let run (module Conn : Caqti_async.CONNECTION) id =
      Conn.collect_list query id
  end

  module Zkapp_account_update = struct
    module Extras = struct
      type t = { account : string; status : string } [@@deriving hlist]

      let account t = `Pk t.account

      let typ =
        Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
          Caqti_type.[ string; string ]
    end

    let typ =
      Caqti_type.(
        tup2 Archive_lib.Processor.Zkapp_account_update_body.typ Extras.typ)

    let query =
      let fields =
        String.concat ~sep:","
        @@ List.map
             ~f:(fun n -> "zaub." ^ n)
             Archive_lib.Processor.Zkapp_account_update_body.Fields.names
      in
      Caqti_request.collect
        Caqti_type.(tup3 int string int)
        typ
        (sprintf
           {|
         SELECT %s,
                pk.value as account,
                bzc.status
         FROM zkapp_commands zc
         INNER JOIN blocks_zkapp_commands bzc
           ON bzc.zkapp_command_id = zc.id
         INNER JOIN zkapp_account_update zau
           ON zau.id = ANY(zc.zkapp_account_updates_ids)
         INNER JOIN zkapp_account_update_body zaub
           ON zaub.id = zau.body_id
         INNER JOIN account_identifiers ai
           ON ai.id = zaub.account_identifier_id
         INNER JOIN public_keys pk
           ON ai.public_key_id = pk.id
         INNER JOIN tokens t
           ON t.id = ai.token_id
         WHERE zc.id = ?
           AND t.value = ?
           AND bzc.block_id = ?
    |}
           fields )

    let run (module Conn : Caqti_async.CONNECTION) command_id block_id =
      Conn.collect_list query
        (command_id, Mina_base.Token_id.(to_string default), block_id)
  end

  let run (module Conn : Caqti_async.CONNECTION) input =
    let module M = struct
      include Deferred.Result

      module List = struct
        let map ~f =
          List.fold ~init:(return []) ~f:(fun acc x ->
              let open Let_syntax in
              let%bind xs = acc in
              let%map y = f x in
              y :: xs )
      end
    end in
    let open M.Let_syntax in
    let%bind block_id, raw_block, block_extras =
      match%bind
        Block.run (module Conn) input
        |> Errors.Lift.sql ~context:"Finding block"
      with
      | None ->
          M.fail (Errors.create @@ `Block_missing (Block_query.to_string input))
      | Some (block_id, raw_block, block_extras) ->
          M.return (block_id, raw_block, block_extras)
    in
    let%bind raw_parent_block =
      (* if parent_id is null, this means this is the chain genesis block and
         the block is its own parent *)
      Option.value_map raw_block.parent_id ~default:(M.return raw_block)
        ~f:(fun parent_id ->
          match%bind
            Block.run_by_id (module Conn) parent_id
            |> Errors.Lift.sql ~context:"Finding parent block"
          with
          | None ->
              M.fail
                ( Errors.create ~context:"Parent block"
                @@ `Block_missing (sprintf "parent_id = %d" parent_id) )
          | Some (_, raw_parent_block, _) ->
              M.return raw_parent_block )
    in
    let%bind raw_user_commands =
      User_commands.run (module Conn) block_id
      |> Errors.Lift.sql ~context:"Finding user commands within block"
    in
    let%bind raw_internal_commands =
      Internal_commands.run (module Conn) block_id
      |> Errors.Lift.sql ~context:"Finding internal commands within block"
    in
    let%bind raw_zkapp_commands =
      Zkapp_commands.run (module Conn) block_id
      |> Errors.Lift.sql ~context:"Finding zkapp commands within block"
    in
    let%bind internal_commands =
      M.List.map raw_internal_commands ~f:(fun (_, ic, extras) ->
          let%map kind =
            match ic.Archive_lib.Processor.Internal_command.command_type with
            | "fee_transfer" ->
                M.return `Fee_transfer
            | "coinbase" ->
                M.return `Coinbase
            | "fee_transfer_via_coinbase" ->
                M.return `Fee_transfer_via_coinbase
            | other ->
                M.fail
                  (Errors.create
                     ~context:
                       (sprintf
                          "The archive database is storing internal commands \
                           with %s; this is neither fee_transfer nor coinbase \
                           not fee_transfer_via_coinbase. Please report a bug!"
                          other )
                     `Invariant_violation )
          in
          (* internal commands always use the default token *)
          let token_id = Mina_base.Token_id.(to_string default) in
          { Internal_command_info.kind
          ; receiver = Internal_commands.Extras.receiver extras
          ; receiver_account_creation_fee_paid =
              Option.map
                (Internal_commands.Extras.receiver_account_creation_fee_paid
                   extras )
                ~f:Unsigned.UInt64.of_int64
          ; fee = Unsigned.UInt64.of_string ic.fee
          ; token = `Token_id token_id
          ; sequence_no = Internal_commands.Extras.sequence_no extras
          ; secondary_sequence_no =
              Internal_commands.Extras.secondary_sequence_no extras
          ; hash = ic.hash
          } )
    in
    let%bind user_commands =
      M.List.map raw_user_commands ~f:(fun (_, uc, extras) ->
          let open M.Let_syntax in
          let%bind kind =
            match
              uc.Archive_lib.Processor.User_command.Signed_command.command_type
            with
            | "payment" ->
                M.return `Payment
            | "delegation" ->
                M.return `Delegation
            | other ->
                M.fail
                  (Errors.create
                     ~context:
                       (sprintf
                          "The archive database is storing user commands with \
                           %s; this is not a known type. Please report a bug!"
                          other )
                     `Invariant_violation )
          in
          (* TODO: do we want to mention tokens at all here? *)
          let fee_token = Mina_base.Token_id.(to_string default) in
          let token = Mina_base.Token_id.(to_string default) in
          let%map failure_status =
            match User_commands.Extras.failure_reason extras with
            | None -> (
                match User_commands.Extras.account_creation_fee_paid extras with
                | None ->
                    M.return
                    @@ `Applied
                         User_command_info.Account_creation_fees_paid.By_no_one
                | Some receiver ->
                    M.return
                    @@ `Applied
                         (User_command_info.Account_creation_fees_paid
                          .By_receiver
                            (Unsigned.UInt64.of_int64 receiver) ) )
            | Some status ->
                M.return @@ `Failed status
          in
          { User_command_info.kind
          ; fee_payer = User_commands.Extras.fee_payer extras
          ; source = User_commands.Extras.source extras
          ; receiver = User_commands.Extras.receiver extras
          ; fee_token = `Token_id fee_token
          ; token = `Token_id token
          ; nonce = Unsigned.UInt32.of_int64 uc.nonce
          ; amount = Option.map ~f:Unsigned.UInt64.of_string uc.amount
          ; fee = Unsigned.UInt64.of_string uc.fee
          ; hash = uc.hash
          ; failure_status = Some failure_status
          ; valid_until = Option.map ~f:Unsigned.UInt32.of_int64 uc.valid_until
          ; memo = (if String.equal uc.memo "" then None else Some uc.memo)
          } )
    in
    let%map zkapp_commands =
      M.List.map raw_zkapp_commands ~f:(fun (cmd_id, cmd) ->
          (* TODO: check if this holds *)
          let token = Mina_base.Token_id.(to_string default) in
          let%bind raw_zkapp_account_update =
            Zkapp_account_update.run (module Conn) cmd_id block_id
            |> Errors.Lift.sql
                 ~context:"Finding zkapp account updates within command"
          in
          let%map account_updates =
            M.List.map raw_zkapp_account_update ~f:(fun (upd, extras) ->
                (* TODO: check if this holds *)
                let token = Mina_base.Token_id.(to_string default) in
                let status =
                  match extras.Zkapp_account_update.Extras.status with
                  | "applied" ->
                      `Success
                  | _ ->
                      `Failed
                in
                M.return
                  { Zkapp_account_update_info.authorization_kind =
                      upd
                        .Archive_lib.Processor.Zkapp_account_update_body
                         .authorization_kind
                  ; account = Zkapp_account_update.Extras.account extras
                  ; balance_change = upd.balance_change
                  ; increment_nonce = upd.increment_nonce
                  ; may_use_token = upd.may_use_token
                  ; call_depth = Unsigned.UInt64.of_int upd.call_depth
                  ; use_full_commitment = upd.use_full_commitment
                  ; status
                  ; token = `Token_id token
                  } )
          in
          { Zkapp_command_info.fee =
              Unsigned.UInt64.of_string @@ Zkapp_commands.Extras.fee cmd
          ; fee_payer = Zkapp_commands.Extras.fee_payer cmd
          ; valid_until = Option.map ~f:Unsigned.UInt32.of_int64 cmd.valid_until
          ; nonce = Unsigned.UInt32.of_int64 cmd.nonce
          ; token = `Token_id token
          ; sequence_no = cmd.sequence_no
          ; memo = (if String.equal cmd.memo "" then None else Some cmd.memo)
          ; hash = cmd.hash
          ; failure_reasons =
              Option.value_map ~default:[] ~f:Array.to_list cmd.failure_reasons
          ; account_updates
          } )
    in
    { Block_info.block_identifier =
        { Block_identifier.index = raw_block.height
        ; hash = raw_block.state_hash
        }
    ; creator = Block.Extras.creator block_extras
    ; winner = Block.Extras.winner block_extras
    ; parent_block_identifier =
        { Block_identifier.index = raw_parent_block.height
        ; hash = raw_parent_block.state_hash
        }
    ; timestamp = Int64.of_string raw_block.timestamp
    ; internal_info = internal_commands
    ; user_commands
    ; zkapp_commands
    }
end

module Specific = struct
  module Env = struct
    (* All side-effects go in the env so we can mock them out later *)
    module T (M : Monad_fail.S) = struct
      type 'gql t =
        { logger : Logger.t
        ; db_block : Block_query.t -> (Block_info.t, Errors.t) M.t
        ; validate_network_choice :
               network_identifier:Network_identifier.t
            -> graphql_uri:Uri.t
            -> (unit, Errors.t) M.t
        }
    end

    (* The real environment does things asynchronously *)
    module Real = T (Deferred.Result)

    (* But for tests, we want things to go fast *)
    module Mock = T (Result)

    let real :
        logger:Logger.t -> db:(module Caqti_async.CONNECTION) -> 'gql Real.t =
     fun ~logger ~db ->
      { logger
      ; db_block =
          (fun query ->
            let (module Conn : Caqti_async.CONNECTION) = db in
            Sql.run (module Conn) query )
      ; validate_network_choice = Network.Validate_choice.Real.validate
      }

    let mock : logger:Logger.t -> 'gql Mock.t =
     fun ~logger ->
      { logger
      ; db_block = (fun _query -> Result.return @@ Block_info.dummy)
      ; validate_network_choice = Network.Validate_choice.Mock.succeed
      }
  end

  module Impl (M : Monad_fail.S) = struct
    module Query = Block_query.T (M)
    module Internal_command_info_ops = Internal_command_info.T (M)
    module Zkapp_command_info_ops = Zkapp_command_info.T (M)

    let handle :
           graphql_uri:Uri.t
        -> env:'gql Env.T(M).t
        -> Block_request.t
        -> (Block_response.t, Errors.t) M.t =
     fun ~graphql_uri ~env req ->
      let open M.Let_syntax in
      let logger = env.logger in
      let%bind query = Query.of_partial_identifier req.block_identifier in
      let%bind () =
        env.validate_network_choice ~network_identifier:req.network_identifier
          ~graphql_uri
      in
      let%bind block_info = env.db_block query in
      let coinbase_receiver =
        List.find block_info.internal_info ~f:(fun info ->
            Internal_command_info.Kind.equal info.Internal_command_info.kind
              `Coinbase )
        |> Option.map ~f:(fun cmd -> cmd.Internal_command_info.receiver)
      in
      let%bind internal_transactions =
        List.fold block_info.internal_info ~init:(M.return [])
          ~f:(fun macc info ->
            let%bind acc = macc in
            let%map operations =
              Internal_command_info_ops.to_operations ~coinbase_receiver info
            in
            [%log debug]
              ~metadata:[ ("info", Internal_command_info.to_yojson info) ]
              "Block internal received $info" ;
            { Transaction.transaction_identifier =
                (* prepend the sequence number, secondary sequence number and kind to the transaction hash
                   duplicate hashes are possible in the archive database, with differing
                   "type" fields, which correspond to the "kind" here
                *)
                { Transaction_identifier.hash =
                    sprintf "%s:%s:%s:%s"
                      (Internal_command_info.Kind.to_string info.kind)
                      (Int.to_string info.sequence_no)
                      (Int.to_string info.secondary_sequence_no)
                      info.hash
                }
            ; operations
            ; metadata = None
            ; related_transactions = []
            }
            :: acc )
        |> M.map ~f:List.rev
      in
      let%map zkapp_command_transactions =
        List.fold block_info.zkapp_commands ~init:(M.return [])
          ~f:(fun acc cmd ->
            let%bind acc = acc in
            let%map operations = Zkapp_command_info_ops.to_operations cmd in
            [%log debug]
              ~metadata:[ ("info", Zkapp_command_info.to_yojson cmd) ]
              "Block zkapp received $info" ;
            { Transaction.transaction_identifier =
                { Transaction_identifier.hash = cmd.hash }
            ; operations
            ; metadata = None
            ; related_transactions = []
            }
            :: acc )
        |> M.map ~f:List.rev
      in
      { Block_response.block =
          Some
            { Block.block_identifier = block_info.block_identifier
            ; parent_block_identifier = block_info.parent_block_identifier
            ; timestamp = block_info.timestamp
            ; transactions =
                internal_transactions
                @ List.map block_info.user_commands ~f:(fun info ->
                      [%log debug]
                        ~metadata:[ ("info", User_command_info.to_yojson info) ]
                        "Block user received $info" ;
                      { Transaction.transaction_identifier =
                          { Transaction_identifier.hash = info.hash }
                      ; operations = User_command_info.to_operations' info
                      ; metadata =
                          Option.bind info.memo ~f:(fun base58_check ->
                              try
                                let memo =
                                  let open Mina_base.Signed_command_memo in
                                  base58_check |> of_base58_check_exn
                                  |> to_string_hum
                                in
                                if String.is_empty memo then None
                                else Some (`Assoc [ ("memo", `String memo) ])
                              with _ -> None )
                      ; related_transactions = []
                      } )
                @ zkapp_command_transactions
            ; metadata = Some (Block_info.creator_metadata block_info)
            }
      ; other_transactions = []
      }
  end

  module Real = Impl (Deferred.Result)

  let%test_module "blocks" =
    ( module struct
      module Mock = Impl (Result)

      (* This test intentionally fails as there has not been time to implement
       * it properly yet *)
      (*
      let%test_unit "all dummies" =
        Test.assert_ ~f:Block_response.to_yojson
          ~expected:
            (Mock.handle ~env:Env.mock
               (Block_request.create
                  (Network_identifier.create "x" "y")
                  (Partial_block_identifier.create ())))
          ~actual:(Result.fail (Errors.create (`Json_parse None)))
    *)
    end )
end

let router ~graphql_uri ~logger ~with_db (route : string list) body =
  let open Async.Deferred.Result.Let_syntax in
  [%log debug] "Handling /block/ $route"
    ~metadata:[ ("route", `List (List.map route ~f:(fun s -> `String s))) ] ;
  [%log info] "Block query" ~metadata:[ ("query", body) ] ;
  match route with
  | [] | [ "" ] ->
      with_db (fun ~db ->
          let%bind req =
            Errors.Lift.parse ~context:"Request" @@ Block_request.of_yojson body
            |> Errors.Lift.wrap
          in
          let%map res =
            Specific.Real.handle ~graphql_uri
              ~env:(Specific.Env.real ~logger ~db)
              req
            |> Errors.Lift.wrap
          in
          Block_response.to_yojson res )
  (* Note: We do not need to implement /block/transaction endpoint because we
   * don't return any "other_transactions" *)
  | _ ->
      Deferred.Result.fail `Page_not_found
