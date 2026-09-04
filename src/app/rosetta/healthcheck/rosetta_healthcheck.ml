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

   The connection flags, the environment variables that override their
   defaults and the values behind those live in [Rosetta_client.Flags],
   and are shared with [rosetta-client], so the two binaries cannot
   drift apart on what [--rosetta-uri] or [--timeout] means. *)

open Core
open Async
module MRC = Rosetta_client
module RM = MRC.Models
module Out = Health_output
module Probes = Health_probes

(* Oldest tip, in seconds, that [tip-recency] and [ready] still call
   healthy.  360s is two 3-minute slots. *)
let default_max_age = 360

(* How long [wait] keeps polling before it gives up, in seconds. *)
let default_deadline = 600

(* Seconds [wait] sleeps between two readiness attempts. *)
let default_interval = 10

(* ---------- Flags ---------- *)

(* A bound on a numeric flag, checked while the arguments are parsed
   and before a single request goes out.  Rejecting beats clamping: the
   values below the floor are not merely unusual but incoherent --
   [--interval 0] asks for a poll loop with no pause at all, which turns
   a probe into a load generator against the server it is meant to check
   and invalidates the descriptor-budget argument in the README -- and
   an operator who typed one should be told, not quietly given
   something else.

   The message is printed and the process exits here rather than being
   raised: [Command] renders an escaping exception as [(Failure "...")],
   and raw OCaml exception syntax in user-visible output is the one
   thing this binary promises never to print.  It goes out plainly
   rather than through [Logger], which is not registered until a
   subcommand body runs -- the same order [mina_archive_healthcheck]
   reports its own usage error in.

   Exit 2, not 1: 1 is the probe's answer, and an orchestrator that
   reads a mistyped flag as "the server is not ready" retries a
   condition no amount of waiting will fix. *)
let reject name ~must_be ~got =
  Stdlib.prerr_endline (sprintf "%s must be %s, got %s" name must_be got) ;
  Stdlib.exit 2

let seconds_at_least ~name ~minimum param =
  Command.Param.map param ~f:(fun value ->
      if value < minimum then
        reject name
          ~must_be:
            (sprintf "at least %d second%s" minimum
               (if minimum = 1 then "" else "s") )
          ~got:(Int.to_string value)
      else value )

let positive_seconds ~name param =
  Command.Param.map param ~f:(fun value ->
      if Float.( <= ) value 0.0 then
        reject name ~must_be:"a positive number of seconds"
          ~got:(sprintf "%g" value)
      else value )

let client_flag =
  MRC.Flags.client
    ~timeout:
      (positive_seconds ~name:"--timeout"
         (MRC.Flags.timeout ~default:MRC.Defaults.http_timeout) )

(* The blockchain/network the client was pointed at, for the probes that
   check the server advertises them. *)
let expected client =
  let id = MRC.Http.network_identifier client in
  (id.RM.Network_identifier.blockchain, id.RM.Network_identifier.network)

let json_flag =
  Command.Param.(
    flag "--json" ~aliases:[ "-j" ] ~doc:" Output as JSON instead of text"
      no_arg )

let max_age_flag =
  Command.Param.(
    flag "--max-age"
      ~doc:
        (sprintf "SECONDS Maximum acceptable age of current tip (default: %d)"
           default_max_age )
      (optional_with_default default_max_age int) )
  |> seconds_at_least ~name:"--max-age" ~minimum:0

(* [wait]'s bound on the whole polling loop, as opposed to [--timeout]
   which bounds one exchange within it. *)
let deadline_flag =
  Command.Param.(
    flag "--deadline" ~aliases:[ "-d" ]
      ~doc:
        (sprintf "SECONDS Max seconds to keep polling (default: %d)"
           default_deadline )
      (optional_with_default default_deadline int) )
  |> seconds_at_least ~name:"--deadline" ~minimum:1

let interval_flag =
  Command.Param.(
    flag "--interval" ~aliases:[ "-i" ]
      ~doc:(sprintf "SECONDS Polling interval (default: %d)" default_interval)
      (optional_with_default default_interval int) )
  |> seconds_at_least ~name:"--interval" ~minimum:1

(* ---------- Output ---------- *)

