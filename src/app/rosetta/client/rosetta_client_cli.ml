(* rosetta_client CLI — a curl-on-steroids for the Rosetta API.

   Every subcommand POSTs to a single Rosetta endpoint through the
   [Rosetta_client] library, auto-injects the network_identifier
   ({"blockchain":"mina","network":"testnet"} by default), and prints
   the response as JSON (pretty by default).  On HTTP or transport
   failure, prints a short human-readable diagnostic on stderr and exits
   non-zero; the diagnostic never leaks raw OCaml exception syntax. *)

open Core_kernel
open Async
module MRC = Rosetta_client

(* Operators can set [MINA_ROSETTA_URI] to avoid passing --rosetta-uri on
   every invocation; --rosetta-uri still overrides it when given. *)
let rosetta_uri_env_var = "MINA_ROSETTA_URI"

let default_base_uri =
  Option.value (Sys.getenv rosetta_uri_env_var) ~default:"http://localhost:3087"

let default_blockchain = "mina"

let default_network = "testnet"

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
           default_base_uri rosetta_uri_env_var )
      (optional_with_default default_base_uri string)
  and blockchain =
    flag "--blockchain"
      ~doc:
        (sprintf "NAME network_identifier.blockchain (default: %s)"
           default_blockchain )
      (optional_with_default default_blockchain string)
  and network =
    flag "--network"
      ~doc:
        (sprintf "NAME network_identifier.network (default: %s)" default_network)
      (optional_with_default default_network string)
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
  let s = if g.compact then MRC.Http.compact json else MRC.Http.pretty json in
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
     and index = flag "--index" ~doc:"N Block height" (optional int)
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
     and address =
       flag "--address" ~doc:"B62q... Account address" (required string)
     and token_id = flag "--token-id" ~doc:"ID Token id" (optional string)
     and block_index =
       flag "--index" ~doc:"N Block height (default: latest)" (optional int)
     in
     fun () ->
       run g ~call:(fun c ->
           MRC.Data.account_balance c ~address ?token_id ?block_index () ) )

