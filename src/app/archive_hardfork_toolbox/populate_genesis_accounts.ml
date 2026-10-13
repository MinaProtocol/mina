(** Write a genesis ledger to [accounts_accessed] of its genesis block, a
    chunk of accounts per transaction, with set-based statements.

    The rows equal what [Archive_lib.Processor.Accounts_accessed] writes one
    account at a time, but each chunk costs a fixed number of statements,
    and each lookup into a table without an index ([timing_info],
    [zkapp_permissions], [zkapp_states], [zkapp_action_states],
    [zkapp_accounts]) is one join per chunk instead of one scan per account.
    Rows that exist are reused (the lowest id when there are duplicates);
    accounts the block already has are skipped. *)

open Core
open Async
open Mina_base
open Caqti_request.Infix

module type CONNECTION = Mina_caqti.CONNECTION

let auth_required = function
  | Permissions.Auth_required.None ->
      "none"
  | Either ->
      "either"
  | Proof ->
      "proof"
  | Signature ->
      "signature"
  | Impossible ->
      "impossible"

let field fp = `String (Pickles.Backend.Tick.Field.to_string fp)

let int64_of_uint32 x = `Intlit (Unsigned.UInt32.to_int64 x |> Int64.to_string)

(* One account as a JSON object; the column names are those of [chunk_cols]. *)
let account_json (ledger_index, (account : Account.t)) =
  let string s = `String s in
  let timing =
    match account.timing with
    | Untimed ->
        [ ("imb", string "0")
        ; ("ct", `Intlit "0")
        ; ("ca", string "0")
        ; ("vp", `Intlit "0")
        ; ("vi", string "0")
        ]
    | Timed t ->
        [ ("imb", string (Currency.Balance.to_string t.initial_minimum_balance))
        ; ( "ct"
          , int64_of_uint32
              (Mina_numbers.Global_slot_since_genesis.to_uint32 t.cliff_time) )
        ; ("ca", string (Currency.Amount.to_string t.cliff_amount))
        ; ( "vp"
          , int64_of_uint32
              (Mina_numbers.Global_slot_span.to_uint32 t.vesting_period) )
        ; ("vi", string (Currency.Amount.to_string t.vesting_increment))
        ]
  in
  let p = account.permissions in
  let permissions =
    [ ("p_edit_state", p.edit_state)
    ; ("p_send", p.send)
    ; ("p_receive", p.receive)
    ; ("p_access", p.access)
    ; ("p_set_delegate", p.set_delegate)
    ; ("p_set_permissions", p.set_permissions)
    ; ("p_set_verification_key_auth", fst p.set_verification_key)
    ; ("p_set_zkapp_uri", p.set_zkapp_uri)
    ; ("p_edit_action_state", p.edit_action_state)
    ; ("p_set_token_symbol", p.set_token_symbol)
    ; ("p_increment_nonce", p.increment_nonce)
    ; ("p_set_voting_for", p.set_voting_for)
    ; ("p_set_timing", p.set_timing)
    ]
    |> List.map ~f:(fun (name, auth) -> (name, string (auth_required auth)))
  in
  let zkapp =
    match account.zkapp with
    | None ->
        [ ("zk", `Bool false) ]
    | Some zk ->
        [ ("zk", `Bool true)
        ; ( "zk_vk"
          , Option.value_map zk.verification_key ~default:`Null ~f:(fun vk ->
                string (Pickles.Side_loaded.Verification_key.to_base64 vk.data) )
          )
        ; ( "zk_vk_hash"
          , Option.value_map zk.verification_key ~default:`Null ~f:(fun vk ->
                field vk.hash ) )
        ; ("zk_ver", int64_of_uint32 zk.zkapp_version)
        ; ( "zk_las"
          , int64_of_uint32
              (Mina_numbers.Global_slot_since_genesis.to_uint32
                 zk.last_action_slot ) )
        ; ("zk_proved", `Bool zk.proved_state)
        ; ("zk_uri", string zk.zkapp_uri)
        ; ( "app_state"
          , `List
              (Pickles_types.Vector.to_list zk.app_state |> List.map ~f:field)
          )
        ; ( "action_state"
          , `List
              (Pickles_types.Vector.to_list zk.action_state |> List.map ~f:field)
          )
        ]
  in
  `Assoc
    ( [ ("idx", `Int ledger_index)
      ; ( "pk"
        , string
            (Signature_lib.Public_key.Compressed.to_base58_check
               account.public_key ) )
      ; ("token", string (Token_id.to_string account.token_id))
      ; ("sym", string account.token_symbol)
      ; ("bal", string (Currency.Balance.to_string account.balance))
      ; ("nonce", int64_of_uint32 (Account.Nonce.to_uint32 account.nonce))
      ; ( "rch"
        , string (Receipt.Chain_hash.to_base58_check account.receipt_chain_hash)
        )
      ; ( "del"
        , Option.value_map account.delegate ~default:`Null ~f:(fun pk ->
              string (Signature_lib.Public_key.Compressed.to_base58_check pk) )
        )
      ; ("vf", string (State_hash.to_base58_check account.voting_for))
      ; ( "p_vk_txn"
        , `Int (Mina_numbers.Txn_version.to_int (snd p.set_verification_key)) )
      ]
    @ timing @ permissions @ zkapp )

