open Core_kernel
open Async
open Rosetta_lib
open Rosetta_models

module Block = struct
  module Extras = struct
    let creator (creator, _) = `Pk creator

    let winner (_, winner) = `Pk winner

    let typ = Caqti_type.(tup2 string string)
  end

  let typ = Caqti_type.(tup3 int Archive_lib.Processor.Block.typ Extras.typ)

  let query_count_canonical_at_height =
    Caqti_request.find Caqti_type.int64 Caqti_type.int64
      {sql| SELECT COUNT(*) FROM blocks
              WHERE height = ?
              AND chain_status = 'canonical'
        |sql}

  let query_height_canonical =
    Caqti_request.find_opt Caqti_type.int64 typ
      (* The archive database will only reconcile the canonical columns for
       * blocks older than k + epsilon
       *)
      {|
SELECT c.id, c.state_hash, c.parent_id, c.parent_hash, c.creator_id, c.block_winner_id, c.snarked_ledger_hash_id, c.staking_epoch_data_id, c.next_epoch_data_id, c.min_window_density, c.total_currency, c.ledger_hash, c.height, c.global_slot_since_hard_fork, c.global_slot_since_genesis, c.timestamp, c.chain_status, pk.value as creator, bw.value as winner FROM blocks c
  INNER JOIN public_keys pk
  ON pk.id = c.creator_id
  INNER JOIN public_keys bw
  ON bw.id = c.block_winner_id
  WHERE c.height = ? AND c.chain_status = 'canonical'
      |}

  let query_height_pending =
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
      {|
WITH RECURSIVE chain AS (
  (SELECT id, state_hash, parent_id, parent_hash, creator_id, block_winner_id, snarked_ledger_hash_id, staking_epoch_data_id, next_epoch_data_id, min_window_density, total_currency, ledger_hash, height, global_slot_since_hard_fork, global_slot_since_genesis, timestamp, chain_status FROM blocks b WHERE height = (select MAX(height) from blocks)
  ORDER BY timestamp ASC, state_hash ASC
  LIMIT 1)

  UNION ALL

  SELECT b.id, b.state_hash, b.parent_id, b.parent_hash, b.creator_id, b.block_winner_id, b.snarked_ledger_hash_id, b.staking_epoch_data_id, b.next_epoch_data_id, b.min_window_density, b.total_currency, b.ledger_hash, b.height, b.global_slot_since_hard_fork, b.global_slot_since_genesis, b.timestamp, b.chain_status FROM blocks b
  INNER JOIN chain
  ON b.id = chain.parent_id AND chain.id <> chain.parent_id AND chain.chain_status <> 'canonical'
) SELECT c.id, c.state_hash, c.parent_id, c.parent_hash, c.creator_id, c.block_winner_id, c.snarked_ledger_hash_id, c.staking_epoch_data_id, c.next_epoch_data_id, c.min_window_density, c.total_currency, c.ledger_hash, c.height, c.global_slot_since_hard_fork, c.global_slot_since_genesis, c.timestamp, c.chain_status, pk.value as creator, bw.value as winner FROM chain c
  INNER JOIN public_keys pk
  ON pk.id = c.creator_id
  INNER JOIN public_keys bw
  ON bw.id = c.block_winner_id
  WHERE c.height = ?
      |}

  let query_hash =
    Caqti_request.find_opt Caqti_type.string typ
      {| SELECT b.id, b.state_hash, b.parent_id, b.parent_hash, b.creator_id, b.block_winner_id, b.snarked_ledger_hash_id, b.staking_epoch_data_id, b.next_epoch_data_id, b.min_window_density, b.total_currency, b.ledger_hash, b.height, b.global_slot_since_hard_fork, b.global_slot_since_genesis, b.timestamp, b.chain_status, pk.value as creator, bw.value as winner FROM blocks b
        INNER JOIN public_keys pk
        ON pk.id = b.creator_id
        INNER JOIN public_keys bw
        ON bw.id = b.block_winner_id
        WHERE b.state_hash = ? |}

  let query_both =
    Caqti_request.find_opt
      Caqti_type.(tup2 string int64)
      typ
      {| SELECT b.id, b.state_hash, b.parent_id, b.parent_hash, b.creator_id, b.block_winner_id, b.snarked_ledger_hash_id, b.staking_epoch_data_id, b.next_epoch_data_id, b.min_window_density, b.total_currency, b.ledger_hash, b.height, b.global_slot_since_hard_fork, b.global_slot_since_genesis, b.timestamp, b.chain_status, pk.value as creator, bw.value as winner FROM blocks b
        INNER JOIN public_keys pk
        ON pk.id = b.creator_id
        INNER JOIN public_keys bw
        ON bw.id = b.block_winner_id
        WHERE b.state_hash = ? AND b.height = ? |}

  let query_by_id =
    Caqti_request.find_opt Caqti_type.int typ
      {| SELECT b.id, b.state_hash, b.parent_id, b.parent_hash, b.creator_id, b.block_winner_id, b.snarked_ledger_hash_id, b.staking_epoch_data_id, b.next_epoch_data_id, b.min_window_density, b.total_currency, b.ledger_hash, b.height, b.global_slot_since_hard_fork, b.global_slot_since_genesis, b.timestamp, b.chain_status, pk.value as creator, bw.value as winner FROM blocks b
        INNER JOIN public_keys pk
        ON pk.id = b.creator_id
        INNER JOIN public_keys bw
        ON bw.id = b.block_winner_id
        WHERE b.id = ? |}

  let query_best =
    Caqti_request.find_opt Caqti_type.unit typ
      {| SELECT b.id, b.state_hash, b.parent_id, b.parent_hash, b.creator_id, b.block_winner_id, b.snarked_ledger_hash_id, b.staking_epoch_data_id, b.next_epoch_data_id, b.min_window_density, b.total_currency, b.ledger_hash, b.height, b.global_slot_since_hard_fork, b.global_slot_since_genesis, b.timestamp, b.chain_status, pk.value as creator, bw.value as winner FROM blocks b
           INNER JOIN public_keys pk
           ON pk.id = b.creator_id
           INNER JOIN public_keys bw
           ON bw.id = b.block_winner_id
           WHERE b.height = (select MAX(b.height) from blocks b)
           ORDER BY timestamp ASC, state_hash ASC
           LIMIT 1 |}

  let run_by_id (module Conn : Caqti_async.CONNECTION) id =
    Conn.find_opt query_by_id id

  let run_has_canonical_height (module Conn : Caqti_async.CONNECTION) ~height =
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
          [ string; string; string; option string; option string; option int64 ]
  end

  let typ =
    Caqti_type.(
      tup3 int Archive_lib.Processor.User_command.Signed_command.typ Extras.typ)

  let query =
    Caqti_request.collect Caqti_type.int typ
      {| SELECT u.id, u.command_type, u.fee_payer_id, u.source_id, u.receiver_id, u.nonce, u.amount, u.fee,
        u.valid_until, u.memo, u.hash,
        pk_payer.value as fee_payer, pk_source.value as source, pk_receiver.value as receiver,
        buc.status,
        buc.failure_reason,
        ac.creation_fee
        FROM user_commands u
        INNER JOIN blocks_user_commands buc ON buc.user_command_id = u.id
        INNER JOIN account_identifiers ai_payer on ai_payer.id = u.fee_payer_id
        INNER JOIN public_keys pk_payer ON pk_payer.id = ai_payer.public_key_id
        INNER JOIN account_identifiers ai_source on ai_source.id = u.source_id
        INNER JOIN public_keys pk_source ON pk_source.id = ai_source.public_key_id
        INNER JOIN account_identifiers ai_receiver on ai_receiver.id = u.receiver_id
        INNER JOIN public_keys pk_receiver ON pk_receiver.id = ai_receiver.public_key_id
        /* Account creation fees are attributed to the first successful command in the
           block that mentions the account with the following LEFT JOIN */
        LEFT JOIN accounts_created ac
            ON buc.block_id = ac.block_id
                   AND u.receiver_id = ac.account_identifier_id
                   AND buc.status = 'applied'
                   AND buc.sequence_no =
                       (SELECT MIN(buc2.sequence_no)
                        FROM blocks_user_commands buc2
                            INNER JOIN user_commands uc2 on buc2.user_command_id = uc2.id
                                   AND uc2.receiver_id = ac.account_identifier_id
                                   AND buc2.block_id = buc.block_id)
        WHERE buc.block_id = ?
      |}

  let run (module Conn : Caqti_async.CONNECTION) id = Conn.collect_list query id
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
    Caqti_type.(tup3 int Archive_lib.Processor.Internal_command.typ Extras.typ)

  let query =
    Caqti_request.collect Caqti_type.int typ
      {| SELECT DISTINCT ON (i.hash,i.command_type,bic.sequence_no,bic.secondary_sequence_no) i.id, i.command_type, i.receiver_id, i.fee, i.hash,
            ac.creation_fee, pk.value as receiver,
            bic.sequence_no, bic.secondary_sequence_no
        FROM internal_commands i
        INNER JOIN blocks_internal_commands bic ON bic.internal_command_id = i.id
        INNER JOIN account_identifiers ai on ai.id = i.receiver_id
        INNER JOIN accounts_created ac on ac.account_identifier_id = ai.id
        INNER JOIN public_keys pk ON pk.id = ai.public_key_id
        WHERE bic.block_id = ?
      |}

  let run (module Conn : Caqti_async.CONNECTION) id = Conn.collect_list query id