(* Stdout is the result channel.  We bypass Async's own [print_*]
   wrappers (which use non-blocking writers that may not flush before a
   subsequent [Stdlib.exit]) by going straight to [Stdlib.stdout], and
   flush explicitly so the result appears even when we exit without
   going through Async's shutdown path. *)
let output_line line =
  Stdlib.print_string line ;
  Stdlib.print_newline () ;
  Stdlib.flush Stdlib.stdout

let output json = output_line (Yojson.Safe.pretty_to_string json)

(* Diagnostics go to stderr through [Logger], which is where every other
   Mina binary sends them, so a rosetta-healthcheck run in a pod is
   collected and filtered like the daemon beside it.  Stdout stays the
   result channel: the probe verdict goes out through [output] above and
   nothing else joins it there.

   The processor follows [--json], as [mina_archive_healthcheck] does:
   a caller that asked for a machine-readable verdict gets
   machine-readable diagnostics beside it rather than prose.

   The interpolation cap is high enough to hold what the probes produce
   -- three problems, each naming a URL -- because a value that exceeds
   it is dropped from the line and printed under it, which for a
   progress line is worse than the quotes interpolation adds.  The
   metadata is rendered compactly for the same reason: [problems] is a
   list, and pretty-printing it would spread one attempt over five
   lines. *)
let logger = Logger.create ~id:"rosetta-healthcheck" ()

let setup_logging ~json =
  Logger.Consumer_registry.register ~id:"rosetta-healthcheck"
    ~processor:
      ( if json then Logger.Processor.raw ~log_level:Logger.Level.Info ()
        else
          Logger.Processor.pretty ~log_level:Logger.Level.Info
            ~config:
              { Interpolator_lib.Interpolator.mode = Inline
              ; max_interpolation_length = 4096
              ; pretty_print = false
              } )
    ~transport:(Logger.Transport.raw Stdlib.prerr_endline)
    ()

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
    }

(* ---------- connectivity ---------- *)

let connectivity_command =
  Command.async
    ~summary:
      "Verify Rosetta's /network/list advertises the expected network.  Lists \
       the advertised set when the expected network is absent."
    (let%map_open.Command client = client_flag and json = json_flag in
     fun () ->
       let blockchain, network = expected client in
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
    (let%map_open.Command client = client_flag
     and json = json_flag
     and max_age = max_age_flag in
     fun () ->
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
    (let%map_open.Command client = client_flag
     and json = json_flag
     and max_age = max_age_flag in
     fun () ->
       let blockchain, network = expected client in
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
    ~summary:"Block until Rosetta passes readiness checks or --deadline expires"
    (let%map_open.Command client = client_flag
     and json = json_flag
     and max_age = max_age_flag
     and deadline_secs = deadline_flag
     and interval = interval_flag in
     fun () ->
       setup_logging ~json ;
       let blockchain, network = expected client in
       let start = Time_float.now () in
       let deadline =
         Time_float.add start (Time_float.Span.of_int_sec deadline_secs)
       in
       let timed_out () = Time_float.( >= ) (Time_float.now ()) deadline in
       let elapsed () =
         Float.to_int
           (Time_float.Span.to_sec (Time_float.diff (Time_float.now ()) start))
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
           (* The problems go as metadata, not in the message: they
              carry server text verbatim, and a "$" in a log message is
              read as an interpolation with nothing behind it, which
              makes Logger replace the whole line. *)
           [%log info] "not ready after $elapsed_seconds s: $problems"
             ~metadata:
               [ ("elapsed_seconds", `Int (elapsed ()))
               ; ( "problems"
                 , `List
                     (List.map result.Probes.problems ~f:(fun problem ->
                          `String problem ) ) )
               ] ;
           (* Never sleep past the deadline: a plain [--interval] nap
              would let [--deadline 600 --interval 300] run for 900s
              before reporting that it had timed out. *)
           let%bind () =
             after
               (Time_float.Span.min
                  (Time_float.Span.of_int_sec interval)
                  (Time_float.diff deadline (Time_float.now ())) )
           in
           loop () )
       in
       loop () )

let () =
  Command_unix.run
    (Command.group
       ~summary:
         "Mina Rosetta healthcheck CLI — readiness and recency probes. For \
          generic Rosetta API calls use 'rosetta-client'."
       [ ("ready", ready_command)
       ; ("wait", wait_command)
       ; ("tip-recency", tip_recency_command)
       ; ("connectivity", connectivity_command)
       ] )