let permission_cols =
  [ "edit_state"
  ; "send"
  ; "receive"
  ; "access"
  ; "set_delegate"
  ; "set_permissions"
  ; "set_verification_key_auth"
  ; "set_zkapp_uri"
  ; "edit_action_state"
  ; "set_token_symbol"
  ; "increment_nonce"
  ; "set_voting_for"
  ; "set_timing"
  ]

let chunk_cols =
  [ "idx int"
  ; "pk text"
  ; "token text"
  ; "sym text"
  ; "bal text"
  ; "nonce bigint"
  ; "rch text"
  ; "del text"
  ; "vf text"
  ; "p_vk_txn int"
  ; "imb text"
  ; "ct bigint"
  ; "ca text"
  ; "vp bigint"
  ; "vi text"
  ]
  @ List.map permission_cols ~f:(fun c -> sprintf "p_%s text" c)
  @ [ "zk boolean"
    ; "zk_vk text"
    ; "zk_vk_hash text"
    ; "zk_ver bigint"
    ; "zk_las bigint"
    ; "zk_proved boolean"
    ; "zk_uri text"
    ; "app_state jsonb"
    ; "action_state jsonb"
    ]

(* [elements n] = "element0, ..., element(n-1)" *)
let elements n = List.init n ~f:(sprintf "element%d") |> String.concat ~sep:", "

(* Insert the distinct element vectors of [source] missing from [table] and
   set [id_col] of the chunk to the lowest matching id. *)
let vector_stmts ~table ~source ~json_col ~id_col ~n =
  let ids = List.init n ~f:(fun i -> sprintf "ids[%d]" (i + 1)) in
  let matches alias =
    List.init n ~f:(fun i -> sprintf "%s.element%d = s.ids[%d]" alias i (i + 1))
    |> String.concat ~sep:" AND "
  in
  [ sprintf
      {sql| CREATE TEMP TABLE %s ON COMMIT DROP AS
            SELECT c.idx, array_agg(f.id ORDER BY e.ord) AS ids
            FROM genesis_chunk c
            CROSS JOIN LATERAL jsonb_array_elements_text(c.%s)
              WITH ORDINALITY AS e(field, ord)
            JOIN zkapp_field f ON f.field = e.field
            WHERE c.zk
            GROUP BY c.idx |sql}
      source json_col
  ; sprintf
      {sql| INSERT INTO %s (%s)
            SELECT DISTINCT %s FROM %s s
            WHERE NOT EXISTS (SELECT 1 FROM %s z WHERE %s) |sql}
      table (elements n)
      (String.concat ~sep:", " ids)
      source table (matches "z")
  ; sprintf
      {sql| UPDATE genesis_chunk c SET %s = m.id
            FROM (SELECT s.idx, min(z.id) AS id FROM %s s
                  JOIN %s z ON %s GROUP BY s.idx) m
            WHERE m.idx = c.idx |sql}
      id_col source table (matches "z")
  ]

