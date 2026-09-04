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

   The connection flags, the environment variables that override their
   defaults and the values behind those live in [Rosetta_client.Flags],
   and are shared with [rosetta-healthcheck]. *)

open Core
open Async
module MRC = Rosetta_client
module RM = MRC.Models

(* Seconds allowed for one request/response exchange with the Rosetta
   server, from sending the request to reading the last byte of the
   response body.  This is deliberately longer than
   [MRC.Defaults.http_timeout]: a healthcheck probe wants a quick verdict,
   whereas this CLI is used interactively for queries such as a
   /search/transactions sweep that legitimately take much longer than a
   probe would wait. *)
let default_timeout = 30.0

(* ---------- Global flags shared by every leaf command ---------- *)

(* A record that every subcommand's [let%map_open] can pull in with a
   single line.  Keeps per-command preludes short.  The connection flags
   -- and the environment variables behind them -- belong to
   [MRC.Flags], which hands back a client already built from them. *)
type global_flags = { client : MRC.Http.t; compact : bool }

let global_flags_param =
  let open Command.Let_syntax in
  let%map client =
    MRC.Flags.client ~timeout:(MRC.Flags.timeout ~default:default_timeout)
  and compact =
    Command.Param.flag "--compact"
      ~doc:" Emit compact JSON instead of indented (pretty)"
      Command.Param.no_arg
  in
  { client; compact }

(* Single JSON record on stdout, with a trailing newline.  Stdout is
   this CLI's data channel -- scripts/tests/rosetta-helper.sh pipes it
   straight into jq -- so the payload goes out raw, unprefixed and
   unlabelled.  Diagnostics go the other way, through [Logger] below. *)
let emit_json g json =
  let s =
    if g.compact then Yojson.Safe.to_string json
    else Yojson.Safe.pretty_to_string json
  in
  Stdlib.print_string s ; Stdlib.print_newline () ; Stdlib.flush Stdlib.stdout

(* Diagnostics go to stderr through [Logger], which is where every other
   Mina binary sends them, so a rosetta-client run in a pod is collected
   and filtered like the daemon beside it.

   The interpolation cap is high enough to hold any diagnostic the
   library produces (a body is truncated to [Errors.max_body_chars]),
   because a message that exceeds it is dropped from the line and
   printed under it -- which for a one-line CLI error is worse than the
   quotes interpolation adds. *)
let logger = Logger.create ~id:"rosetta-client" ()

let setup_logging () =
  Logger.Consumer_registry.register ~id:"rosetta-client"
    ~processor:
      (Logger.Processor.pretty ~log_level:Logger.Level.Info
         ~config:
           { Interpolator_lib.Interpolator.mode = Inline
           ; max_interpolation_length = 4096
           ; pretty_print = true
           } )
    ~transport:(Logger.Transport.raw Stdlib.prerr_endline)
    ()

(* As metadata, not as the message: a server's error text reaches us
   verbatim, and Postgres and GraphQL errors -- which Mina's Rosetta
   propagates into the envelope -- are full of "$1" placeholders.  A "$"
   in a log message is either an interpolation with no metadata behind it
   or a parse failure, and either way Logger replaces the whole line with
   "invalid log call: " and the "$"s rewritten to ".".

   The text comes from the library's error formatters, so no raw OCaml
   exception syntax reaches the log. *)
