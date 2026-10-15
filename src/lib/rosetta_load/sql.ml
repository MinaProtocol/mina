(* Archive queries the load tool needs: request arguments sampled from the
   archive, and a block count. Same shape as [Archive_health_queries]. *)

open Core
open Async

type pool = (Caqti_async.connection, Caqti_error.t) Mina_caqti.Pool.t

let connect uri =
  Mina_caqti.connect_pool ~max_size:4 uri
  |> Result.map_error ~f:(fun e -> Error.of_string (Caqti_error.show e))
  |> Deferred.return

let use (pool : pool) f =
  Mina_caqti.Pool.use f pool
  >>| Result.map_error ~f:(fun e -> Error.of_string (Caqti_error.show e))

module Block_count = struct
  let query =
    Mina_caqti.find_req Caqti_type.unit Caqti_type.int
      "SELECT COUNT(*) FROM blocks"

  let run (module Conn : Mina_caqti.CONNECTION) () = Conn.find query ()
end

(* Random rather than the first rows, so a run spreads over the whole archive
   instead of its genesis corner. Each sample is one probe: a random id between
   1 and the table's largest, and the nearest row from that id whose block is
   canonical, searched upwards first and then downwards, so a probe finds a row
   whenever the table has one. A probe walks the primary key and the block
   links by index, so its cost does not grow with the archive, as a random sort
   of every row would. Probes that land on the same row give one sample, so a
   query returns at most [limit] values.

   Everything comes from canonical blocks: rosetta's search only returns
   canonical transactions (and pending ones above the canonical tip), and a
   public key in the archive need not be a MINA account in the ledger. *)
module Sample = struct
  (* [g * 0] ties the start id to its row of [generate_series], so [random ()]
     runs once per probe. [LIMIT 1] over the two branches stops at the first
     row found. *)
  let probes ~table ~select ~from ~canonical =
    sprintf
      {sql| SELECT DISTINCT probe.value
            FROM generate_series(1, $1) g
            CROSS JOIN LATERAL
              (SELECT g * 0 + floor(random() * (SELECT max(id) FROM %s)) AS id)
              start
            CROSS JOIN LATERAL
              ((SELECT %s AS value FROM %s
                WHERE x.id >= start.id AND %s
                ORDER BY x.id LIMIT 1)
               UNION ALL
               (SELECT %s AS value FROM %s
                WHERE x.id < start.id AND %s
                ORDER BY x.id DESC LIMIT 1)
               LIMIT 1) probe |sql}
      table select from canonical select from canonical

  let block =
    Mina_caqti.collect_req Caqti_type.int Caqti_type.string
      (probes ~table:"blocks" ~select:"x.state_hash" ~from:"blocks x"
         ~canonical:"x.chain_status = 'canonical'" )

  let mina_account =
    Mina_caqti.collect_req
      Caqti_type.(t2 int string)
      Caqti_type.string
      (probes ~table:"account_identifiers" ~select:"pk.value"
         ~from:
           "account_identifiers x JOIN public_keys pk ON pk.id = \
            x.public_key_id"
         ~canonical:
           "x.token_id = (SELECT id FROM tokens WHERE value = $2) AND EXISTS \
            (SELECT 1 FROM accounts_accessed aa JOIN blocks b ON b.id = \
            aa.block_id WHERE aa.account_identifier_id = x.id AND \
            b.chain_status = 'canonical')" )

  let payment_transaction =
    Mina_caqti.collect_req Caqti_type.int Caqti_type.string
      (probes ~table:"user_commands" ~select:"x.hash" ~from:"user_commands x"
         ~canonical:
           "EXISTS (SELECT 1 FROM blocks_user_commands buc JOIN blocks b ON \
            b.id = buc.block_id WHERE buc.user_command_id = x.id AND \
            b.chain_status = 'canonical')" )

  let zkapp_transaction =
    Mina_caqti.collect_req Caqti_type.int Caqti_type.string
      (probes ~table:"zkapp_commands" ~select:"x.hash" ~from:"zkapp_commands x"
         ~canonical:
           "EXISTS (SELECT 1 FROM blocks_zkapp_commands bzc JOIN blocks b ON \
            b.id = bzc.block_id WHERE bzc.zkapp_command_id = x.id AND \
            b.chain_status = 'canonical')" )

  let mina_token = Mina_base.Token_id.(to_string default)

  (* The two network calls take no argument; one empty one stands for it. *)
  let run (module Conn : Mina_caqti.CONNECTION) (endpoint : Endpoint.t) ~limit =
    let collect query = Conn.collect_list query limit in
    match endpoint with
    | Network_status | Network_options ->
        Deferred.Result.return [ "" ]
    | Block ->
        collect block
    | Account_balance ->
        Conn.collect_list mina_account (limit, mina_token)
    | Payment_transaction ->
        collect payment_transaction
    | Zkapp_transaction ->
        collect zkapp_transaction
end

let block_count pool = use pool (fun conn -> Block_count.run conn ())

let sample pool endpoint ~limit =
  use pool (fun conn -> Sample.run conn endpoint ~limit)