let permission_match =
  List.map permission_cols ~f:(fun c ->
      sprintf "z.%s = c.p_%s::zkapp_auth_required_type" c c )
  @ [ "z.set_verification_key_txn_version = c.p_vk_txn" ]
  |> String.concat ~sep:" AND "

let timing_match =
  {sql| t.account_identifier_id = c.aid
        AND t.initial_minimum_balance = c.imb AND t.cliff_time = c.ct
        AND t.cliff_amount = c.ca AND t.vesting_period = c.vp
        AND t.vesting_increment = c.vi |sql}

let zkapp_account_match =
  {sql| z.app_state_id = c.app_state_id
        AND COALESCE(z.verification_key_id, -1) = COALESCE(c.vk_id, -1)
        AND z.zkapp_version = c.zk_ver
        AND z.action_state_id = c.action_state_id
        AND z.last_action_slot = c.zk_las
        AND z.proved_state = c.zk_proved
        AND z.zkapp_uri_id = c.uri_id |sql}

(* Statements after the chunk is loaded, in order. *)
let stmts =
  [ (* The tables without a UNIQUE key: an archive writing at the same time
       waits for this chunk, so neither side adds a duplicate it cannot see. *)
    {sql| LOCK TABLE token_symbols, voting_for, timing_info, zkapp_permissions,
            zkapp_states, zkapp_action_states, zkapp_accounts
          IN SHARE ROW EXCLUSIVE MODE |sql}
  ; {sql| ALTER TABLE genesis_chunk
            ADD COLUMN aid int, ADD COLUMN sym_id int, ADD COLUMN del_id int,
            ADD COLUMN vf_id int, ADD COLUMN timing_id int,
            ADD COLUMN perm_id int, ADD COLUMN app_state_id int,
            ADD COLUMN action_state_id int, ADD COLUMN vk_id int,
            ADD COLUMN uri_id int, ADD COLUMN zkapp_id int |sql}
  ; {sql| INSERT INTO public_keys (value)
          SELECT pk FROM genesis_chunk
          UNION SELECT del FROM genesis_chunk WHERE del IS NOT NULL
          ON CONFLICT (value) DO NOTHING |sql}
    (* ownerless, reusing a row that has an owner: as Token.add_if_doesn't_exist
       does for genesis accounts *)
  ; {sql| INSERT INTO tokens (value)
          SELECT DISTINCT token FROM genesis_chunk
          ON CONFLICT (value) DO NOTHING |sql}
  ; {sql| INSERT INTO account_identifiers (public_key_id, token_id)
          SELECT p.id, t.id FROM genesis_chunk c
          JOIN public_keys p ON p.value = c.pk
          JOIN tokens t ON t.value = c.token
          ON CONFLICT DO NOTHING |sql}
  ; {sql| UPDATE genesis_chunk c SET aid = ai.id
          FROM account_identifiers ai
          JOIN public_keys p ON p.id = ai.public_key_id
          JOIN tokens t ON t.id = ai.token_id
          WHERE p.value = c.pk AND t.value = c.token |sql}
  ; {sql| DELETE FROM genesis_chunk c USING accounts_accessed a
          WHERE a.block_id = $1 AND a.account_identifier_id = c.aid |sql}
  ; {sql| UPDATE genesis_chunk c SET del_id = p.id FROM public_keys p
          WHERE p.value = c.del |sql}
  ; {sql| INSERT INTO token_symbols (value)
          SELECT DISTINCT c.sym FROM genesis_chunk c
          WHERE NOT EXISTS (SELECT 1 FROM token_symbols t WHERE t.value = c.sym) |sql}
  ; {sql| UPDATE genesis_chunk c SET sym_id = m.id
          FROM (SELECT value, min(id) AS id FROM token_symbols GROUP BY value) m
          WHERE m.value = c.sym |sql}
  ; {sql| INSERT INTO voting_for (value)
          SELECT DISTINCT c.vf FROM genesis_chunk c
          WHERE NOT EXISTS (SELECT 1 FROM voting_for t WHERE t.value = c.vf) |sql}
  ; {sql| UPDATE genesis_chunk c SET vf_id = m.id
          FROM (SELECT value, min(id) AS id FROM voting_for GROUP BY value) m
          WHERE m.value = c.vf |sql}
  ; sprintf
      {sql| INSERT INTO timing_info
              (account_identifier_id, initial_minimum_balance, cliff_time,
               cliff_amount, vesting_period, vesting_increment)
            SELECT c.aid, c.imb, c.ct, c.ca, c.vp, c.vi FROM genesis_chunk c
            WHERE NOT EXISTS (SELECT 1 FROM timing_info t WHERE %s) |sql}
      timing_match
  ; sprintf
      {sql| UPDATE genesis_chunk c SET timing_id = m.id
            FROM (SELECT c.idx, min(t.id) AS id FROM genesis_chunk c
                  JOIN timing_info t ON %s GROUP BY c.idx) m
            WHERE m.idx = c.idx |sql}
      timing_match
  ; sprintf
      {sql| INSERT INTO zkapp_permissions (%s, set_verification_key_txn_version)
            SELECT DISTINCT %s, c.p_vk_txn FROM genesis_chunk c
            WHERE NOT EXISTS (SELECT 1 FROM zkapp_permissions z WHERE %s) |sql}
      (String.concat ~sep:", " permission_cols)
      ( List.map permission_cols ~f:(sprintf "c.p_%s::zkapp_auth_required_type")
      |> String.concat ~sep:", " )
      permission_match
  ; sprintf
      {sql| UPDATE genesis_chunk c SET perm_id = m.id
            FROM (SELECT c.idx, min(z.id) AS id FROM genesis_chunk c
                  JOIN zkapp_permissions z ON %s GROUP BY c.idx) m
            WHERE m.idx = c.idx |sql}
      permission_match
  ; {sql| INSERT INTO zkapp_field (field)
          SELECT DISTINCT e.field FROM genesis_chunk c
          CROSS JOIN LATERAL jsonb_array_elements_text(
            c.app_state || c.action_state) AS e(field)
          WHERE c.zk
          ON CONFLICT (field) DO NOTHING |sql}
  ]
  @ vector_stmts ~table:"zkapp_states" ~source:"genesis_app_state"
      ~json_col:"app_state" ~id_col:"app_state_id" ~n:Zkapp_state.max_size_int
  @ vector_stmts ~table:"zkapp_action_states" ~source:"genesis_action_state"
      ~json_col:"action_state" ~id_col:"action_state_id"
      ~n:(Pickles_types.Nat.to_int Pickles_types.Nat.N5.n)
  @ [ {sql| INSERT INTO zkapp_verification_key_hashes (value)
            SELECT DISTINCT zk_vk_hash FROM genesis_chunk
            WHERE zk_vk IS NOT NULL
            ON CONFLICT (value) DO NOTHING |sql}
    ; {sql| INSERT INTO zkapp_verification_keys (verification_key, hash_id)
            SELECT DISTINCT c.zk_vk, h.id FROM genesis_chunk c
            JOIN zkapp_verification_key_hashes h ON h.value = c.zk_vk_hash
            WHERE c.zk_vk IS NOT NULL
            ON CONFLICT DO NOTHING |sql}
    ; {sql| UPDATE genesis_chunk c SET vk_id = v.id
            FROM zkapp_verification_keys v
            WHERE v.verification_key = c.zk_vk |sql}
    ; {sql| INSERT INTO zkapp_uris (value)
            SELECT DISTINCT zk_uri FROM genesis_chunk WHERE zk
            ON CONFLICT (value) DO NOTHING |sql}
    ; {sql| UPDATE genesis_chunk c SET uri_id = u.id FROM zkapp_uris u
            WHERE c.zk AND u.value = c.zk_uri |sql}
    ; sprintf
        {sql| INSERT INTO zkapp_accounts
                (app_state_id, verification_key_id, zkapp_version,
                 action_state_id, last_action_slot, proved_state, zkapp_uri_id)
              SELECT DISTINCT c.app_state_id, c.vk_id, c.zk_ver,
                c.action_state_id, c.zk_las, c.zk_proved, c.uri_id
              FROM genesis_chunk c
              WHERE c.zk
                AND NOT EXISTS (SELECT 1 FROM zkapp_accounts z WHERE %s) |sql}
        zkapp_account_match
    ; sprintf
        {sql| UPDATE genesis_chunk c SET zkapp_id = m.id
              FROM (SELECT c.idx, min(z.id) AS id FROM genesis_chunk c
                    JOIN zkapp_accounts z ON %s
                    WHERE c.zk GROUP BY c.idx) m
              WHERE m.idx = c.idx |sql}
        zkapp_account_match
    ]

