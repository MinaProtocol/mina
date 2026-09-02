(* rosetta_client CLI — a curl-on-steroids for the Rosetta API.

   This file owns the command-line surface: the flags, the subcommand
   tree, and how a result or an error reaches the terminal.  Everything
   else -- the transport, the request bodies, the error rendering --
   lives in the [rosetta_client] library.

   Every subcommand POSTs to a single Rosetta endpoint through the
   [Rosetta_client] library, auto-injects the network_identifier
   ({"blockchain":"mina","network":"testnet"} by default), and prints
   the response as JSON (pretty by default).  On HTTP or transport
   failure, prints a short human-readable diagnostic on stderr and exits
   non-zero; the diagnostic never leaks raw OCaml exception syntax.

   Environment variables (each one is overridden by the matching flag):

   - [MINA_ROSETTA_URI] — default for [--rosetta-uri].
   - [MINA_ROSETTA_BLOCKCHAIN] — default for [--blockchain].
   - [MINA_ROSETTA_NETWORK] — default for [--network].

   The values they fall back to when unset live in
   [Rosetta_client.Defaults]. *)

open Core
open Async
module MRC = Rosetta_client

(* Seconds allowed for one request/response exchange with the Rosetta
   server, from sending the request to reading the last byte of the
   response body.  This is deliberately longer than
   [MRC.Defaults.http_timeout], which is sized for a readiness probe that
   wants a quick verdict: this CLI is used interactively, for queries such
   as a /search/transactions sweep that legitimately take much longer than
   a probe would wait. *)
let default_timeout = 30.0

(* ---------- Global flags shared by every leaf command ---------- *)

(* A record that every subcommand's [let%map_open] can pull in with a
   single line.  Keeps per-command preludes short. *)
type global_flags =
  { base_uri : string
  ; blockchain : string
  ; network : string
  ; timeout : float
  ; compact : bool
  }

let global_flags_param =
  let open Command.Let_syntax in
  let open Command.Param in
  let%map base_uri =
    flag "--rosetta-uri"
      ~doc:
        (sprintf "URI Rosetta base URL (default: %s, overridable via $%s)"
           (MRC.Defaults.base_uri_from_env ())
           MRC.Defaults.uri_env_var )
      (optional_with_default (MRC.Defaults.base_uri_from_env ()) string)
  and blockchain =
    flag "--blockchain"
      ~doc:
        (sprintf
           "NAME network_identifier.blockchain (default: %s, overridable via \
            $%s)"
           (MRC.Defaults.blockchain_from_env ())
           MRC.Defaults.blockchain_env_var )
      (optional_with_default (MRC.Defaults.blockchain_from_env ()) string)
  and network =
    flag "--network"
      ~doc:
        (sprintf
           "NAME network_identifier.network (default: %s, overridable via $%s)"
           (MRC.Defaults.network_from_env ())
           MRC.Defaults.network_env_var )
      (optional_with_default (MRC.Defaults.network_from_env ()) string)
  and timeout =
    flag "--timeout"
      ~doc:
        (sprintf "SECONDS HTTP request timeout (default: %.0f)" default_timeout)
      (optional_with_default default_timeout float)
  and compact =
    flag "--compact" ~doc:" Emit compact JSON instead of indented (pretty)"
      no_arg
  in
  { base_uri; blockchain; network; timeout; compact }

let client_of_globals g =
  MRC.Http.create ~base_uri:(Uri.of_string g.base_uri) ~blockchain:g.blockchain
    ~network:g.network ~timeout:g.timeout ()

(* Single JSON record on stdout, with a trailing newline.  Bypasses
   Async's [print_*] wrappers so the output flushes even when we take
   the [Stdlib.exit] fast path. *)
let emit_json g json =
  let s =
    if g.compact then Yojson.Safe.to_string json
    else Yojson.Safe.pretty_to_string json
  in
  Stdlib.print_string s ; Stdlib.print_newline () ; Stdlib.flush Stdlib.stdout

let emit_error msg =
  (* No raw OCaml exception text leaks: [msg] is produced by
     [MRC.Errors] formatters or by the CLI itself. *)
  Stdlib.prerr_string (msg ^ "\n") ;
  Stdlib.flush Stdlib.stderr

(* Run a client call, emit the result as JSON (or the error on stderr
   and exit 1).  Wraps the "happy path" so each leaf command stays a
   one-liner. *)
let run g ~(call : MRC.Http.t -> Yojson.Safe.t Deferred.Or_error.t) =
  let client = client_of_globals g in
  match%map call client with
  | Ok j ->
      emit_json g j
  | Error e ->
      emit_error (Error.to_string_hum e) ;
      Stdlib.exit 1

(* ---------- Flags reused by more than one subcommand ---------- *)

(* Defined once here so a flag that means the same thing in two
   subcommands also spells and documents itself the same way. *)

