(* rosetta_healthcheck.ml — the CLI surface of the Rosetta health probes.

   This file owns everything the operator sees: the flags, the choice
   between text and JSON, and the exit code.  The probes themselves live
   in [health_probes.ml] and the JSON records they are rendered into in
   [health_output.ml]; neither of those prints or exits.

   This binary focuses exclusively on readiness and recency checks.
   Generic Rosetta API calls live in the sibling [rosetta-client] binary
   so operators don't have to choose between two overlapping CLIs for
   debugging.  HTTP calls go through [Rosetta_client] so
   network_identifier handling, timeout enforcement, and error formatting
   stay in one place.

   Environment variables (each one is overridden by the matching flag,
   and all three are shared with [rosetta-client]):

   - [MINA_ROSETTA_URI] — base URL of the Rosetta server, i.e. the
     default for [--online-uri].
   - [MINA_ROSETTA_BLOCKCHAIN] — default for [--blockchain].
   - [MINA_ROSETTA_NETWORK] — default for [--network].

   The values they fall back to when unset live in
   [Rosetta_client.Defaults], which is also where [rosetta-client] reads
   them from, so the two binaries cannot drift apart. *)

open Core_kernel
open Async
module MRC = Rosetta_client
module RM = MRC.Models
module Out = Health_output
module Probes = Health_probes

(* Probe bounds specific to this binary.  Connection details (URI,
   blockchain, network) and the per-request HTTP timeout come from
   [MRC.Defaults] instead. *)

(* Oldest tip, in seconds, that [tip-recency] and [ready] still call
   healthy.  360s is two 3-minute slots. *)
let default_max_age = 360

(* How long [wait] keeps polling before it gives up, in seconds. *)
let default_timeout = 600

(* Seconds [wait] sleeps between two readiness attempts. *)
let default_interval = 10

(* ---------- Flags ---------- *)

let online_uri_flag =
  Command.Param.(
    flag "--online-uri" ~aliases:[ "-o" ]
      ~doc:
        (sprintf
           "URI Rosetta online base URL (default: %s, overridable via $%s)"
           (MRC.Defaults.base_uri_from_env ())
           MRC.Defaults.uri_env_var )
      (optional_with_default (MRC.Defaults.base_uri_from_env ()) string))

let network_flag =
  Command.Param.(
    flag "--network" ~aliases:[ "-n" ]
      ~doc:
        (sprintf
           "NAME network_identifier.network (default: %s, overridable via $%s)"
           (MRC.Defaults.network_from_env ())
           MRC.Defaults.network_env_var )
      (optional_with_default (MRC.Defaults.network_from_env ()) string))

let blockchain_flag =
  Command.Param.(
    flag "--blockchain"
      ~doc:
        (sprintf
           "NAME network_identifier.blockchain (default: %s, overridable via \
            $%s)"
           (MRC.Defaults.blockchain_from_env ())
           MRC.Defaults.blockchain_env_var )
      (optional_with_default (MRC.Defaults.blockchain_from_env ()) string))

let json_flag =
  Command.Param.(
    flag "--json" ~aliases:[ "-j" ] ~doc:" Output as JSON instead of text"
      no_arg)

let max_age_flag =
  Command.Param.(
    flag "--max-age"
      ~doc:
        (sprintf "SECONDS Maximum acceptable age of current tip (default: %d)"
           default_max_age )
      (optional_with_default default_max_age int))

let timeout_flag ~default =
  Command.Param.(
    flag "--timeout" ~aliases:[ "-t" ]
      ~doc:(sprintf "SECONDS Max seconds to wait (default: %d)" default)
      (optional_with_default default int))

let interval_flag =
  Command.Param.(
    flag "--interval" ~aliases:[ "-i" ]
      ~doc:(sprintf "SECONDS Polling interval (default: %d)" default_interval)
      (optional_with_default default_interval int))

let make_client ~online_uri ~blockchain ~network =
  MRC.Http.create ~base_uri:(Uri.of_string online_uri) ~blockchain ~network
    ~timeout:MRC.Defaults.http_timeout ()