let load_chunk_req =
  (Caqti_type.string ->. Caqti_type.unit)
  @@ sprintf
       {sql| CREATE TEMP TABLE genesis_chunk ON COMMIT DROP AS
             SELECT * FROM jsonb_to_recordset($1::jsonb) AS x(%s) |sql}
       (String.concat ~sep:", " chunk_cols)

let stmt_reqs =
  List.map stmts ~f:(fun sql ->
      if String.is_substring sql ~substring:"$1" then
        `Block ((Caqti_type.int ->. Caqti_type.unit) sql)
      else `Unit ((Caqti_type.unit ->. Caqti_type.unit) sql) )

let insert_accessed_req =
  (Caqti_type.int ->! Caqti_type.int)
    {sql| WITH written AS (
            INSERT INTO accounts_accessed
              (ledger_index, block_id, account_identifier_id, token_symbol_id,
               balance, nonce, receipt_chain_hash, delegate_id, voting_for_id,
               timing_id, permissions_id, zkapp_id)
            SELECT idx, $1, aid, sym_id, bal, nonce, rch, del_id, vf_id,
                   timing_id, perm_id, zkapp_id
            FROM genesis_chunk
            ON CONFLICT (block_id, account_identifier_id) DO NOTHING
            RETURNING 1)
          SELECT count(*)::int FROM written |sql}

