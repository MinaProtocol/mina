(* textformat serialization and runtime metrics taken from github.com/mirage/prometheus:/app/prometheus_app.ml *)
open Core_kernel
open Prometheus

let namespace = "Coda"

module TextFormat_0_0_4 = struct
  let re_unquoted_escapes = Re.compile @@ Re.set "\\\n"

  let re_quoted_escapes = Re.compile @@ Re.set "\"\\\n"

  let quote g =
    match Re.Group.get g 0 with
    | "\\" ->
        "\\\\"
    | "\n" ->
        "\\n"
    | "\"" ->
        "\\\""
    | x ->
        failwithf "Unexpected match %S" x ()

  let output_metric_type f = function
    | Counter ->
        Fmt.string f "counter"
    | Gauge ->
        Fmt.string f "gauge"
    | Summary ->
        Fmt.string f "summary"
    | Histogram ->
        Fmt.string f "histogram"

  let output_unquoted f s =
    Fmt.string f @@ Re.replace re_unquoted_escapes ~f:quote s

  let output_quoted f s =
    Fmt.string f @@ Re.replace re_quoted_escapes ~f:quote s

  let output_value f v =
    let open Float.Class in
    match Float.classify v with
    | Normal | Subnormal | Zero ->
        Fmt.float f v
    | Infinite when v > 0.0 ->
        Fmt.string f "+Inf"
    | Infinite ->
        Fmt.string f "-Inf"
    | Nan ->
        Fmt.string f "Nan"

  let output_pairs f (label_names, label_values) =
    let cont = ref false in
    let output_pair name value =
      if !cont then Fmt.string f ", " else cont := true ;
      Fmt.pf f "%a=\"%a\"" LabelName.pp name output_quoted value
    in
    List.iter2_exn label_names label_values ~f:output_pair

  let output_labels ~label_names f = function
    | [] ->
        ()
    | label_values ->
        Fmt.pf f "{%a}" output_pairs (label_names, label_values)

  let output_sample ~base ~label_names ~label_values f
      {Sample_set.ext; value; bucket} =
    let label_names, label_values =
      match bucket with
      | None ->
          (label_names, label_values)
      | Some (label_name, label_value) ->
          let label_value_str = Fmt.strf "%a" output_value label_value in
          (label_name :: label_names, label_value_str :: label_values)
    in
    Fmt.pf f "%a%s%a %a@." MetricName.pp base ext
      (output_labels ~label_names)
      label_values output_value value

  let output_metric ~name ~label_names f (label_values, samples) =
    List.iter samples
      ~f:(output_sample ~base:name ~label_names ~label_values f)

  let output f =
    MetricFamilyMap.iter (fun metric samples ->
        let {MetricInfo.name; metric_type; help; label_names} = metric in
        Fmt.pf f "#HELP %a %a@.#TYPE %a %a@.%a" MetricName.pp name
          output_unquoted help MetricName.pp name output_metric_type
          metric_type
          (LabelSetMap.pp ~sep:Fmt.nop (output_metric ~name ~label_names))
          samples )
end

