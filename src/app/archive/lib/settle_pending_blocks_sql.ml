(* The SQL of Settle_pending_blocks. Each query is one statement. *)

open Caqti_request.Infix

let newest_fork_genesis =
  (Caqti_type.unit ->? Caqti_type.int)
    {sql| SELECT id FROM blocks
          WHERE global_slot_since_hard_fork = 0
            AND global_slot_since_genesis > 0
          ORDER BY height DESC
          LIMIT 1
    |sql}

(* $1: a fork genesis. The parent link, or, when it is not set yet, the block
   whose state hash is the genesis's parent hash. *)
let fork_block =
  (Caqti_type.int ->? Caqti_type.int)
    {sql| SELECT COALESCE(g.parent_id, p.id)
          FROM blocks g
          LEFT JOIN blocks p ON p.state_hash = g.parent_hash
          WHERE g.id = $1
            AND COALESCE(g.parent_id, p.id) IS NOT NULL
    |sql}

(* $1: the fork genesis, $2: the fork block. [walk] climbs from the fork block
   to the first canonical ancestor [anchor]; [ended] is everything below the
   anchor except the fork genesis and its descendants. Without an anchor
   nothing changes. *)
let settle_fork =
  (Caqti_type.(t2 int int) ->! Caqti_type.(t3 int int bool))
    {sql|
      WITH RECURSIVE walk (id, parent_id, chain_status) AS (
        SELECT id, parent_id, chain_status FROM blocks WHERE id = $2
        UNION ALL
        SELECT b.id, b.parent_id, b.chain_status
        FROM blocks b
        JOIN walk w ON b.id = w.parent_id
        WHERE w.chain_status <> 'canonical'
      ), anchor AS (
        SELECT id FROM walk WHERE chain_status = 'canonical'
      ), ended (id) AS (
        SELECT b.id FROM blocks b JOIN anchor a ON b.parent_id = a.id
        WHERE b.id <> $1
        UNION
        SELECT b.id FROM blocks b JOIN ended e ON b.parent_id = e.id
        WHERE b.id <> $1
      ), healed AS (
        UPDATE blocks SET chain_status = 'canonical'::chain_status_type
        WHERE id IN (SELECT id FROM walk WHERE chain_status <> 'canonical')
          AND EXISTS (SELECT 1 FROM anchor)
        RETURNING id
      ), cut AS (
        UPDATE blocks SET chain_status = 'orphaned'::chain_status_type
        WHERE id IN (SELECT id FROM ended)
          AND id NOT IN (SELECT id FROM walk)
          AND chain_status <> 'orphaned'
        RETURNING id
      )
      SELECT (SELECT count(*) FROM healed)::int,
             (SELECT count(*) FROM cut)::int,
             EXISTS (SELECT 1 FROM anchor)
    |sql}
