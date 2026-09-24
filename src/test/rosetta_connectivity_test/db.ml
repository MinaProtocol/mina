(* Queries against the archive database the test runs. *)

open Core
open Async

type t = (Caqti_async.connection, Caqti_error.t) Mina_caqti.Pool.t

let connect uri =
  Mina_caqti.connect_pool ~max_size:4 uri
  |> Result.map_error ~f:(fun e -> Error.of_string (Caqti_error.show e))
  |> Deferred.return

let use (t : t) f =
  Mina_caqti.Pool.use f t
  >>| Result.map_error ~f:(fun e -> Error.of_string (Caqti_error.show e))

let block_count t =
  use t (fun (module Conn : Mina_caqti.CONNECTION) ->
      Conn.find
        (Mina_caqti.find_req Caqti_type.unit Caqti_type.int
           "SELECT COUNT(*) FROM blocks" )
        () )

let sample t ~query ~limit =
  use t (fun (module Conn : Mina_caqti.CONNECTION) ->
      Conn.collect_list
        (Mina_caqti.collect_req Caqti_type.int Caqti_type.string query)
        limit )

(* Random rather than the first rows, so a run spreads over the whole
   archive instead of its genesis corner. Accounts and transactions come from
   canonical blocks: rosetta's search only returns canonical transactions (and
   pending ones above the canonical tip), and a public key in the archive need
   not be a MINA account in the ledger. *)
let sample_for (endpoint : Endpoint.t) t ~limit =
  match endpoint with
  | Network_status | Network_options ->
      Deferred.Or_error.return [ "" ]
  | Block ->
      sample t ~limit
        ~query:"SELECT state_hash FROM blocks ORDER BY random() LIMIT ?"
  | Account_balance ->
      sample t ~limit
        ~query:
          "SELECT DISTINCT pk.value FROM (SELECT aa.account_identifier_id FROM \
           accounts_accessed aa JOIN blocks b ON b.id = aa.block_id WHERE \
           b.chain_status = 'canonical' ORDER BY random() LIMIT 10000) aa JOIN \
           account_identifiers ai ON ai.id = aa.account_identifier_id JOIN \
           public_keys pk ON pk.id = ai.public_key_id JOIN tokens t ON t.id = \
           ai.token_id WHERE t.value = \
           'wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf' LIMIT ?"
  | Payment_transaction ->
      sample t ~limit
        ~query:
          "SELECT uc.hash FROM user_commands uc JOIN blocks_user_commands buc \
           ON buc.user_command_id = uc.id JOIN blocks b ON b.id = buc.block_id \
           WHERE b.chain_status = 'canonical' ORDER BY random() LIMIT ?"
  | Zkapp_transaction ->
      sample t ~limit
        ~query:
          "SELECT zc.hash FROM zkapp_commands zc JOIN blocks_zkapp_commands \
           bzc ON bzc.zkapp_command_id = zc.id JOIN blocks b ON b.id = \
           bzc.block_id WHERE b.chain_status = 'canonical' ORDER BY random() \
           LIMIT ?"
