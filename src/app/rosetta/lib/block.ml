open Core_kernel
open Async
module Mina_currency = Currency
open Rosetta_lib
open Rosetta_models
open Commands_common

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
      type t = { creator : string; winner : string } [@@deriving hlist]

      let creator { creator; _ } = `Pk creator

      let winner { winner; _ } = `Pk winner

      let typ =
        Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
          Caqti_type.[ string; string ]
    end

    type t =
      { block_id : int
      ; raw_block : Archive_lib.Processor.Block.t
      ; block_extras : Extras.t
      }
    [@@deriving hlist]

    let typ =
      Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
        Caqti_type.[ int; Archive_lib.Processor.Block.typ; Extras.typ ]

    let block_fields ?prefix () =
      let names = Archive_lib.Processor.Block.Fields.names in
      let fields =
        Option.value_map prefix ~default:names ~f:(fun prefix ->
            List.map ~f:(fun n -> prefix ^ n) names )
      in
      String.concat ~sep:"," fields

    let query_count_canonical_at_height =
      Mina_caqti.find_req Caqti_type.int64 Caqti_type.int64
        {sql| SELECT COUNT(*) FROM blocks
              WHERE height = ?
              AND chain_status = 'canonical'
        |sql}

    let query_height_canonical =
      let c_fields = block_fields ~prefix:"c." () in
      Mina_caqti.find_opt_req Caqti_type.int64 typ
        (* The archive database will only reconcile the canonical columns for
         * blocks older than k + epsilon
         *)
        [%string
          {|
         SELECT c.id,
                %{c_fields},
                pk.value as creator,
                bw.value as winner
         FROM blocks c
         INNER JOIN public_keys pk
           ON pk.id = c.creator_id
         INNER JOIN public_keys bw
           ON bw.id = c.block_winner_id
         WHERE c.height = ?
           AND c.chain_status = 'canonical'
        |}]

    let query_height_pending =
      let fields = block_fields () in
      let b_fields = block_fields ~prefix:"b." () in
      let c_fields = block_fields ~prefix:"c." () in
      Mina_caqti.find_opt_req Caqti_type.int64 typ
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
        [%string
          {|
         WITH RECURSIVE chain AS (
           (SELECT id, %{fields}
           FROM blocks
           WHERE height = (select MAX(height) from blocks)
           ORDER BY timestamp ASC, state_hash ASC
           LIMIT 1)

         UNION ALL

           SELECT b.id, %{b_fields}
           FROM blocks b
           INNER JOIN chain
             ON b.id = chain.parent_id
             AND chain.id <> chain.parent_id
             AND chain.chain_status <> 'canonical')

         SELECT c.id,
                %{c_fields},
                pk.value as creator,
                bw.value as winner
         FROM chain c
         INNER JOIN public_keys pk
           ON pk.id = c.creator_id
         INNER JOIN public_keys bw
           ON bw.id = c.block_winner_id
         WHERE c.height = ?
       |}]

    let query_hash =
      let b_fields = block_fields ~prefix:"b." () in
      Mina_caqti.find_opt_req Caqti_type.string typ
        [%string
          {|
         SELECT b.id,
                %{b_fields},
                pk.value as creator,
                bw.value as winner
         FROM blocks b
         INNER JOIN public_keys pk
         ON pk.id = b.creator_id
         INNER JOIN public_keys bw
         ON bw.id = b.block_winner_id
         WHERE b.state_hash = ?
        |}]

    let query_both =
      let b_fields = block_fields ~prefix:"b." () in
      Mina_caqti.find_opt_req
        Caqti_type.(t2 string int64)
        typ
        [%string
          {|
         SELECT b.id,
                %{b_fields},
                pk.value as creator,
                bw.value as winner
         FROM blocks b
         INNER JOIN public_keys pk
           ON pk.id = b.creator_id
         INNER JOIN public_keys bw
           ON bw.id = b.block_winner_id
         WHERE b.state_hash = ?
           AND b.height = ?
        |}]

    let query_by_id =
      let b_fields = block_fields ~prefix:"b." () in
      Mina_caqti.find_opt_req Caqti_type.int typ
        [%string
          {|
         SELECT b.id,
                %{b_fields},
                pk.value as creator,
                bw.value as winner
         FROM blocks b
         INNER JOIN public_keys pk
           ON pk.id = b.creator_id
         INNER JOIN public_keys bw
           ON bw.id = b.block_winner_id
         WHERE b.id = ?
        |}]

    let query_best =
      let b_fields = block_fields ~prefix:"b." () in
      Mina_caqti.find_opt_req Caqti_type.unit typ
        [%string
          {|
         SELECT b.id,
                %{b_fields},
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
        |}]

    let run_by_id (module Conn : Mina_caqti.CONNECTION) id =
      Conn.find_opt query_by_id id

    let run_has_canonical_height (module Conn : Mina_caqti.CONNECTION) ~height =
      let open Deferred.Result.Let_syntax in
      let%map num_canonical_at_height =
        Conn.find query_count_canonical_at_height height
      in
      Int64.( > ) num_canonical_at_height Int64.zero

    let run (module Conn : Mina_caqti.CONNECTION) = function
      | Some (`This (`Height h)) ->
          let open Deferred.Result.Let_syntax in
          let%bind has_canonical_height =
            run_has_canonical_height (module Conn) ~height:h
          in
          if has_canonical_height then Conn.find_opt query_height_canonical h
          else
            let%bind max_height =
              Conn.find
                (Mina_caqti.find_req Caqti_type.unit Caqti_type.int64
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
      [@@deriving hlist, fields]

      let fee_payer t = `Pk t.fee_payer

      let source t = `Pk t.source

      let receiver t = `Pk t.receiver

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
        t3 int Archive_lib.Processor.User_command.Signed_command.typ Extras.typ)

    let fields =
      String.concat ~sep:","
      @@ List.map
           ~f:(fun n -> "u." ^ n)
           Archive_lib.Processor.User_command.Signed_command.Fields.names

    let query =
      Mina_caqti.collect_req
        Caqti_type.(t2 int string)
        typ
        [%string
          {|
         SELECT u.id,
                %{fields},
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
        |}]

    let run (module Conn : Mina_caqti.CONNECTION) id =
      Conn.collect_list query (id, Mina_base.Token_id.(to_string default))
  end

  module Internal_commands = struct
    module Cte = struct
      type t =
        { internal_command_id : int
        ; raw_internal_command : Archive_lib.Processor.Internal_command.t
        ; receiver_account_creation_fee_paid : int64 option
        ; receiver : string
        ; sequence_no : int
        ; secondary_sequence_no : int
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
          ; "ac.creation_fee"
          ; "pk.value as receiver"
          ; "bic.sequence_no"
          ; "bic.secondary_sequence_no"
          ]

      let receiver t = `Pk t.receiver

      let typ =
        Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
          Caqti_type.
            [ int
            ; Archive_lib.Processor.Internal_command.typ
            ; option int64
            ; string
            ; int
            ; int
            ]

      let query =
        [%string
          {|
         SELECT DISTINCT ON (i.hash,i.command_type,bic.sequence_no,bic.secondary_sequence_no)
           %{fields}
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
      |}]

      let to_info ~coinbase_receiver ({ raw_internal_command = ic; _ } as t) =
        let open Result.Let_syntax in
        let%map kind =
          match ic.Archive_lib.Processor.Internal_command.command_type with
          | "fee_transfer" ->
              return `Fee_transfer
          | "coinbase" ->
              return `Coinbase
          | "fee_transfer_via_coinbase" ->
              return `Fee_transfer_via_coinbase
          | other ->
              Result.fail
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
        ; receiver = receiver t
        ; receiver_account_creation_fee_paid =
            Option.map
              (receiver_account_creation_fee_paid t)
              ~f:Unsigned.UInt64.of_int64
        ; fee = Unsigned.UInt64.of_string ic.fee
        ; token = `Token_id token_id
        ; sequence_no = sequence_no t
        ; secondary_sequence_no = secondary_sequence_no t
        ; hash = ic.hash
        ; coinbase_receiver
        }
    end

    type t = { command : Cte.t; coinbase_receiver : string option }
    [@@deriving hlist]

    let fields =
      String.concat ~sep:","
        [ "ic.*"; "coinbase_receiver_pk.value as coinbase_receiver" ]

    let coinbase_receiver t =
      Option.map t.coinbase_receiver ~f:(fun pk -> `Pk pk)

    let typ =
      Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
        Caqti_type.[ Cte.typ; option string ]

    let query =
      [%string
        {sql|
          WITH internal_commands_cte AS (
            %{Cte.query}
          )
          SELECT %{fields}
          FROM internal_commands_cte ic
          LEFT JOIN internal_commands_cte ic_coinbase_receiver
            ON ic.command_type = 'fee_transfer_via_coinbase' AND ic_coinbase_receiver.command_type = 'coinbase'
          LEFT JOIN public_keys coinbase_receiver_pk
            ON ic_coinbase_receiver.receiver_id = coinbase_receiver_pk.id
    |sql}]

    let run (module Conn : Mina_caqti.CONNECTION) id =
      Conn.collect_list
        (Mina_caqti.collect_req Caqti_type.(t2 int string) typ query)
        (id, Mina_base.Token_id.(to_string default))

    let to_info t =
      Cte.to_info ~coinbase_receiver:(coinbase_receiver t) t.command
  end

  module Zkapp_commands = struct
    module Extras = struct
      type t =
        { fee_payer : string
        ; fee : string
        ; valid_until : int64 option
        ; nonce : int64
        ; sequence_no : int
        ; status : string
        ; failure_reasons : string array option
        }
      [@@deriving hlist, fields]

      let fields =
        String.concat ~sep:","
          [ "pk_fee_payer.value as fee_payer"
          ; "zfpb.fee"
          ; "zfpb.valid_until"
          ; "zfpb.nonce"
          ; "bzc.sequence_no"
          ; "bzc.status"
          ; "array(SELECT unnest(zauf.failures) FROM \
             zkapp_account_update_failures zauf WHERE zauf.id = ANY \
             (bzc.failure_reasons_ids))"
          ]

      let fee_payer t = `Pk t.fee_payer

      let typ =
        Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
          Caqti_type.
            [ string
            ; string
            ; option int64
            ; int64
            ; int
            ; string
            ; option Mina_caqti.array_string_typ
            ]
    end

    module Archive_zkapp_command = struct
      type t = { memo : string; hash : string } [@@deriving fields, hlist]

      let fields = String.concat ~sep:"," [ "zc.memo"; "zc.hash" ]

      let typ =
        Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
          Caqti_type.[ string; string ]
    end

    module Zkapp_account_update = struct
      type t =
        { body : Archive_lib.Processor.Zkapp_account_update_body.t
        ; account : string
        ; token : string
        }
      [@@deriving hlist]

      let fields =
        String.concat ~sep:","
        @@ List.map Archive_lib.Processor.Zkapp_account_update_body.Fields.names
             ~f:(fun n -> "zaub." ^ n)
        @ [ "pk_update_body.value as account"
          ; "token_update_body.value as token"
          ]

      let account t = `Pk t.account

      let token t = `Token_id t.token

      let typ =
        Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
          Caqti_type.
            [ Archive_lib.Processor.Zkapp_account_update_body.typ
            ; string
            ; string
            ]
    end

    type t =
      { zkapp_command_id : int
      ; zkapp_command : Archive_zkapp_command.t
      ; zkapp_command_extras : Extras.t
      ; zkapp_account_update : Zkapp_account_update.t option
      }
    [@@deriving hlist]

    let fields =
      String.concat ~sep:","
        [ "zc.id"
        ; Archive_zkapp_command.fields
        ; Extras.fields
        ; Zkapp_account_update.fields
        ]

    let typ =
      Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
        Caqti_type.
          [ int
          ; Archive_zkapp_command.typ
          ; Extras.typ
          ; option Zkapp_account_update.typ
          ]

    let query_string =
      [%string
        {| 
         SELECT %{fields}
         FROM blocks_zkapp_commands bzc
         INNER JOIN zkapp_commands zc
           ON zc.id = bzc.zkapp_command_id
         INNER JOIN zkapp_fee_payer_body zfpb
           ON zc.zkapp_fee_payer_body_id = zfpb.id
         INNER JOIN public_keys pk_fee_payer
           ON zfpb.public_key_id = pk_fee_payer.id
         INNER JOIN blocks b
           ON bzc.block_id = b.id
         LEFT JOIN zkapp_account_update zau
           ON zau.id = ANY (zc.zkapp_account_updates_ids)
         LEFT JOIN zkapp_account_update_body zaub
           ON zaub.id = zau.body_id
         LEFT JOIN account_identifiers ai_update_body
           ON zaub.account_identifier_id = ai_update_body.id
         LEFT JOIN public_keys pk_update_body
           ON ai_update_body.public_key_id = pk_update_body.id
         LEFT JOIN tokens token_update_body
           ON token_update_body.id = ai_update_body.token_id
         WHERE bzc.block_id = ?
          AND (token_update_body.value = ? OR token_update_body.id IS NULL)
         ORDER BY zc.id, bzc.sequence_no
      |}]

    let query =
      Mina_caqti.collect_req Caqti_type.(t2 int string) typ query_string

    let run (module Conn : Mina_caqti.CONNECTION) id =
      Conn.collect_list query (id, Mina_base.Token_id.(to_string default))

    module Make_common (M : sig
      type command

      type account_update_info

      type info

      val is_same_command : command -> command -> bool

      val to_account_update_info : command -> account_update_info option

      val account_updates_and_command_to_info :
        account_update_info list -> command -> info
    end) =
    struct
      let to_command_info' command =
        let rec f pending_account_updates = function
          | command' :: t when M.is_same_command command' command ->
              let account_update_info' = M.to_account_update_info command' in
              let pending_account_updates' =
                Option.value_map account_update_info'
                  ~default:pending_account_updates
                  ~f:(fun account_update_info ->
                    account_update_info :: pending_account_updates )
              in
              f pending_account_updates' t
          | ([] | _ :: _) as t ->
              ( M.account_updates_and_command_to_info
                  (List.rev pending_account_updates)
                  command
              , t )
        in
        f
        @@ Option.value_map ~default:[] ~f:List.return
        @@ M.to_account_update_info command

      let to_command_infos =
        let rec f acc = function
          | [] ->
              List.rev acc
          | command :: t ->
              let command_info, t' = to_command_info' command t in
              f (command_info :: acc) t'
        in
        f []
    end

    let to_account_update_info
        { zkapp_command_extras = cmd_extras; zkapp_account_update; _ } =
      Option.map zkapp_account_update ~f:(fun upd ->
          let status =
            match cmd_extras.Extras.status with
            | "applied" ->
                `Success
            | _ ->
                `Failed
          in
          let body = upd.body in
          { Zkapp_account_update_info.authorization_kind =
              body
                .Archive_lib.Processor.Zkapp_account_update_body
                 .authorization_kind
          ; account = Zkapp_account_update.account upd
          ; balance_change = body.balance_change
          ; increment_nonce = body.increment_nonce
          ; may_use_token = body.may_use_token
          ; call_depth = Unsigned.UInt64.of_int body.call_depth
          ; use_full_commitment = body.use_full_commitment
          ; status
          ; token = Zkapp_account_update.token upd
          } )

    let account_updates_and_command_to_info account_updates
        { zkapp_command = cmd; zkapp_command_extras = cmd_extras; _ } =
      { Commands_common.Zkapp_command_info.fee =
          Unsigned.UInt64.of_string @@ cmd_extras.Extras.fee
      ; fee_payer = Extras.fee_payer cmd_extras
      ; valid_until =
          Option.map ~f:Unsigned.UInt32.of_int64 cmd_extras.valid_until
      ; nonce = Unsigned.UInt32.of_int64 cmd_extras.nonce
      ; sequence_no = cmd_extras.sequence_no
      ; memo = (if String.equal cmd.memo "" then None else Some cmd.memo)
      ; hash = cmd.hash
      ; failure_reasons =
          Option.value_map ~default:[] ~f:Array.to_list
            cmd_extras.failure_reasons
      ; account_updates
      }

    include Make_common (struct
      type command = t

      type account_update_info = Zkapp_account_update_info.t

      type info = Zkapp_command_info.t

      let is_same_command t_1 t_2 =
        t_1.zkapp_command_id = t_2.zkapp_command_id
        && t_1.zkapp_command_extras.sequence_no
           = t_2.zkapp_command_extras.sequence_no

      let to_account_update_info = to_account_update_info

      let account_updates_and_command_to_info =
        account_updates_and_command_to_info
    end)
  end

  let run (module Conn : Mina_caqti.CONNECTION) input =
    let module Result = struct
      include Result

      module List = struct
        let map ~f l =
          map ~f:List.rev
          @@ List.fold_result l ~init:[] ~f:(fun acc x ->
                 f x >>| fun x -> x :: acc )
      end
    end in
    let open Deferred.Result.Let_syntax in
    let%bind block_id, raw_block, block_extras =
      match%bind
        Block.run (module Conn) input
        |> Errors.Lift.sql ~context:"Finding block"
      with
      | None ->
          Deferred.Result.fail
            (Errors.create @@ `Block_missing (Block_query.to_string input))
      | Some { block_id; raw_block; block_extras } ->
          return (block_id, raw_block, block_extras)
    in
    let%bind raw_parent_block =
      (* if parent_id is null, this means this is the chain genesis block and
         the block is its own parent *)
      Option.value_map raw_block.parent_id ~default:(return raw_block)
        ~f:(fun parent_id ->
          match%bind
            Block.run_by_id (module Conn) parent_id
            |> Errors.Lift.sql ~context:"Finding parent block"
          with
          | None ->
              Deferred.Result.fail
                ( Errors.create ~context:"Parent block"
                @@ `Block_missing (sprintf "parent_id = %d" parent_id) )
          | Some { raw_block = raw_parent_block; _ } ->
              return raw_parent_block )
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
      Deferred.return
      @@ Result.List.map raw_internal_commands ~f:Internal_commands.to_info
    in
    let%map user_commands =
      Deferred.return
      @@ Result.List.map raw_user_commands ~f:(fun (_, uc, extras) ->
             let open Result.Let_syntax in
             let%bind kind =
               match
                 uc
                   .Archive_lib.Processor.User_command.Signed_command
                    .command_type
               with
               | "payment" ->
                   return `Payment
               | "delegation" ->
                   return `Delegation
               | other ->
                   Result.fail
                     (Errors.create
                        ~context:
                          (sprintf
                             "The archive database is storing user commands \
                              with %s; this is not a known type. Please report \
                              a bug!"
                             other )
                        `Invariant_violation )
             in
             let fee_token = Mina_base.Token_id.(to_string default) in
             let token = Mina_base.Token_id.(to_string default) in
             let%map failure_status =
               match User_commands.Extras.failure_reason extras with
               | None -> (
                   match
                     User_commands.Extras.account_creation_fee_paid extras
                   with
                   | None ->
                       return
                       @@ `Applied
                            User_command_info.Account_creation_fees_paid
                            .By_no_one
                   | Some receiver ->
                       return
                       @@ `Applied
                            (User_command_info.Account_creation_fees_paid
                             .By_receiver
                               (Unsigned.UInt64.of_int64 receiver) ) )
               | Some status ->
                   return @@ `Failed status
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
             ; valid_until =
                 Option.map ~f:Unsigned.UInt32.of_int64 uc.valid_until
             ; memo = (if String.equal uc.memo "" then None else Some uc.memo)
             } )
    in
    let zkapp_commands = Zkapp_commands.to_command_infos raw_zkapp_commands in
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
      { logger
      ; db_block =
          (fun query ->
            let (module Conn : Mina_caqti.CONNECTION) = db in
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
        -> minimum_user_command_fee:Mina_currency.Fee.t
        -> env:'gql Env.T(M).t
        -> Block_request.t
        -> (Block_response.t, Errors.t) M.t =
     fun ~graphql_uri ~minimum_user_command_fee ~env req ->
      let open M.Let_syntax in
      let logger = env.logger in
      let%bind query = Query.of_partial_identifier req.block_identifier in
      let%bind () =
        env.validate_network_choice ~network_identifier:req.network_identifier
          ~graphql_uri ~minimum_user_command_fee
      in
      let%bind block_info = env.db_block query in
      let%bind internal_transactions =
        List.fold block_info.internal_info ~init:(M.return [])
          ~f:(fun macc info ->
            let%bind acc = macc in
            [%log debug]
              ~metadata:[ ("info", Internal_command_info.to_yojson info) ]
              "Block internal received $info" ;
            let%map transaction =
              Internal_command_info_ops.to_transaction info
            in
            transaction :: acc )
        |> M.map ~f:List.rev
      in
      let user_transactions =
        List.map block_info.user_commands ~f:(fun info ->
            [%log debug]
              ~metadata:[ ("info", User_command_info.to_yojson info) ]
              "Block user received $info" ;
            User_command_info.to_transaction info )
      in
      let%map zkapp_command_transactions =
        List.fold block_info.zkapp_commands ~init:(M.return [])
          ~f:(fun acc cmd ->
            let%bind acc = acc in
            [%log debug]
              ~metadata:[ ("info", Zkapp_command_info.to_yojson cmd) ]
              "Block zkapp received $info" ;
            let%map transaction = Zkapp_command_info_ops.to_transaction cmd in
            transaction :: acc )
        |> M.map ~f:List.rev
      in
      { Block_response.block =
          Some
            { Block.block_identifier = block_info.block_identifier
            ; parent_block_identifier = block_info.parent_block_identifier
            ; timestamp = block_info.timestamp
            ; transactions =
                internal_transactions @ user_transactions
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

let router ~graphql_uri ~minimum_user_command_fee ~logger ~with_db
    (route : string list) body =
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
            Specific.Real.handle ~graphql_uri ~minimum_user_command_fee
              ~env:(Specific.Env.real ~logger ~db)
              req
            |> Errors.Lift.wrap
          in
          Block_response.to_yojson res )
  (* Note: We do not need to implement /block/transaction endpoint because we
   * don't return any "other_transactions" *)
  | _ ->
      Deferred.Result.fail `Page_not_found