let log_error msg = [%log error] "$error" ~metadata:[ ("error", `String msg) ]

(* Run a client call, emit the result as JSON (or the error on stderr
   and exit 1).  Wraps the "happy path" so each leaf command stays a
   one-liner. *)
let run g ~(call : MRC.Http.t -> Yojson.Safe.t Deferred.Or_error.t) =
  match%map call g.client with
  | Ok j ->
      emit_json g j
  | Error e ->
      log_error (Error.to_string_hum e) ;
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

let metadata_json_flag =
  Command.Param.(
    flag "--metadata-json" ~doc:"JSON Optional metadata object"
      (optional string) )

let operations_json_flag =
  Command.Param.(
    flag "--operations-json" ~doc:"JSON Operations array" (required string) )

let public_keys_json_flag =
  Command.Param.(
    flag "--public-keys-json" ~doc:"JSON PublicKey array" (optional string) )

let signed_transaction_flag =
  Command.Param.(
    flag "--signed-transaction" ~doc:"STR Signed tx blob" (required string) )

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
           log_error "block get: one of --index or --hash is required" ;
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

(* Note: there is no [account coins] subcommand.  Mina's Rosetta server
   does not implement /account/coins -- it routes /account/balance and
   404s the rest -- and the coins model is a UTXO notion that an
   account-based chain has nothing to say about, which is why
   /network/options advertises "mempool_coins": false. *)

let account_group =
  Command.group ~summary:"Rosetta /account/* endpoints"
    [ ("balance", cmd_account_balance) ]

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

(* ---------- Construction API subcommands ---------- *)

(* [MRC.Payload] reports a bad flag as an error; this is where that
   error becomes a diagnostic on stderr and a non-zero exit. *)
let or_exit = function
  | Ok value ->
      value
  | Error e ->
      log_error (Error.to_string_hum e) ;
      Stdlib.exit 1

(* The model a JSON flag decodes into, paired with the encoder the
   unknown-field check needs. *)
let public_key = ([%of_yojson: RM.Public_key.t], [%to_yojson: RM.Public_key.t])

let public_keys =
  ([%of_yojson: RM.Public_key.t list], [%to_yojson: RM.Public_key.t list])

let operations =
  ([%of_yojson: RM.Operation.t list], [%to_yojson: RM.Operation.t list])

let signatures =
  ([%of_yojson: RM.Signature.t list], [%to_yojson: RM.Signature.t list])

let model_flag label (of_yojson, to_yojson) s =
  or_exit (MRC.Payload.model ~label ~of_yojson ~to_yojson s)

(* [metadata] and [options] stay raw JSON: the Rosetta schema leaves both
   free-form apart from requiring an object, so there is no model to
   decode them into. *)
let object_flag label s = or_exit (MRC.Payload.json_object ~label s)

let cmd_construction_derive =
  Command.async ~summary:"POST /construction/derive"
    (let%map_open.Command g = global_flags_param
     and pk_json =
       flag "--public-key-json"
         ~doc:
           "JSON Rosetta PublicKey object (e.g. \
            '{\"hex_bytes\":\"...\",\"curve_type\":\"pallas\"}')"
         (required string)
     and metadata = metadata_json_flag in
     fun () ->
       let pk = model_flag "--public-key-json" public_key pk_json in
       let md = Option.map metadata ~f:(object_flag "--metadata-json") in
       run g ~call:(fun c ->
           MRC.Construction.derive c ~public_key:pk ?metadata:md () ) )

let cmd_construction_preprocess =
  Command.async ~summary:"POST /construction/preprocess"
    (let%map_open.Command g = global_flags_param
     and ops_json = operations_json_flag
     and metadata = metadata_json_flag in
     fun () ->
       let ops = model_flag "--operations-json" operations ops_json in
       let md = Option.map metadata ~f:(object_flag "--metadata-json") in
       run g ~call:(fun c ->
           MRC.Construction.preprocess c ~operations:ops ?metadata:md () ) )

let cmd_construction_metadata =
  Command.async ~summary:"POST /construction/metadata"
    (let%map_open.Command g = global_flags_param
     and options =
       flag "--options-json" ~doc:"JSON Options object" (required string)
     and pks_json = public_keys_json_flag in
     fun () ->
       let opts = object_flag "--options-json" options in
       let pks =
         Option.map pks_json ~f:(model_flag "--public-keys-json" public_keys)
       in
       run g ~call:(fun c ->
           MRC.Construction.metadata c ~options:opts ?public_keys:pks () ) )

let cmd_construction_payloads =
  Command.async ~summary:"POST /construction/payloads"
    (let%map_open.Command g = global_flags_param
     and ops_json = operations_json_flag
     and metadata = metadata_json_flag
     and pks_json = public_keys_json_flag in
     fun () ->
       let ops = model_flag "--operations-json" operations ops_json in
       let md = Option.map metadata ~f:(object_flag "--metadata-json") in
       let pks =
         Option.map pks_json ~f:(model_flag "--public-keys-json" public_keys)
       in
       run g ~call:(fun c ->
           MRC.Construction.payloads c ~operations:ops ?metadata:md
             ?public_keys:pks () ) )

let cmd_construction_parse =
  Command.async ~summary:"POST /construction/parse"
    (let%map_open.Command g = global_flags_param
     and signed = flag "--signed" ~doc:" Transaction is signed" no_arg
     and unsigned = flag "--unsigned" ~doc:" Transaction is unsigned" no_arg
     and transaction =
       flag "--transaction" ~doc:"STR Transaction blob" (required string)
     in
     fun () ->
       let signed =
         match (signed, unsigned) with
         | true, true ->
             log_error "--signed and --unsigned are mutually exclusive" ;
             Stdlib.exit 1
         | false, false ->
             log_error "parse: one of --signed or --unsigned is required" ;
             Stdlib.exit 1
         | true, false ->
             true
         | false, true ->
             false
       in
       run g ~call:(fun c -> MRC.Construction.parse c ~signed ~transaction) )

let cmd_construction_combine =
  Command.async ~summary:"POST /construction/combine"
    (let%map_open.Command g = global_flags_param
     and unsigned_transaction =
       flag "--unsigned-transaction" ~doc:"STR Unsigned tx blob"
         (required string)
     and sigs_json =
       flag "--signatures-json" ~doc:"JSON Signatures array" (required string)
     in
     fun () ->
       let sigs = model_flag "--signatures-json" signatures sigs_json in
       run g ~call:(fun c ->
           MRC.Construction.combine c ~unsigned_transaction ~signatures:sigs )
    )

let cmd_construction_hash =
  Command.async ~summary:"POST /construction/hash"
    (let%map_open.Command g = global_flags_param
     and signed_transaction = signed_transaction_flag in
     fun () ->
       run g ~call:(fun c -> MRC.Construction.hash c ~signed_transaction) )

let cmd_construction_submit =
  Command.async ~summary:"POST /construction/submit"
    (let%map_open.Command g = global_flags_param
     and signed_transaction = signed_transaction_flag in
     fun () ->
       run g ~call:(fun c -> MRC.Construction.submit c ~signed_transaction) )

let construction_group =
  Command.group ~summary:"Rosetta /construction/* endpoints"
    [ ("derive", cmd_construction_derive)
    ; ("preprocess", cmd_construction_preprocess)
    ; ("metadata", cmd_construction_metadata)
    ; ("payloads", cmd_construction_payloads)
    ; ("parse", cmd_construction_parse)
    ; ("combine", cmd_construction_combine)
    ; ("hash", cmd_construction_hash)
    ; ("submit", cmd_construction_submit)
    ]

(* ---------- Top-level ---------- *)

(* Everything this CLI reports goes through [Logger], but not everything
   the binary prints: [Command_unix.run] writes its own parse errors
   ("unknown flag --bogus") straight to stderr and exits, and exposes no
   hook to intercept them -- [when_parsing_succeeds] is the only
   callback, and it fires after a successful parse.  Capturing those
   would mean reimplementing the runner around an exception Core does
   not export, so they stay as Core writes them: one line, on stderr,
   before any request is made. *)
let () =
  setup_logging () ;
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
       ; ("construction", construction_group)
       ] )
