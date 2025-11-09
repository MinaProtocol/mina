open Async
open Core
open Caqti_request.Infix

module type CONNECTION = Mina_caqti.CONNECTION

module Protocol_version = struct
  type t = { transaction : int; network : int; patch : int } [@@deriving equal]

  let of_string : string -> t = function
    | version_str -> (
        try
          Scanf.sscanf version_str "%d.%d.%d" (fun transaction network patch ->
              { transaction; network; patch } )
        with _ ->
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

module Block_info = struct
  type t =
    { id : int
    ; height : int64
    ; state_hash : string
    ; protocol_version : Protocol_version.t
    }

  let typ =
    let encode { id; height; state_hash; protocol_version } =
      Ok (id, height, state_hash, protocol_version)
    in
    let decode (id, height, state_hash, protocol_version) =
      Ok { id; height; state_hash; protocol_version }
    in
    Caqti_type.(
      custom ~encode ~decode (t4 int int64 string Protocol_version.typ))
end

let chain_of_query_templated ~join_condition =
  {%string|
    WITH RECURSIVE chain AS (
        SELECT
            b.id AS id,
            b.parent_id AS parent_id,
            b.state_hash AS state_hash,
            b.height AS height,
            b.global_slot_since_genesis AS global_slot_since_genesis
        FROM blocks b
        WHERE b.state_hash = $1

        UNION ALL

        SELECT
            p.id,
            p.parent_id,
            p.state_hash,
            p.height,
            p.global_slot_since_genesis
        FROM blocks p
        JOIN chain c ON p.id = c.parent_id AND %{join_condition}
        WHERE p.parent_id IS NOT NULL
    )
  |}

let chain_of_query = chain_of_query_templated ~join_condition:"TRUE"

let chain_of_query_until_inclusive =
  chain_of_query_templated ~join_condition:"c.state_hash <> $2"

let latest_state_hash (module Conn : CONNECTION) =
  let query =
    Caqti_type.(unit ->! string)
      {%string|
        SELECT state_hash from blocks order by height desc limit 1;
      |}
  in
  Conn.find query ()

(* Returns the first block of a specific protocol version.
   NOTE: There exists some emergency HF that doesn't bump up protocol version. *)
let first_block_of_protocol_version (module Conn : CONNECTION)
    ~(v : Protocol_version.t) =
  let query =
    (Protocol_version.typ ->? Block_info.typ)
      {%string|
        SELECT blocks.id, height, state_hash, protocol_versions.network, protocol_versions.transaction, protocol_versions.patch
        FROM blocks INNER JOIN protocol_versions
          ON blocks.protocol_version_id = protocol_versions.id
        WHERE protocol_versions.transaction = $1::int
          AND protocol_versions.network = $2::int
          AND protocol_versions.patch = $3::int
          AND global_slot_since_hard_fork = 0
        ORDER BY id ASC
        LIMIT 1;
      |}
  in
  Conn.find_opt query v

let block_info_by_state_hash (module Conn : CONNECTION) ~state_hash =
  let query =
    Caqti_type.(string ->? Block_info.typ)
      {%string|
        SELECT blocks.id, height, state_hash, protocol_versions.network, protocol_versions.transaction, protocol_versions.patch
        FROM blocks INNER JOIN protocol_versions
          ON blocks.protocol_version_id = protocol_versions.id
        WHERE state_hash = ?
        LIMIT 1;
      |}
  in
  Conn.find_opt query state_hash

let mark_pending_blocks_as_canonical_or_orphaned (module Conn : CONNECTION)
    ~canonical_block_ids ~stop_at_slot =
  let mutation =
    Caqti_type.(t2 (option int) Mina_caqti.array_int_typ ->. Caqti_type.unit)
      {%string|
        UPDATE blocks
        SET chain_status = CASE
            WHEN id = ANY($2::int[]) THEN 'canonical'::chain_status_type
            ELSE 'orphaned'::chain_status_type
        END
        WHERE chain_status = 'pending'::chain_status_type
          AND ($1 IS NULL OR $1::int <= global_slot_since_genesis);
      |}
  in
  Conn.exec mutation (stop_at_slot, Array.of_list canonical_block_ids)

let blocks_between_both_inclusive (module Conn : CONNECTION) ~latest_block_id
    ~oldest_block_id : (Block_info.t list, Caqti_error.t) Deferred.Result.t =
  let query =
    Caqti_type.(t2 int int ->* Block_info.typ)
      {%string|
        %{chain_of_query_until_inclusive}
        SELECT chain.id, height, state_hash, protocol_versions.network, protocol_versions.transaction, protocol_versions.patch
        FROM chain INNER JOIN protocol_versions
          ON chain.protocol_version_id = protocol_versions.id
        ORDER BY height ASC
      |}
  in
  Conn.collect_list query (latest_block_id, oldest_block_id)

let is_in_best_chain (module Conn : CONNECTION) ~tip_hash ~check_hash
    ~check_height ~check_slot =
  let query =
    Caqti_type.(t4 string string int int64 ->! bool)
      {%string|
        %{chain_of_query}
        SELECT EXISTS (
          SELECT 1 FROM chain
          WHERE state_hash = $2
            AND height = $3
            AND global_slot_since_genesis = $4
        );
      |}
  in
  Conn.find query (tip_hash, check_hash, check_height, check_slot)

let num_of_confirmations (module Conn : CONNECTION) ~latest_state_hash
    ~fork_slot =
  let query =
    Caqti_type.(t2 string int ->! int)
      {%string|
        %{chain_of_query}
        SELECT COUNT(*) FROM chain 
        WHERE global_slot_since_genesis >= $2;
      |}
  in
  Conn.find query (latest_state_hash, fork_slot)

let number_of_commands_since_block_query block_commands_table =
  Caqti_type.(t2 string int ->! t4 string int int int)
    {%string|
      %{chain_of_query}
      SELECT 
          state_hash,
          height,
          global_slot_since_genesis,
          COUNT(bc.block_id) AS command_count
      FROM chain
      LEFT JOIN %{block_commands_table} bc 
          ON chain.id = bc.block_id
      WHERE global_slot_since_genesis >= $2
      GROUP BY 
          state_hash,
          height,
          global_slot_since_genesis;
    |}

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

let last_fork_block (module Conn : CONNECTION) =
  let query =
    Caqti_type.(unit ->! t2 string int64)
      {%string|
        SELECT state_hash, global_slot_since_genesis FROM blocks
        WHERE global_slot_since_hard_fork = 0
        ORDER BY height DESC
        LIMIT 1;
      |}
  in
  Conn.find query ()

let fetch_latest_migration_history (module Conn : CONNECTION) =
  let query =
    Caqti_type.(unit ->? t3 string string string)
      {%string|
        SELECT
          status, protocol_version, migration_version
        FROM migration_history
        ORDER BY commit_start_at DESC
        LIMIT 1;
      |}
  in
  Conn.find_opt query ()

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

let fetch_last_filled_block (module Conn : CONNECTION) =
  let query =
    Caqti_type.(unit ->! t3 string int64 int)
      {%string|
        SELECT b.state_hash, b.global_slot_since_genesis, b.height
        FROM blocks b
        INNER JOIN blocks_internal_commands bic ON b.id = bic.block_id
        ORDER BY b.height DESC
        LIMIT 1;
      |}
  in
  Conn.find query ()