module Runtime = struct
  let start_time = Core.Time.now ()

  let current = ref (Gc.stat ())

  let update () = current := Gc.stat ()

  let simple_metric ~metric_type ~help name fn =
    let info =
      {MetricInfo.name= MetricName.v name; help; metric_type; label_names= []}
    in
    let collect () = LabelSetMap.singleton [] [Sample_set.sample (fn ())] in
    (info, collect)

  let ocaml_gc_allocated_bytes =
    simple_metric ~metric_type:Counter "ocaml_gc_allocated_bytes"
      Gc.allocated_bytes
      ~help:"Total number of bytes allocated since the program was started."

  let ocaml_gc_major_words =
    simple_metric ~metric_type:Counter "ocaml_gc_major_words"
      (fun () -> !current.Gc.Stat.major_words)
      ~help:
        "Number of words allocated in the major heap since the program was \
         started."

  let ocaml_gc_minor_collections =
    simple_metric ~metric_type:Counter "ocaml_gc_minor_collections"
      (fun () -> float_of_int !current.Gc.Stat.minor_collections)
      ~help:
        "Number of minor collection cycles completed since the program was \
         started."

  let ocaml_gc_major_collections =
    simple_metric ~metric_type:Counter "ocaml_gc_major_collections"
      (fun () -> float_of_int !current.Gc.Stat.major_collections)
      ~help:
        "Number of major collection cycles completed since the program was \
         started."

  let ocaml_gc_heap_words =
    simple_metric ~metric_type:Gauge "ocaml_gc_heap_words"
      (fun () -> float_of_int !current.Gc.Stat.heap_words)
      ~help:"Total size of the major heap, in words."

  let ocaml_gc_compactions =
    simple_metric ~metric_type:Counter "ocaml_gc_compactions"
      (fun () -> float_of_int !current.Gc.Stat.compactions)
      ~help:"Number of heap compactions since the program was started."

  let ocaml_gc_top_heap_words =
    simple_metric ~metric_type:Counter "ocaml_gc_top_heap_words"
      (fun () -> float_of_int !current.Gc.Stat.top_heap_words)
      ~help:"Maximum size reached by the major heap, in words."

  let ocaml_gc_live_words =
    simple_metric ~metric_type:Counter "ocaml_gc_live_words"
      (fun () -> float_of_int !current.Gc.Stat.live_words)
      ~help:"Live words allocated by the GC."

  let ocaml_gc_free_words =
    simple_metric ~metric_type:Counter "ocaml_gc_free_words"
      (fun () -> float_of_int !current.Gc.Stat.free_words)
      ~help:"Words freed by the GC."

  let ocaml_gc_largest_free =
    simple_metric ~metric_type:Counter "ocaml_gc_largest_free"
      (fun () -> float_of_int !current.Gc.Stat.largest_free)
      ~help:"Size of the largest block freed by the GC."

  let ocaml_gc_stack_size =
    simple_metric ~metric_type:Counter "ocaml_gc_stack_size"
      (fun () -> float_of_int !current.Gc.Stat.stack_size)
      ~help:"Current stack size."

  let process_cpu_seconds_total =
    simple_metric ~metric_type:Counter "process_cpu_seconds_total" Sys.time
      ~help:"Total user and system CPU time spent in seconds."

  let process_uptime_ms_total =
    simple_metric ~metric_type:Counter "process_uptime_ms_total"
      (fun () ->
        Core.Time.Span.to_ms (Core.Time.diff (Core.Time.now ()) start_time) )
      ~help:"Total time the process has been running for in milliseconds."

  let metrics =
    [ ocaml_gc_allocated_bytes
    ; ocaml_gc_major_words
    ; ocaml_gc_minor_collections
    ; ocaml_gc_major_collections
    ; ocaml_gc_heap_words
    ; ocaml_gc_compactions
    ; ocaml_gc_top_heap_words
    ; ocaml_gc_live_words
    ; ocaml_gc_free_words
    ; ocaml_gc_largest_free
    ; ocaml_gc_stack_size
    ; process_cpu_seconds_total
    ; process_uptime_ms_total ]

  let () =
    let open CollectorRegistry in
    register_pre_collect default update ;
    List.iter metrics ~f:(fun (info, collector) ->
        register default info collector )
end

module Cryptography = struct
  let subsystem = "Cryptography"

  let blockchain_proving_time_ms =
    let help =
      "time elapsed while proving most recently generated blockchain snark"
    in
    Gauge.v "blockchain_proving_time_ms" ~help ~namespace ~subsystem

  let total_pedersen_hashes_computed =
    let help = "# of pedersen hashes computed" in
    Counter.v "total_pedersen_hash_computed" ~help ~namespace ~subsystem

  (* TODO:
  let transaction_proving_time_ms =
    let help = "time elapsed while proving most recently generated transaction snark" in
    Gauge.v "transaction_proving_time_ms" ~help ~namespace ~subsystem
  *)
end

module Bootstrap = struct
  let subsystem = "Bootstrap"

  let bootstrap_time_ms =
    let help = "time elapsed while bootstrapping" in
    Gauge.v "bootstrap_time_ms" ~help ~namespace ~subsystem
end

(* TODO:
module Transaction_pool = struct
  let subsystem = "Transaction_pool"
end

module Snark_pool = struct
  let subsystem = "Snark_pool"
end
*)

module Network = struct
  let subsystem = "Network"

  let peers : Gauge.t =
    let help = "# of peers seen through gossip net" in
    Gauge.v "peers" ~help ~namespace ~subsystem

  let gossip_messages_received : Counter.t =
    let help = "# of messages received" in
    Counter.v "messages_received" ~help ~namespace ~subsystem

  module Rpc_map = Hashtbl.Make (String)

  module Rpc_histogram = Histogram (struct
    let spec = Histogram_spec.of_exponential 500. 2. 7
  end)

  let rpc_table = Rpc_map.of_alist_exn []

  let rpc_latency_ms ~name : Gauge.t =
    if Rpc_map.mem rpc_table name then Rpc_map.find_exn rpc_table name
    else
      let help = "time elapsed while doing rpc calls in ms" in
      let rpc_gauge = Gauge.v name ~help ~namespace ~subsystem in
      Rpc_map.add_exn rpc_table ~key:name ~data:rpc_gauge ;
      rpc_gauge

  let rpc_latency_ms_summary : Rpc_histogram.t =
    let help = "A histogram for all rpc call latencies" in
    Rpc_histogram.v "rpc_latency_ms_summary" ~help ~namespace ~subsystem