end

module Zkapp_commands = struct
  module Extras = struct
    (* TODO: A few of these actually aren't used; should we leave in for future or remove? *)
    type t =
      { account_pk : string
      ; status : string option
      ; failure_reason : string option
      ; account_creation_fee_paid : int64 option
      }
    [@@deriving hlist]

    let account_pk t = `Pk t.account_pk

    let status t = t.status

    let failure_reason t = t.failure_reason

    let account_creation_fee_paid t = t.account_creation_fee_paid

    let typ =
      Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
        Caqti_type.[ string; option string; option string; option int64 ]
  end

  let typ =
    Caqti_type.(
      tup3 int Archive_lib.Processor.User_command.Zkapp_command.typ Extras.typ)

  let query = Caqti_request.collect Caqti_type.int typ {| 
      |}

  let run (module Conn : Caqti_async.CONNECTION) id = Conn.collect_list query id
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
      Block.run (module Conn) input |> Errors.Lift.sql ~context:"Finding block"
    with
    | None ->
        M.fail (Errors.create @@ `Block_missing (Block_query.to_string input))
    | Some (block_id, raw_block, block_extras) ->
        M.return (block_id, raw_block, block_extras)
  in
  let%bind parent_id =
    Option.value_map raw_block.parent_id
      ~default:
        (M.fail
           ( Errors.create
           @@ `Block_missing
                (sprintf "parent block of: %s" (Block_query.to_string input)) ) )
      ~f:M.return
  in
  let%bind raw_parent_block, _parent_block_extras =
    match%bind
      Block.run_by_id (module Conn) parent_id
      |> Errors.Lift.sql ~context:"Finding parent block"
    with
    | None ->
        M.fail
          ( Errors.create ~context:"Parent block"
          @@ `Block_missing (sprintf "parent_id = %d" parent_id) )
    | Some (_, raw_parent_block, parent_block_extras) ->
        M.return (raw_parent_block, parent_block_extras)
  in
  let%bind raw_user_commands =
    User_commands.run (module Conn) block_id
    |> Errors.Lift.sql ~context:"Finding user commands within block"
  in
  let%bind raw_internal_commands =
    Internal_commands.run (module Conn) block_id
    |> Errors.Lift.sql ~context:"Finding internal commands within block"
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
  let%map user_commands =
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
                       (User_command_info.Account_creation_fees_paid.By_receiver
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
  let%map zkapp_commands = M.return Zkapp_command_info.dummies (*TODO: *) in
  let%map zkapps_account_updates =
    M.return Zkapp_account_update_info.dummies
    (*TODO: *)
  in
  { Block_info.block_identifier =
      { Block_identifier.index = raw_block.height; hash = raw_block.state_hash }
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
  ; zkapps_account_updates
  }
