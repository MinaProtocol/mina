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
   instead of its genesis corner. Accounts and transactions come from canonical
   blocks: rosetta's search only returns canonical transactions (and pending
   ones above the canonical tip), and a public key in the archive need not be a
   MINA account in the ledger. Each query takes the sample size. *)
module Sample = struct
  let block =
    Mina_caqti.collect_req Caqti_type.int Caqti_type.string
      {sql| SELECT state_hash FROM blocks ORDER BY random() LIMIT ? |sql}

  let mina_account =
    Mina_caqti.collect_req Caqti_type.int Caqti_type.string
      {sql| SELECT DISTINCT pk.value
            FROM (SELECT aa.account_identifier_id
                  FROM accounts_accessed aa
                  JOIN blocks b ON b.id = aa.block_id
                  WHERE b.chain_status = 'canonical'
                  ORDER BY random() LIMIT 10000) aa
            JOIN account_identifiers ai ON ai.id = aa.account_identifier_id
            JOIN public_keys pk ON pk.id = ai.public_key_id
            JOIN tokens t ON t.id = ai.token_id
            WHERE t.value = 'wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf'
            LIMIT ? |sql}

  let payment_transaction =
    Mina_caqti.collect_req Caqti_type.int Caqti_type.string
      {sql| SELECT uc.hash
            FROM user_commands uc
            JOIN blocks_user_commands buc ON buc.user_command_id = uc.id
            JOIN blocks b ON b.id = buc.block_id
            WHERE b.chain_status = 'canonical'
            ORDER BY random() LIMIT ? |sql}

  let zkapp_transaction =
    Mina_caqti.collect_req Caqti_type.int Caqti_type.string
      {sql| SELECT zc.hash
            FROM zkapp_commands zc
            JOIN blocks_zkapp_commands bzc ON bzc.zkapp_command_id = zc.id
            JOIN blocks b ON b.id = bzc.block_id
            WHERE b.chain_status = 'canonical'
            ORDER BY random() LIMIT ? |sql}

  (* The two network calls take no argument; one empty one stands for it. *)
  let run (module Conn : Mina_caqti.CONNECTION) (endpoint : Endpoint.t) ~limit =
    let collect query = Conn.collect_list query limit in
    match endpoint with
    | Network_status | Network_options ->
        Deferred.Result.return [ "" ]
    | Block ->
        collect block
    | Account_balance ->
        collect mina_account
    | Payment_transaction ->
        collect payment_transaction
    | Zkapp_transaction ->
        collect zkapp_transaction
end

let block_count pool = use pool (fun conn -> Block_count.run conn ())

let sample pool endpoint ~limit =
  use pool (fun conn -> Sample.run conn endpoint ~limit)
