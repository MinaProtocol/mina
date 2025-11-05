open Async
open Core
open Caqti_request.Infix

module type CONNECTION = Mina_caqti.CONNECTION

module Protocol_version = struct
  type t = { transaction : int; network : int; patch : int }

  let of_string : string -> t = function
    | version_str -> (
        String.split version_str ~on:'.'
        |> List.map ~f:Int.of_string
        |> function
        | [ transaction; network; patch ] ->
            { transaction; network; patch }
        | _ ->
            failwithf
              "Invalid protocol version string: %s. Expected format \
               <network>.<transaction>.<patch>"
              version_str () )

  let to_string { transaction; network; patch } =
    sprintf "%d.%d.%d" network transaction patch

  let typ =
    let encode { transaction; network; patch } =
      Ok (transaction, network, patch)
    in
    let decode (transaction, network, patch) =
      Ok { transaction; network; patch }
    in
    Caqti_type.(custom ~encode ~decode (t3 int int int))
end

type block_info =
  { id : int
  ; height : int64
  ; state_hash : string
  ; protocol_version : Protocol_version.t
  }

let block_info_typ =
  let encode { id; height; state_hash; protocol_version } =
    Ok (id, height, state_hash, protocol_version)
  in
  let decode (id, height, state_hash, protocol_version) =
    Ok { id; height; state_hash; protocol_version }
  in
  Caqti_type.(custom ~encode ~decode (t4 int int64 string Protocol_version.typ))

let latest_state_hash_query =
  Caqti_type.(unit ->! string)
    {sql|
          SELECT state_hash from blocks order by height desc limit 1;
        |sql}

let latest_state_hash (module Conn : CONNECTION) =
  Conn.find latest_state_hash_query ()

let genesis_block_query =
  (Protocol_version.typ ->? block_info_typ)
    {sql|
      SELECT blocks.id, height, state_hash, protocol_versions.network, protocol_versions.transaction, protocol_versions.patch
      FROM blocks inner JOIN protocol_versions
        ON blocks.protocol_version_id = protocol_versions.id
      WHERE protocol_versions.transaction = $1::int
        AND protocol_versions.network = $2::int
        AND protocol_versions.patch = $3::int
        AND global_slot_since_hard_fork = 0
      ORDER BY id ASC
      LIMIT 1;
    |sql}

let genesis_block (module Conn : CONNECTION)
    ~(protocol_version : Protocol_version.t) =
  Conn.find_opt genesis_block_query protocol_version

let block_info_by_state_hash_query =
  Caqti_type.(string ->? block_info_typ)
    {sql|
      SELECT blocks.id, height, state_hash, protocol_versions.network, protocol_versions.transaction, protocol_versions.patch
      FROM blocks inner JOIN protocol_versions
        ON blocks.protocol_version_id = protocol_versions.id
      WHERE state_hash = ?
      LIMIT 1;
    |sql}

let block_info_by_state_hash (module Conn : CONNECTION) ~state_hash =
  Conn.find_opt block_info_by_state_hash_query state_hash

let canonical_chain_members_query =
  Caqti_type.(t3 int int Protocol_version.typ ->* block_info_typ)
    {sql|
      WITH RECURSIVE chain AS (
        SELECT blocks.id, parent_id, height, state_hash, transaction, network, patch
        FROM blocks inner JOIN protocol_versions
          ON blocks.protocol_version_id = protocol_versions.id
        WHERE blocks.id = $1::int AND protocol_versions.transaction = $3::int
          AND protocol_versions.network = $4::int
          AND protocol_versions.patch = $5::int

        UNION ALL

        SELECT b.id, b.parent_id, b.height, b.state_hash, pv.transaction, pv.network, pv.patch
        FROM blocks b
        INNER JOIN protocol_versions pv
          ON b.protocol_version_id = pv.id
        INNER JOIN chain
          ON b.id = chain.parent_id
        WHERE (chain.id <> $2::int OR b.id = $2::int)
          AND pv.transaction = $3::int
          AND pv.network = $4::int
          AND pv.patch = $5::int
      )
      SELECT id, height, state_hash, transaction, network, patch
      FROM chain
      ORDER BY height ASC;
    |sql}

let canonical_chain_ids (module Conn : CONNECTION) ~target_block_id ~genesis_id
    ~(protocol_version : Protocol_version.t) =
  let open Deferred.Result.Let_syntax in
  Conn.collect_list canonical_chain_members_query
    (target_block_id, genesis_id, protocol_version)
  >>| List.map ~f:(fun block_info -> block_info.id)

let protocol_version_id_query =
  Caqti_type.(Protocol_version.typ ->! int)
    {sql|
      SELECT id FROM protocol_versions
      WHERE transaction = $1::int
        AND network = $2::int
        AND patch = $3::int
      LIMIT 1;
    |sql}

let canonical_or_orphaned_blocks_query =
  Caqti_type.(t3 (option int) int Mina_caqti.array_int_typ ->. Caqti_type.unit)
    {sql|
      UPDATE blocks
      SET chain_status = CASE
          WHEN id = ANY($3::int[]) THEN 'canonical'::chain_status_type
          ELSE 'orphaned'::chain_status_type
      END
      WHERE protocol_version_id = $2::int
        AND ($1 IS NULL OR global_slot_since_genesis < $1::int);
    |sql}