let address_flag =
  Command.Param.(
    flag "--address" ~doc:"B62q... Account address" (required string) )

let address_filter_flag =
  Command.Param.(
    flag "--address" ~doc:"B62q... Filter by account" (optional string) )

let tx_hash_flag =
  Command.Param.(flag "--tx-hash" ~doc:"H Transaction hash" (required string))

let tx_hash_filter_flag =
  Command.Param.(flag "--tx-hash" ~doc:"H Filter by tx hash" (optional string))

let block_index_flag ~doc = Command.Param.(flag "--index" ~doc (optional int))

(* ---------- Data API subcommands ---------- *)

let cmd_network_list =
  Command.async ~summary:"POST /network/list"
    (let%map_open.Command g = global_flags_param in
     fun () -> run g ~call:MRC.Data.network_list )

let cmd_network_status =
  Command.async ~summary:"POST /network/status"
    (let%map_open.Command g = global_flags_param in
     fun () -> run g ~call:MRC.Data.network_status )

let cmd_network_options =
  Command.async ~summary:"POST /network/options"
    (let%map_open.Command g = global_flags_param in
     fun () -> run g ~call:MRC.Data.network_options )

let network_group =
  Command.group ~summary:"Rosetta /network/* endpoints"
    [ ("list", cmd_network_list)
    ; ("status", cmd_network_status)
    ; ("options", cmd_network_options)
    ]

let cmd_block_get =
  Command.async ~summary:"POST /block (by --index or --hash)"
    (let%map_open.Command g = global_flags_param
     and index = block_index_flag ~doc:"N Block height"
     and hash = flag "--hash" ~doc:"H Block state hash" (optional string) in
     fun () ->
       match (index, hash) with
       | None, None ->
           emit_error "block get: one of --index or --hash is required" ;
           Stdlib.exit 1
       | _ ->
           run g ~call:(fun c -> MRC.Data.block c ?index ?hash ()) )

(* Note: there is no [block transaction] subcommand. Mina's Rosetta server
   does not implement /block/transaction (it returns every transaction inline
   in /block, so "other_transactions" is always empty) and would 404 on it.
   Use [block get] and filter the returned transactions by hash instead. *)

let block_group =
  Command.group ~summary:"Rosetta /block endpoints" [ ("get", cmd_block_get) ]

let cmd_account_balance =
  Command.async ~summary:"POST /account/balance"
    (let%map_open.Command g = global_flags_param
     and address = address_flag
     and token_id = flag "--token-id" ~doc:"ID Token id" (optional string)
     and block_index =
       block_index_flag ~doc:"N Block height (default: latest)"
     in
     fun () ->
       run g ~call:(fun c ->
           MRC.Data.account_balance c ~address ?token_id ?block_index () ) )

let cmd_account_coins =
  Command.async ~summary:"POST /account/coins"
    (let%map_open.Command g = global_flags_param
     and address = address_flag
     and include_mempool =
       flag "--include-mempool" ~doc:" Include mempool transactions" no_arg
     in
     fun () ->
       run g ~call:(fun c ->
           MRC.Data.account_coins c ~address ~include_mempool () ) )

let account_group =
  Command.group ~summary:"Rosetta /account/* endpoints"
    [ ("balance", cmd_account_balance); ("coins", cmd_account_coins) ]

let cmd_mempool_list =
  Command.async ~summary:"POST /mempool"
    (let%map_open.Command g = global_flags_param in
     fun () -> run g ~call:MRC.Data.mempool )

let cmd_mempool_transaction =
  Command.async ~summary:"POST /mempool/transaction"
    (let%map_open.Command g = global_flags_param and tx_hash = tx_hash_flag in
     fun () -> run g ~call:(fun c -> MRC.Data.mempool_transaction c ~tx_hash) )

let mempool_group =
  Command.group ~summary:"Rosetta /mempool endpoints"
    [ ("list", cmd_mempool_list); ("transaction", cmd_mempool_transaction) ]

let cmd_search_transactions =
  Command.async ~summary:"POST /search/transactions"
    (let%map_open.Command g = global_flags_param
     and address = address_filter_flag
     and tx_hash = tx_hash_filter_flag
     and limit = flag "--limit" ~doc:"N Max results" (optional int) in
     fun () ->
       run g ~call:(fun c ->
           MRC.Data.search_transactions c ?address ?tx_hash ?limit () ) )

let search_group =
  Command.group ~summary:"Rosetta /search/* endpoints"
    [ ("transactions", cmd_search_transactions) ]

(* ---------- Top-level ---------- *)

let () =
  Command_unix.run
    (Command.group
       ~summary:
         "Mina Rosetta client CLI — curl-on-steroids for a running Rosetta \
          server"
       [ ("network", network_group)
       ; ("block", block_group)
       ; ("account", account_group)
       ; ("mempool", mempool_group)
       ; ("search", search_group)
       ] )