let cmd_account_coins =
  Command.async ~summary:"POST /account/coins"
    (let%map_open.Command g = global_flags_param
     and address =
       flag "--address" ~doc:"B62q... Account address" (required string)
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
    (let%map_open.Command g = global_flags_param
     and tx_hash =
       flag "--tx-hash" ~doc:"H Transaction hash" (required string)
     in
     fun () -> run g ~call:(fun c -> MRC.Data.mempool_transaction c ~tx_hash) )

let mempool_group =
  Command.group ~summary:"Rosetta /mempool endpoints"
    [ ("list", cmd_mempool_list); ("transaction", cmd_mempool_transaction) ]

let cmd_search_transactions =
  Command.async ~summary:"POST /search/transactions"
    (let%map_open.Command g = global_flags_param
     and address =
       flag "--address" ~doc:"B62q... Filter by account" (optional string)
     and tx_hash = flag "--tx-hash" ~doc:"H Filter by tx hash" (optional string)
     and limit = flag "--limit" ~doc:"N Max results" (optional int) in
     fun () ->
       run g ~call:(fun c ->
           MRC.Data.search_transactions c ?address ?tx_hash ?limit () ) )

let search_group =
  Command.group ~summary:"Rosetta /search/* endpoints"
    [ ("transactions", cmd_search_transactions) ]

(* ---------- Construction API subcommands ---------- *)

let parse_json_flag label s =
  match Or_error.try_with (fun () -> Yojson.Safe.from_string s) with
  | Ok j ->
      Ok j
  | Error _ ->
      Or_error.errorf "%s: invalid JSON" label

let fail_if_error label = function
  | Ok v ->
      v
  | Error e ->
      emit_error (sprintf "%s: %s" label (Error.to_string_hum e)) ;
      Stdlib.exit 1

let cmd_construction_derive =
  Command.async ~summary:"POST /construction/derive"
    (let%map_open.Command g = global_flags_param
     and public_key =
       flag "--public-key-json"
         ~doc:
           "JSON Rosetta PublicKey object (e.g. \
            '{\"hex_bytes\":\"...\",\"curve_type\":\"pallas\"}')"
         (required string)
     and metadata =
       flag "--metadata-json" ~doc:"JSON Optional metadata object"
         (optional string)
     in
     fun () ->
       let pk =
         fail_if_error "--public-key-json"
           (parse_json_flag "--public-key-json" public_key)
       in
       let md =
         Option.map metadata ~f:(fun s ->
             fail_if_error "--metadata-json"
               (parse_json_flag "--metadata-json" s) )
       in
       run g ~call:(fun c ->
           MRC.Construction.derive c ~public_key:pk ?metadata:md () ) )

let cmd_construction_preprocess =
  Command.async ~summary:"POST /construction/preprocess"
    (let%map_open.Command g = global_flags_param
     and operations =
       flag "--operations-json" ~doc:"JSON Operations array" (required string)
     and metadata =
       flag "--metadata-json" ~doc:"JSON Optional metadata object"
         (optional string)
     in
     fun () ->
       let ops =
         fail_if_error "--operations-json"
           (parse_json_flag "--operations-json" operations)
       in
       let md =
         Option.map metadata ~f:(fun s ->
             fail_if_error "--metadata-json"
               (parse_json_flag "--metadata-json" s) )
       in
       run g ~call:(fun c ->
           MRC.Construction.preprocess c ~operations:ops ?metadata:md () ) )

let cmd_construction_metadata =
  Command.async ~summary:"POST /construction/metadata"
    (let%map_open.Command g = global_flags_param
     and options =
       flag "--options-json" ~doc:"JSON Options object" (required string)
     and public_keys =
       flag "--public-keys-json" ~doc:"JSON PublicKey array" (optional string)
     in
     fun () ->
       let opts =
         fail_if_error "--options-json"
           (parse_json_flag "--options-json" options)
       in
       let pks =
         Option.map public_keys ~f:(fun s ->
             fail_if_error "--public-keys-json"
               (parse_json_flag "--public-keys-json" s) )
       in
       run g ~call:(fun c ->
           MRC.Construction.metadata c ~options:opts ?public_keys:pks () ) )

let cmd_construction_payloads =
  Command.async ~summary:"POST /construction/payloads"
    (let%map_open.Command g = global_flags_param
     and operations =
       flag "--operations-json" ~doc:"JSON Operations array" (required string)
     and metadata =
       flag "--metadata-json" ~doc:"JSON Optional metadata object"
         (optional string)
     and public_keys =
       flag "--public-keys-json" ~doc:"JSON PublicKey array" (optional string)
     in
     fun () ->
       let ops =
         fail_if_error "--operations-json"
           (parse_json_flag "--operations-json" operations)
       in
       let md =
         Option.map metadata ~f:(fun s ->
             fail_if_error "--metadata-json"
               (parse_json_flag "--metadata-json" s) )
       in
       let pks =
         Option.map public_keys ~f:(fun s ->
             fail_if_error "--public-keys-json"
               (parse_json_flag "--public-keys-json" s) )
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
             emit_error "--signed and --unsigned are mutually exclusive" ;
             Stdlib.exit 1
         | false, false ->
             emit_error "parse: one of --signed or --unsigned is required" ;
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
     and signatures =
       flag "--signatures-json" ~doc:"JSON Signatures array" (required string)
     in
     fun () ->
       let sigs =
         fail_if_error "--signatures-json"
           (parse_json_flag "--signatures-json" signatures)
       in
       run g ~call:(fun c ->
           MRC.Construction.combine c ~unsigned_transaction ~signatures:sigs )
    )

let cmd_construction_hash =
  Command.async ~summary:"POST /construction/hash"
    (let%map_open.Command g = global_flags_param
     and signed_transaction =
       flag "--signed-transaction" ~doc:"STR Signed tx blob" (required string)
     in
     fun () ->
       run g ~call:(fun c -> MRC.Construction.hash c ~signed_transaction) )

let cmd_construction_submit =
  Command.async ~summary:"POST /construction/submit"
    (let%map_open.Command g = global_flags_param
     and signed_transaction =
       flag "--signed-transaction" ~doc:"STR Signed tx blob" (required string)
     in
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

(* ---------- Config subcommands ---------- *)

let cmd_config_show =
  Command.basic ~summary:"Print an embedded rosetta-cli config file to stdout"
    (let%map_open.Command file =
       flag "--file"
         ~doc:
           (sprintf
              "NAME Which embedded config to print (default: config.json; \
               available: %s)"
              (MRC.Config.names ()) )
         (optional_with_default "config.json" string)
     in
     fun () ->
       match MRC.Config.find_by_name file with
       | None ->
           Stdlib.prerr_string
             (sprintf "unknown embedded config %S; available: %s\n" file
                (MRC.Config.names ()) ) ;
           Stdlib.flush Stdlib.stderr ;
           Stdlib.exit 2
       | Some f ->
           Stdlib.print_string (MRC.Config.contents f) ;
           Stdlib.flush Stdlib.stdout )

let cmd_config_export =
  Command.basic
    ~summary:"Write all embedded rosetta-cli config files into a directory"
    (let%map_open.Command out_dir =
       flag "--out-dir" ~doc:"DIR Target directory (created if missing)"
         (required string)
     in
     fun () ->
       match MRC.Config.export_to_dir ~dir:out_dir with
       | Ok paths ->
           List.iter paths ~f:print_endline
       | Error e ->
           Stdlib.prerr_string (Error.to_string_hum e ^ "\n") ;
           Stdlib.flush Stdlib.stderr ;
           Stdlib.exit 2 )

let config_group =
  Command.group ~summary:"Embedded rosetta-cli config accessors"
    [ ("show", cmd_config_show); ("export", cmd_config_export) ]

(* ---------- Top-level ---------- *)

let () =
  Command.run
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
       ; ("config", config_group)
       ] )