let mark_blocks_as_canonical_or_orphaned (module Conn : CONNECTION) ~ids
    ~stop_at_slot ~protocol_version =
  let open Deferred.Result.Let_syntax in
  let id_array = Array.of_list ids in
  let%bind protocol_version_id =
    Conn.find protocol_version_id_query protocol_version
  in
  Conn.exec canonical_or_orphaned_blocks_query
    (stop_at_slot, protocol_version_id, id_array)

let chain_of_query =
  {sql|
    WITH RECURSIVE chain AS (
        SELECT
            b.id AS id,
            b.parent_id AS parent_id,
            b.state_hash AS state_hash,
            b.height AS height,
            b.global_slot_since_genesis AS global_slot_since_genesis
        FROM blocks b
        WHERE b.state_hash = ?

        UNION ALL

        SELECT
            p.id,
            p.parent_id,
            p.state_hash,
            p.height,
            p.global_slot_since_genesis
        FROM blocks p
        JOIN chain c ON p.id = c.parent_id
        WHERE p.parent_id IS NOT NULL
    )
  |sql}

let is_in_best_chain_query =
  Caqti_type.(t4 string string int int64 ->! bool)
    ( chain_of_query
    ^ {sql|
    SELECT EXISTS (
      SELECT 1 FROM chain
      WHERE state_hash = ?
        AND height = ?
        AND global_slot_since_genesis = ?
    );
    |sql}
    )

let is_in_best_chain (module Conn : CONNECTION) ~tip_hash ~check_hash
    ~check_height ~check_slot =
  Conn.find is_in_best_chain_query
    (tip_hash, check_hash, check_height, check_slot)

let num_of_confirmations_query =
  Caqti_type.(t2 string int ->! int)
    ( chain_of_query
    ^ {sql|
    SELECT count(*) FROM chain 
    WHERE global_slot_since_genesis >= ?;
    |sql}
    )

let num_of_confirmations (module Conn : CONNECTION) ~latest_state_hash
    ~fork_slot =
  Conn.find num_of_confirmations_query (latest_state_hash, fork_slot)

let number_of_commands_since_block_query block_commands_table =
  Caqti_type.(t2 string int ->! t4 string int int int)
    ( chain_of_query
    ^ Printf.sprintf
        {sql|
    SELECT 
        state_hash,
        height,
        global_slot_since_genesis,
        COUNT(bc.block_id) AS command_count
    FROM chain
    LEFT JOIN %s bc 
        ON chain.id = bc.block_id
    WHERE global_slot_since_genesis >= ?
    GROUP BY 
        state_hash,
        height,
        global_slot_since_genesis;
    |sql}
        block_commands_table )

let number_of_user_commands_since_block (module Conn : CONNECTION)
    ~fork_state_hash ~fork_slot =
  Conn.find
    (number_of_commands_since_block_query "blocks_user_commands")
    (fork_state_hash, fork_slot)

let number_of_internal_commands_since_block (module Conn : CONNECTION)
    ~fork_state_hash ~fork_slot =
  Conn.find
    (number_of_commands_since_block_query "blocks_internal_commands")
    (fork_state_hash, fork_slot)

let number_of_zkapps_commands_since_block (module Conn : CONNECTION)
    ~fork_state_hash ~fork_slot =
  Conn.find
    (number_of_commands_since_block_query "blocks_zkapp_commands")
    (fork_state_hash, fork_slot)

let last_fork_block_query =
  Caqti_type.(unit ->! t2 string int64)
    {sql|
    SELECT state_hash, global_slot_since_genesis FROM blocks
    WHERE global_slot_since_hard_fork = 0
    ORDER BY height DESC
    LIMIT 1;
    |sql}

let last_fork_block (module Conn : CONNECTION) =
  Conn.find last_fork_block_query ()

let fetch_latest_migration_history_query =
  Caqti_type.(unit ->? t3 string string string)
    {|
      SELECT
        status, protocol_version, migration_version
      FROM migration_history
      ORDER BY commit_start_at DESC
      LIMIT 1;
    |}

let fetch_latest_migration_history (module Conn : CONNECTION) =
  Conn.find_opt fetch_latest_migration_history_query ()

(* Fetches last filled block before stop transaction slot.

   Every block in mina should have internal commands since system transactions (like coinbase, fee transfer etc)
   are implemented as internal commands. It CAN have zero user commands and zero zkapp commands,
   but it should have internal commands.

   However, in context of hard fork, we want to stop including any transactions
   in the blocks after specified slot (called stop transaction slot). No internal, user or zkapp commands should be included in the blocks after that slot.
   Blocks can still be produced with no transactions, to keep chain progressing and give us confirmations but
   only from stop transaction slot till stop network slot, where we completely stop the chain.
   Knowing above we can detect last filled block by only looking at internal transactions occurrence.
   Therefore our fork candidate is the block with highest height that has internal transaction included in it.
*)
let fetch_last_filled_block_query =
  Caqti_type.(unit ->! t3 string int64 int)
    {sql|
    SELECT b.state_hash, b.global_slot_since_genesis, b.height
    FROM blocks b
    INNER JOIN blocks_internal_commands bic ON b.id = bic.block_id
    ORDER BY b.height DESC
    LIMIT 1;
    |sql}

let fetch_last_filled_block (module Conn : CONNECTION) =
  Conn.find fetch_last_filled_block_query ()