end

module Snark_work = struct
  let subsystem = "Snark_work"

  let completed_snark_work_received_gossip : Counter.t =
    let help = "# of completed snark work bundles received from peers" in
    Counter.v "completed_snark_work_received_gossip" ~help ~namespace
      ~subsystem

  let completed_snark_work_received_rpc : Counter.t =
    let help = "# of completed snark work bundles received via rpc" in
    Counter.v "completed_snark_work_received_rpc" ~help ~namespace ~subsystem

  let snark_work_assigned_rpc : Counter.t =
    let help = "# of snark work bundles assigned via rpc" in
    Counter.v "snark_work_assigned_rpc" ~help ~namespace ~subsystem

  let snark_work_timed_out_rpc : Counter.t =
    let help =
      "# of snark work bundles sent via rpc that did not complete within the \
       value of the daemon flag work-reassignment-wait"
    in
    Counter.v "snark_work_timed_out_rpc" ~help ~namespace ~subsystem

  let snark_pool_size : Gauge.t =
    let help = "# of completed snark work bundles in the snark pool" in
    Gauge.v "snark_pool_size" ~help ~namespace ~subsystem

  let completed_snark_work_last_block : Gauge.t =
    let help = "# of snark work bundles purchased per block" in
    Gauge.v "completed_snark_work_last_block" ~help ~namespace ~subsystem

  let scan_state_snark_work : Gauge.t =
    let help =
      "# of snark work in the scan state that are yet to be done/purchased \
       after every block"
    in
    Gauge.v "scan_state_snark_work" ~help ~namespace ~subsystem
end

module Trust_system = struct
  let subsystem = "Trust_system"

  let banned_peers : Gauge.t =
    let help = "# of banned ip addresses" in
    Gauge.v "banned_peers" ~help ~namespace ~subsystem
end

module Consensus = struct
  let subsystem = "Consensus"

  (* TODO:
  let vrf_threshold =
    let help = "vrf threshold expressed as % to win (in range 0..1)" in
    Gauge.v "vrf_threshold" ~help ~namespace ~subsystem
  *)

  let vrf_evaluations : Counter.t =
    let help = "vrf evaluations performed" in
    Counter.v "vrf_evaluations" ~help ~namespace ~subsystem

  let staking_keypairs : Gauge.t =
    let help = "# of actively staking keypairs" in
    Gauge.v "staking_keypairs" ~help ~namespace ~subsystem

  let stake_delegators : Gauge.t =
    let help =
      "# of delegators the node is evaluating vrfs for (in addition to \
       evaluations for staking keypairs)"
    in
    Gauge.v "stake_delegators" ~help ~namespace ~subsystem
end

module Proposer = struct
  let subsystem = "Proposer"

  let slots_won : Counter.t =
    let help =
      "slots which the proposer has won (does not represent that a proposer \
       actually proposed)"
    in
    Counter.v "slots_won" ~help ~namespace ~subsystem

  let blocks_proposed : Counter.t =
    let help = "blocks produced and submitted by the proposer" in
    Counter.v "blocks_proposed" ~help ~namespace ~subsystem
end