let written_req =
  (Caqti_type.int ->! Caqti_type.int)
    "SELECT count(*)::int FROM accounts_accessed WHERE block_id = $1"

let write_chunk (module Conn : CONNECTION) ~block_id chunk =
  let open Deferred.Result.Let_syntax in
  let%bind () =
    Conn.exec load_chunk_req
      (Yojson.Safe.to_string (`List (List.map chunk ~f:account_json)))
  in
  let%bind () =
    Mina_caqti.deferred_result_list_fold stmt_reqs ~init:() ~f:(fun () ->
      function
      | `Unit req -> Conn.exec req () | `Block req -> Conn.exec req block_id )
  in
  Conn.find insert_accessed_req block_id

(** Write [accounts] (ledger index, account) to [accounts_accessed] of
    [block_id], [chunk_size] accounts per transaction. Returns the number of
    rows written; accounts the block already has are skipped. *)
let run ?(chunk_size = 2_000) ~logger (module Conn : CONNECTION) ~block_id
    accounts =
  let open Deferred.Result.Let_syntax in
  let total = List.length accounts in
  let%bind already = Conn.find written_req block_id in
  if already >= total then return 0
  else
    let chunks = List.chunks_of accounts ~length:chunk_size in
    let num_chunks = List.length chunks in
    Mina_caqti.deferred_result_list_fold (List.mapi chunks ~f:Tuple2.create)
      ~init:0 ~f:(fun written (i, chunk) ->
        let%bind () = Conn.start () in
        match%bind.Deferred write_chunk (module Conn) ~block_id chunk with
        | Ok n ->
            let%map () = Conn.commit () in
            [%log info] "Wrote chunk $chunk of $chunks: $count accounts"
              ~metadata:
                [ ("chunk", `Int (i + 1))
                ; ("chunks", `Int num_chunks)
                ; ("count", `Int n)
                ] ;
            written + n
        | Error e ->
            let%bind.Deferred (_ : (unit, _) Result.t) = Conn.rollback () in
            Deferred.Result.fail e )