(* ---------- Output ---------- *)

(* Emit a JSON record to stdout.  We bypass Async's own [print_*]
   wrappers (which use non-blocking writers that may not flush before
   a subsequent [Stdlib.exit]) by going straight to [Stdlib.stdout],
   and flush explicitly so the record appears even when we exit without
   going through Async's shutdown path. *)
let output json =
  Stdlib.print_string (Yojson.Safe.pretty_to_string json) ;
  Stdlib.print_newline () ;
  Stdlib.flush Stdlib.stdout

(* The text-mode counterpart of [output], for the same reason: Async's
   [printf] buffers, and that buffer is not flushed by [Stdlib.exit]. *)
let output_line line =
  Stdlib.print_string line ;
  Stdlib.print_newline () ;
  Stdlib.flush Stdlib.stdout

(* Exactly one result per invocation, then exit 1.  Mirrors the contract
   in [mina_archive_healthcheck]: never double-print -- in JSON mode emit
   one record, in text mode one line, and in neither case also hand the
   message back to a [Command] wrapper that would print it again.  The
   two renderings are lazy so only the one that is asked for is built. *)
let fail ~json ~record ~line =
  if json then output (Lazy.force record) else output_line (Lazy.force line) ;
  Stdlib.exit 1

(* A probe that could not reach the server at all.  Both modes say the
   same thing, so each command states it once. *)
let fail_unreachable ~json ~record error =
  let message = Error.to_string_hum error in
  fail ~json ~record:(lazy (record message)) ~line:(lazy message)

let advertised_network_id (network_identifier : RM.Network_identifier.t) =
  { Out.blockchain = network_identifier.RM.Network_identifier.blockchain
  ; network = network_identifier.RM.Network_identifier.network
  }

let readiness_json ?timed_out (result : Probes.readiness) =
  Out.readiness_to_yojson
    { Out.ready = result.Probes.ready
    ; timed_out
    ; block_height =
        Option.map result.Probes.tip ~f:(fun tip -> tip.Probes.height)
    ; age_seconds =
        Option.map result.Probes.tip ~f:(fun tip -> tip.Probes.age_seconds)
    ; problems = result.Probes.problems
    ; error =
        ( if result.Probes.ready then None
        else
          Some
            (sprintf "not ready: %s"
               (String.concat ~sep:", " result.Probes.problems) ) )
    }

(* ---------- connectivity ---------- *)

let connectivity_command =
  Command.async
    ~summary:
      "Verify Rosetta's /network/list advertises the expected network.  Lists \
       the advertised set when the expected network is absent."
    (let%map_open.Command online_uri = online_uri_flag
     and blockchain = blockchain_flag
     and network = network_flag
     and json = json_flag in
     fun () ->
       let client = make_client ~online_uri ~blockchain ~network in
       match%map
         Probes.connectivity client ~expected_blockchain:blockchain
           ~expected_network:network
       with
       | Error e ->
           fail_unreachable ~json e ~record:(fun message ->
               Out.connectivity_to_yojson (Out.connectivity_failed message) )
       | Ok advertised ->
           if json then
             output
               (Out.connectivity_to_yojson
                  { Out.healthy = true
                  ; expected_network = Some network
                  ; advertised = List.map advertised ~f:advertised_network_id
                  ; error = None
                  } )
           else
             output_line
               (sprintf "advertises %d networks (contains %s)"
                  (List.length advertised) network ) )

(* ---------- tip-recency ---------- *)

let tip_recency_command =
  Command.async
    ~summary:
      "POST /network/status — exit 0 if tip is returned and its timestamp is \
       within --max-age"
    (let%map_open.Command online_uri = online_uri_flag
     and blockchain = blockchain_flag
     and network = network_flag
     and json = json_flag
     and max_age = max_age_flag in
     fun () ->
       let client = make_client ~online_uri ~blockchain ~network in
       match%map Probes.tip_recency client ~max_age with
       | Error e ->
           fail_unreachable ~json e ~record:(fun message ->
               Out.tip_recency_to_yojson (Out.tip_recency_failed message) )
       | Ok tip ->
           let record ~healthy ~max_age_field ~error =
             Out.tip_recency_to_yojson
               { Out.healthy
               ; block_height = Some tip.Probes.height
               ; block_hash = Some tip.Probes.hash
               ; age_seconds = Some tip.Probes.age_seconds
               ; max_age = max_age_field
               ; error
               }
           in
           if tip.Probes.fresh then
             if json then
               output (record ~healthy:true ~max_age_field:None ~error:None)
             else
               output_line
                 (sprintf "tip height=%Ld hash=%s age=%Lds" tip.Probes.height
                    tip.Probes.hash tip.Probes.age_seconds )
           else
             let message =
               sprintf "tip is %Ld seconds old, exceeds max age %d"
                 tip.Probes.age_seconds max_age
             in
             fail ~json
               ~record:
                 ( lazy
                   (record ~healthy:false ~max_age_field:(Some max_age)
                      ~error:(Some message) ) )
               ~line:(lazy message) )

(* ---------- ready and wait ---------- *)

let ready_command =
  Command.async
    ~summary:
      "Composite readiness: connectivity + tip-recency + /network/options"
    (let%map_open.Command online_uri = online_uri_flag
     and blockchain = blockchain_flag
     and network = network_flag
     and json = json_flag
     and max_age = max_age_flag in
     fun () ->
       let client = make_client ~online_uri ~blockchain ~network in
       let%map result =
         Probes.readiness client ~expected_blockchain:blockchain
           ~expected_network:network ~max_age
       in
       if result.Probes.ready then
         if json then output (readiness_json result) else output_line "READY"
       else
         fail ~json
           ~record:(lazy (readiness_json result))
           ~line:
             ( lazy
               (sprintf "NOT READY: %s"
                  (String.concat ~sep:", " result.Probes.problems) ) ) )

let wait_command =
  Command.async
    ~summary:"Block until Rosetta passes readiness checks or timeout expires"
    (let%map_open.Command online_uri = online_uri_flag
     and blockchain = blockchain_flag
     and network = network_flag
     and json = json_flag
     and max_age = max_age_flag
     and timeout = timeout_flag ~default:default_timeout
     and interval = interval_flag in
     fun () ->
       let client = make_client ~online_uri ~blockchain ~network in
       let start = Time.now () in
       let deadline = Time.add start (Time.Span.of_int_sec timeout) in
       let timed_out () = Time.( >= ) (Time.now ()) deadline in
       let elapsed () =
         Float.to_int (Time.Span.to_sec (Time.diff (Time.now ()) start))
       in
       let rec loop () =
         let%bind result =
           Probes.readiness client ~expected_blockchain:blockchain
             ~expected_network:network ~max_age
         in
         let problems = String.concat ~sep:", " result.Probes.problems in
         if result.Probes.ready then (
           if json then output (readiness_json result) else output_line "READY" ;
           Deferred.unit )
         else if timed_out () then
           fail ~json
             ~record:(lazy (readiness_json ~timed_out:true result))
             ~line:
               (lazy (sprintf "timed out waiting for readiness: %s" problems))
         else (
           eprintf "[%3ds] not ready: %s\n" (elapsed ()) problems ;
           (* Never sleep past the deadline: a plain [--interval] nap
              would let [--timeout 600 --interval 300] run for 900s
              before reporting that it had timed out. *)
           let%bind () =
             after
               (Time.Span.min
                  (Time.Span.of_int_sec interval)
                  (Time.diff deadline (Time.now ())) )
           in
           loop () )
       in
       loop () )

let () =
  Command.run
    (Command.group
       ~summary:
         "Mina Rosetta healthcheck CLI — readiness and recency probes. For \
          generic Rosetta API calls use 'rosetta-client'."
       [ ("ready", ready_command)
       ; ("wait", wait_command)
       ; ("tip-recency", tip_recency_command)
       ; ("connectivity", connectivity_command)
       ] )