module Transition_frontier = struct
  let subsystem = "Transition_frontier"

  let slot_fill_rate : Gauge.t =
    let help = "number of blocks / total slots since genesis" in
    Gauge.v "slot_fill_rate" ~help ~namespace ~subsystem

  let active_breadcrumbs : Gauge.t =
    let help = "current # of breadcrumbs in the transition frontier" in
    Gauge.v "active_breadcrumbs" ~help ~namespace ~subsystem

  let total_breadcrumbs : Counter.t =
    let help =
      "monotonically increasing # of breadcrumbs added to transition frontier"
    in
    Counter.v "total_breadcrumbs" ~help ~namespace ~subsystem

  let root_transitions : Counter.t =
    let help =
      "# of root transitions (finalizations) performed in transition frontier"
    in
    Counter.v "root_transitions" ~help ~namespace ~subsystem

  let finalized_staged_txns : Counter.t =
    let help = "total # of staged txns that have been finalized" in
    Counter.v "finalized_staged_txns" ~help ~namespace ~subsystem

  let recently_finalized_staged_txns : Gauge.t =
    let help =
      "# of staged txns that were finalized during the last transition \
       frontier root transition"
    in
    Gauge.v "recently_finalized_staged_txns" ~help ~namespace ~subsystem

  (* TODO:
  let recently_finalized_snarked_txns : Gauge.t =
    let help = "toal # of snarked txns that have been finalized" in
    Gauge.v "finalized_snarked_txns" ~help ~namespace ~subsystem

  let recently_finalized_snarked_txns : Gauge.t =
    let help = "# of snarked txns that were finalized during the last transition frontier root transition" in
    Gauge.v "recently_finalized_snarked_txns" ~help ~namespace ~subsystem
  *)

  let root_snarked_ledger_accounts : Gauge.t =
    let help = "# of accounts in transition frontier root snarked ledger" in
    Gauge.v "root_snarked_ledger_accounts" ~help ~namespace ~subsystem

  let root_snarked_ledger_total_currency : Gauge.t =
    let help = "total amount of currency in root snarked ledger" in
    Gauge.v "root_snarked_ledger_total_currency" ~help ~namespace ~subsystem

  (* TODO:
  let root_staged_ledger_accounts : Gauge.t =
    let help = "# of accounts in transition frontier root staged ledger" in
    Gauge.v "root_staged_ledger_accounts" ~help ~namespace ~subsystem

  let root_staged_ledger_total_currency : Gauge.t =
    let help = "total amount of currency in root staged ledger" in
    Gauge.v "root_staged_ledger_total_currency" ~help ~namespace ~subsystem
  *)
end

module Transition_frontier_controller = struct
  let subsystem = "Transition_frontier_controller"

  let transitions_being_processed : Gauge.t =
    let help =
      "transitions currently being processed by the transition frontier \
       controller"
    in
    Gauge.v "transitions_being_processed" ~help ~namespace ~subsystem

  let transitions_in_catchup_scheduler =
    let help = "transitions stored inside catchup scheduler" in
    Gauge.v "transitions_in_catchup_scheduler" ~help ~namespace ~subsystem

  let catchup_time_ms =
    let help = "time elapsed while doing catchup" in
    Gauge.v "catchup_time_ms" ~help ~namespace ~subsystem

  let transitions_downloaded_from_catchup =
    let help = "# of transitions downloaded by ledger_catchup" in
    Gauge.v "transitions_downloaded_from_catchup" ~help ~namespace ~subsystem

  let breadcrumbs_built_by_processor : Counter.t =
    let help = "breadcrumbs built by the processor" in
    Counter.v "breadcrumbs_built_by_processor" ~help ~namespace ~subsystem

  let breadcrumbs_built_by_builder : Counter.t =
    let help = "breadcrumbs built by the breadcrumb builder" in
    Counter.v "breadcrumbs_built_by_builder" ~help ~namespace ~subsystem
end

let server ~port ~logger =
  let open Cohttp in
  let open Cohttp_async in
  let handle_error _ exn =
    Logger.error logger ~module_:__MODULE__ ~location:__LOC__
      !"ecountered error while handling request to prometheus server: %{sexp: \
        Error.t}"
      (Error.of_exn exn)
  in
  let callback ~body:_ _ req =
    let uri = Request.uri req in
    match (Request.meth req, Uri.path uri) with
    | `GET, "/metrics" ->
        let data = CollectorRegistry.(collect default) in
        let body = Fmt.to_to_string TextFormat_0_0_4.output data in
        let headers =
          Header.init_with "Content-Type" "text/plain; version=0.0.4"
        in
        Server.respond_string ~status:`OK ~headers body
    | _ ->
        Server.respond_string ~status:`Bad_request "Bad request"
  in
  Server.create ~mode:`TCP ~on_handler_error:(`Call handle_error)
    (Async_extra.Tcp.Where_to_listen.of_port port)
    callback

(* re-export a constrained subset of prometheus to keep consumers of this module abstract over implementation *)
include (
  Prometheus :
    sig
      module Counter : sig
        type t = Prometheus.Counter.t

        val inc_one : t -> unit

        val inc : t -> float -> unit
      end

      module Gauge : sig
        type t = Prometheus.Gauge.t

        val inc_one : t -> unit

        val inc : t -> float -> unit

        val dec_one : t -> unit

        val dec : t -> float -> unit

        val set : t -> float -> unit
      end
    end )
