[%%import "/src/config.mlh"]

open Core_kernel

(* We re-export a constrained subset of prometheus to keep consumers of this
   module abstract over implementation.
*)
include Prometheus
open Prometheus
open Namespace
open Metric_generators
open Async_kernel

let time_offset_sec = 1609459200.

[%%inject "block_window_duration", block_window_duration]

(* textformat serialization and runtime metrics taken from github.com/mirage/prometheus:/app/prometheus_app.ml *)
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
    | Infinite when Float.(v > 0.) ->
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
      { Sample_set.ext; value; bucket } =
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
    List.iter samples ~f:(output_sample ~base:name ~label_names ~label_values f)

  let output f =
    MetricFamilyMap.iter (fun metric samples ->
        let { MetricInfo.name; metric_type; help; label_names } = metric in
        Fmt.pf f "@[<v>#HELP %a %a@,#TYPE %a %a@,%a@]" MetricName.pp name
          output_unquoted help MetricName.pp name output_metric_type metric_type
          (LabelSetMap.pp ~sep:Fmt.nop (output_metric ~name ~label_names))
          samples )
end

module type Histogram = sig
  type t

  val observe : t -> float -> unit

  val buckets : t -> int list
end

module Runtime = struct
  let subsystem = "Runtime"

  module Long_async_histogram = Histogram (struct
    let spec = Histogram_spec.of_exponential 0.5 2. 7
  end)

  let long_async_cycle : Long_async_histogram.t =
    let help = "A histogram for long async cycles" in
    Long_async_histogram.v "long_async_cycle" ~help ~namespace ~subsystem

  module Long_job_histogram = Histogram (struct
    let spec = Histogram_spec.of_exponential 0.5 2. 7
  end)

  let long_async_job : Long_job_histogram.t =
    let help = "A histogram for long async jobs" in
    Long_job_histogram.v "long_async_job" ~help ~namespace ~subsystem

  let start_time = Core.Time.now ()

  let current_gc = ref (Gc.stat ())

  let gc_stat_interval_mins = ref 15.

  let gc_allocated_bytes = ref (Gc.allocated_bytes ())

  let rec gc_stat () =
    let%bind () = after (Time_ns.Span.of_min !gc_stat_interval_mins) in
    current_gc := Gc.stat () ;
    gc_allocated_bytes := Gc.allocated_bytes () ;
    gc_stat ()

  let simple_metric ~metric_type ~help name fn =
    let name = Printf.sprintf "%s_%s_%s" namespace subsystem name in
    let info =
      { MetricInfo.name = MetricName.v name
      ; help
      ; metric_type
      ; label_names = []
      }
    in
    let collect () = LabelSetMap.singleton [] [ Sample_set.sample (fn ()) ] in
    (info, collect)

  let ocaml_gc_allocated_bytes =
    simple_metric ~metric_type:Counter "ocaml_gc_allocated_bytes"
      (fun () -> !gc_allocated_bytes)
      ~help:"Total number of bytes allocated since the program was started."

  let ocaml_gc_major_words =
    simple_metric ~metric_type:Counter "ocaml_gc_major_words"
      (fun () -> !current_gc.Gc.Stat.major_words)
      ~help:
        "Number of words allocated in the major heap since the program was \
         started."

  let ocaml_gc_minor_collections =
    simple_metric ~metric_type:Counter "ocaml_gc_minor_collections"
      (fun () -> float_of_int !current_gc.Gc.Stat.minor_collections)
      ~help:
        "Number of minor collection cycles completed since the program was \
         started."

  let ocaml_gc_major_collections =
    simple_metric ~metric_type:Counter "ocaml_gc_major_collections"
      (fun () -> float_of_int !current_gc.Gc.Stat.major_collections)
      ~help:
        "Number of major collection cycles completed since the program was \
         started."

  let ocaml_gc_heap_words =
    simple_metric ~metric_type:Gauge "ocaml_gc_heap_words"
      (fun () -> float_of_int !current_gc.Gc.Stat.heap_words)
      ~help:"Total size of the major heap, in words."

  let ocaml_gc_compactions =
    simple_metric ~metric_type:Counter "ocaml_gc_compactions"
      (fun () -> float_of_int !current_gc.Gc.Stat.compactions)
      ~help:"Number of heap compactions since the program was started."

  let ocaml_gc_top_heap_words =
    simple_metric ~metric_type:Counter "ocaml_gc_top_heap_words"
      (fun () -> float_of_int !current_gc.Gc.Stat.top_heap_words)
      ~help:"Maximum size reached by the major heap, in words."

  let ocaml_gc_live_words =
    simple_metric ~metric_type:Counter "ocaml_gc_live_words"
      (fun () -> float_of_int !current_gc.Gc.Stat.live_words)
      ~help:"Live words allocated by the GC."

  let ocaml_gc_free_words =
    simple_metric ~metric_type:Counter "ocaml_gc_free_words"
      (fun () -> float_of_int !current_gc.Gc.Stat.free_words)
      ~help:"Words freed by the GC."

  let ocaml_gc_largest_free =
    simple_metric ~metric_type:Counter "ocaml_gc_largest_free"
      (fun () -> float_of_int !current_gc.Gc.Stat.largest_free)
      ~help:"Size of the largest block freed by the GC."

  let ocaml_gc_fragments =
    simple_metric ~metric_type:Counter "ocaml_gc_fragments"
      (fun () -> float_of_int !current_gc.Gc.Stat.fragments)
      ~help:"No. of heap fragments."

  let ocaml_gc_stack_size =
    simple_metric ~metric_type:Counter "ocaml_gc_stack_size"
      (fun () -> float_of_int !current_gc.Gc.Stat.stack_size)
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
    ; ocaml_gc_fragments
    ; ocaml_gc_stack_size
    ; process_cpu_seconds_total
    ; process_uptime_ms_total
    ]

  let () =
    let open CollectorRegistry in
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

  module Snark_work_histogram = Histogram (struct
    let spec = Histogram_spec.of_linear 60. 30. 8
  end)

  let snark_work_merge_time_sec =
    let help = "time elapsed while doing merge proof" in
    Snark_work_histogram.v "snark_work_merge_time_sec" ~help ~namespace
      ~subsystem

  let snark_work_zkapp_base_time_sec =
    let help = "time elapsed while doing base proof for a zkapp transaction" in
    Counter.v "snark_work_zkapp_base_time_sec" ~help ~namespace ~subsystem

  let snark_work_base_time_sec =
    let help =
      "time elapsed while doing base proof for a non-zkapp transaction"
    in
    Counter.v "snark_work_base_time_sec" ~help ~namespace ~subsystem

  let snark_work_zkapp_base_submissions =
    let help =
      "Number of base transactions snarks for zkapp transactions submitted"
    in
    Counter.v "snark_work_zkapp_base_submissions" ~help ~namespace ~subsystem

  let snark_work_base_submissions =
    let help =
      "Number of base transactions snarks for non-zkapp transactions submitted"
    in
    Counter.v "snark_work_base_submissions" ~help ~namespace ~subsystem

  let zkapp_transaction_length =
    let help = "Number of updates in a zkapp transaction" in
    Counter.v "zkapp_transaction_length" ~help ~namespace ~subsystem

  let zkapp_proof_updates =
    let help =
      "Number of updates with proof authorization in a zkapp transaction"
    in
    Counter.v "zkapp_proof_updates" ~help ~namespace ~subsystem

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

  let staking_epoch_ledger_sync_ms =
    let help = "time elapsed when sync staking epoch ledger in ms" in
    Counter.v "staking_epoch_ledger_sync_ms" ~help ~namespace ~subsystem

  let next_epoch_ledger_sync_ms =
    let help = "time elapsed when sync next epoch ledger in ms" in
    Counter.v "next_epoch_ledger_sync_ms" ~help ~namespace ~subsystem

  let root_snarked_ledger_sync_ms =
    let help = "time elapsed when sync root snarked ledger in ms" in
    Counter.v "root_snarked_ledger_sync_ms" ~help ~namespace ~subsystem

  let num_of_root_snarked_ledger_retargeted =
    let help =
      "number of times root_snarked_ledger retargeted during bootstrap"
    in
    Gauge.v "num_of_root_snarked_ledger_retargeted" ~help ~namespace ~subsystem
end

module Transaction_pool = struct
  let subsystem = "Transaction_pool"

  let useful_transactions_received_time_sec : Gauge.t =
    let help =
      "Time at which useful transactions were seen (seconds since 1/1/1970)"
    in
    Gauge.v "useful_transactions_received_time_sec" ~help ~namespace ~subsystem

  let pool_size : Gauge.t =
    let help = "Number of transactions in the pool" in
    Gauge.v "size" ~help ~namespace ~subsystem

  let transactions_added_to_pool : Counter.t =
    let help =
      "Number of transactions added to the pool since the node start"
    in
    Counter.v "transactions_added_to_pool" ~help ~namespace ~subsystem

  let vk_refcount_table_size : Gauge.t =
    let help = "Size of verification key refcount table" in
    Gauge.v "vk_refcount_table_size" ~help ~namespace ~subsystem

  let zkapp_transactions_added_to_pool : Counter.t =
    let help =
      "Number of zkapp transactions added to the pool since the node start"
    in
    Counter.v "zkapp_transactions_added_to_pool" ~help ~namespace ~subsystem

  let zkapp_transaction_size : Counter.t =
    let help = "Size of valid zkapp transaction received (bin_size_t)" in
    Counter.v "zkapp_transaction_size" ~help ~namespace ~subsystem

  let zkapp_updates : Counter.t =
    let help =
      "Number of account updates in a valid zkapp transaction received"
    in
    Counter.v "zkapp_updates" ~help ~namespace ~subsystem

  let zkapp_proof_updates : Counter.t =
    let help =
      "Number of account updates with proof authorization in a zkapp \
       transaction"
    in
    Counter.v "zkapp_proof_updates" ~help ~namespace ~subsystem
end

module Metric_map (Metric : sig
  type t

  val subsystem : string

  val v :
       ?registry:CollectorRegistry.t
    -> help:string
    -> ?namespace:string
    -> ?subsystem:string
    -> string
    -> t
end) =
struct
  module Metric_name_map = Hashtbl.Make (String)
  include Metric_name_map

  let add t ~name ~help : Metric.t =
    if Metric_name_map.mem t name then Metric_name_map.find_exn t name
    else
      let metric = Metric.v ~help ~namespace ~subsystem:Metric.subsystem name in
      Metric_name_map.add_exn t ~key:name ~data:metric ;
      metric
end

module Network = struct
  let subsystem = "Network"

  let peers : Gauge.t =
    let help = "# of peers seen through gossip net" in
    Gauge.v "peers" ~help ~namespace ~subsystem

  let all_peers : Gauge.t =
    let help = "# of peers ever seen through gossip net" in
    Gauge.v "all_peers" ~help ~namespace ~subsystem

  let validations_timed_out : Counter.t =
    let help = "# of received messages whose validation timed out" in
    Counter.v "validations_timed_out" ~help ~namespace ~subsystem

  let gossip_messages_failed_to_decode : Counter.t =
    let help = "# of received messages that could not be decoded" in
    Counter.v "gossip_messages_failed_to_decode" ~help ~namespace ~subsystem

  let gossip_messages_received : Counter.t =
    let help = "# of messages received" in
    Counter.v "messages_received" ~help ~namespace ~subsystem

  module Delay_time_spec = struct
    let tick_interval =
      Core.Time.Span.of_ms (Int.to_float block_window_duration)

    let rolling_interval =
      Core.Time.Span.of_ms (Int.to_float (block_window_duration * 20))
  end

  module Block = struct
    let subsystem = "Block"

    let validations_timed_out : Counter.t =
      let help = "# of received blocks whose validation timed out" in
      Counter.v "validations_timed_out" ~help ~namespace ~subsystem

    let rejected : Counter.t =
      let help = "# of received blocks failing validation" in
      Counter.v "rejected" ~help ~namespace ~subsystem

    let ignored : Counter.t =
      let help = "# of received blocks ignored" in
      Counter.v "ignored" ~help ~namespace ~subsystem

    let received : Counter.t =
      let help = "# of blocks received" in
      Counter.v "received" ~help ~namespace ~subsystem

    module Validation_time =
      Moving_time_average
        (struct
          include Delay_time_spec

          let subsystem = subsystem

          let name = "validation_time"

          let help =
            "average time, in ms, for blocks to be validated and rebroadcasted"
        end)
        ()

    module Processing_time =
      Moving_time_average
        (struct
          include Delay_time_spec

          let subsystem = subsystem

          let name = "processing_time"

          let help =
            "average time, in ms, for blocks to be accepted after the OCaml \
             process receives it"
        end)
        ()

    module Rejection_time =
      Moving_time_average
        (struct
          include Delay_time_spec

          let subsystem = subsystem

          let name = "rejection_time"

          let help =
            "average time, in ms, for blocks to be rejected after the OCaml \
             process receives it"
        end)
        ()
  end

  module Snark_work = struct
    let subsystem = "Snark_work"

    let validations_timed_out : Counter.t =
      let help = "# of received snark work whose validation timed out" in
      Counter.v "validations_timed_out" ~help ~namespace ~subsystem

    let rejected : Counter.t =
      let help = "# of received snark work failing validation" in
      Counter.v "rejected" ~help ~namespace ~subsystem

    let ignored : Counter.t =
      let help = "# of received snark work ignored" in
      Counter.v "ignored" ~help ~namespace ~subsystem

    let received : Counter.t =
      let help = "# of snark work received" in
      Counter.v "received" ~help ~namespace ~subsystem

    module Validation_time =
      Moving_time_average
        (struct
          include Delay_time_spec

          let subsystem = subsystem

          let name = "validation_time"

          let help =
            "average delay, in ms, for snark work to be validated and \
             rebroadcasted"
        end)
        ()

    module Processing_time =
      Moving_time_average
        (struct
          include Delay_time_spec

          let subsystem = subsystem

          let name = "processing_time"

          let help =
            "average delay, in ms, for snark work to be accepted after the \
             OCaml process receives it"
        end)
        ()

    module Rejection_time =
      Moving_time_average
        (struct
          include Delay_time_spec

          let subsystem = subsystem

          let name = "rejection_time"

          let help =
            "average time, in ms, for snark work to be rejected after the \
             OCaml process receives it"
        end)
        ()
  end

  module Transaction = struct
    let subsystem = "Transaction"

    let validations_timed_out : Counter.t =
      let help = "# of received transactions whose validation timed out" in
      Counter.v "validations_timed_out" ~help ~namespace ~subsystem

    let rejected : Counter.t =
      let help = "# of received transactions failing validation" in
      Counter.v "rejected" ~help ~namespace ~subsystem

    let ignored : Counter.t =
      let help = "# of received transactions ignored" in
      Counter.v "ignored" ~help ~namespace ~subsystem

    let received : Counter.t =
      let help = "# of transactions received" in
      Counter.v "received" ~help ~namespace ~subsystem

    module Validation_time =
      Moving_time_average
        (struct
          include Delay_time_spec

          let subsystem = subsystem

          let name = "validation_time"

          let help =
            "average delay, in ms, for transactions to be validated and \
             rebroadcasted"
        end)
        ()

    module Processing_time =
      Moving_time_average
        (struct
          include Delay_time_spec

          let subsystem = subsystem

          let name = "processing_time"

          let help =
            "average delay, in ms, for transactions to be accepted after the \
             OCaml process receives it"
        end)
        ()

    module Rejection_time =
      Moving_time_average
        (struct
          include Delay_time_spec

          let subsystem = subsystem

          let name = "rejection_time"

          let help =
            "average time, in ms, for transactions to be rejected after the \
             OCaml process receives it"
        end)
        ()
  end

  let rpc_requests_received : Counter.t =
    let help = "# of rpc requests received" in
    Counter.v "rpc_requests_received" ~help ~namespace ~subsystem

  let rpc_requests_sent : Counter.t =
    let help = "# of rpc requests sent" in
    Counter.v "rpc_requests_sent" ~help ~namespace ~subsystem

  let surfix = "_five_slots"

  let get_some_initial_peers_rpcs_sent =
    let help = "# of Get_some_initial_peers rpc requests sent" in
    let name = "get_some_initial_peers_rpcs_sent" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_some_initial_peers_rpcs_received =
    let help = "# of Get_some_initial_peers rpc requests received" in
    let name = "get_some_initial_peers_rpcs_received" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_some_initial_peers_rpc_requests_failed : Counter.t =
    let help = "# of Get_some_initial_peers rpc requests failed" in
    Counter.v "get_some_initial_peers_rpc_requests_failed" ~help ~namespace
      ~subsystem

  let get_some_initial_peers_rpc_responses_failed : Counter.t =
    let help = "# of Get_some_initial_peers rpc requests failed to respond" in
    Counter.v "get_some_initial_peers_rpc_responses_failed" ~help ~namespace
      ~subsystem

  let get_staged_ledger_aux_and_pending_coinbases_at_hash_rpcs_sent =
    let help =
      "# of Get_staged_ledger_aux_and_pending_coinbases_at_hash rpc requests \
       sent"
    in
    let name =
      "get_staged_ledger_aux_and_pending_coinbases_at_hash_rpcs_sent"
    in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_staged_ledger_aux_and_pending_coinbases_at_hash_rpcs_received =
    let help =
      "# of Get_staged_ledger_aux_and_pending_coinbases_at_hash rpc requests \
       received"
    in
    let name =
      "get_staged_ledger_aux_and_pending_coinbases_at_hash_rpcs_received"
    in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_staged_ledger_aux_and_pending_coinbases_at_hash_rpc_requests_failed :
      Counter.t =
    let help =
      "# of Get_staged_ledger_aux_and_pending_coinbases_at_hash rpc requests \
       failed"
    in
    Counter.v
      "get_staged_ledger_aux_and_pending_coinbases_at_hash_rpc_requests_failed"
      ~help ~namespace ~subsystem

  let get_staged_ledger_aux_and_pending_coinbases_at_hash_rpc_responses_failed :
      Counter.t =
    let help =
      "# of Get_staged_ledger_aux_and_pending_coinbases_at_hash rpc requests \
       failed to respond"
    in
    Counter.v
      "get_staged_ledger_aux_and_pending_coinbases_at_hash_rpc_responses_failed"
      ~help ~namespace ~subsystem

  let answer_sync_ledger_query_rpcs_sent =
    let help = "# of Answer_sync_ledger_query rpc requests sent" in
    let name = "answer_sync_ledger_query_rpcs_sent" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let answer_sync_ledger_query_rpcs_received =
    let help = "# of Answer_synce_ledger_query rpc requests received" in
    let name = "answer_sync_ledger_query_rpcs_received" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let answer_sync_ledger_query_rpc_requests_failed : Counter.t =
    let help = "# of Answer_sync_ledger_query rpc requests failed" in
    Counter.v "answer_sync_ledger_query_rpc_requests_failed" ~help ~namespace
      ~subsystem

  let answer_sync_ledger_query_rpc_responses_failed : Counter.t =
    let help = "# of Answer_sync_ledger_query rpc requests failed to respond" in
    Counter.v "answer_sync_ledger_query_rpc_responses_failed" ~help ~namespace
      ~subsystem

  let get_transition_chain_rpcs_sent =
    let help = "# of Get_transition_chain rpc requests sent" in
    let name = "get_transition_chain_rpcs_sent" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_transition_chain_rpcs_received =
    let help = "# of Get_transition_chain rpc requests received" in
    let name = "get_transition_chain_rpcs_received" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_transition_chain_rpc_requests_failed : Counter.t =
    let help = "# of Get_some_initial_peers rpc requests failed" in
    Counter.v "get_transition_chain_rpc_requests_failed" ~help ~namespace
      ~subsystem

  let get_transition_chain_rpc_responses_failed : Counter.t =
    let help = "# of Get_transition_chain rpc requests failed to respond" in
    Counter.v "get_transition_chain_rpc_responses_failed" ~help ~namespace
      ~subsystem

  let get_transition_knowledge_rpcs_sent =
    let help = "# of Get_transition_knowledge rpc requests sent" in
    let name = "get_transition_knowledge_rpcs_sent" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_transition_knowledge_rpcs_received =
    let help = "# of Get_transition_knowledge rpc requests received" in
    let name = "get_transition_knowledge_rpcs_received" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_transition_knowledge_rpc_requests_failed : Counter.t =
    let help = "# of Get_transition_knowledge rpc requests failed" in
    Counter.v "get_transition_knowledge_rpc_requests_failed" ~help ~namespace
      ~subsystem

  let get_transition_knowledge_rpc_responses_failed : Counter.t =
    let help = "# of Get_transition_knowledge rpc requests failed to respond" in
    Counter.v "get_transition_knowledge_rpc_responses_failed" ~help ~namespace
      ~subsystem

  let get_transition_chain_proof_rpcs_sent =
    let help = "# of Get_transition_chain_proof rpc requests sent" in
    let name = "get_transition_chain_proof_rpcs_sent" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_transition_chain_proof_rpcs_received =
    let help = "# of Get_transition_chain_proof rpc requests received" in
    let name = "get_transition_chain_proof_rpcs_received" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_transition_chain_proof_rpc_requests_failed : Counter.t =
    let help = "# of Get_transition_chain_proof rpc requests failed" in
    Counter.v "get_transition_chain_proof_rpc_requests_failed" ~help ~namespace
      ~subsystem

  let get_transition_chain_proof_rpc_responses_failed : Counter.t =
    let help =
      "# of Get_transition_chain_proof rpc requests failed to respond"
    in
    Counter.v "get_transition_chain_proof_rpc_responses_failed" ~help ~namespace
      ~subsystem

  let get_node_status_rpcs_sent =
    let help = "# of Get_node_status rpc requests sent" in
    let name = "get_node_status_rpcs_sent" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_node_status_rpcs_received =
    let help = "# of Get_node_status rpc requests received" in
    let name = "get_node_status_rpcs_received" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_node_status_rpc_requests_failed : Counter.t =
    let help = "# of Get_node_status rpc requests failed" in
    Counter.v "get_node_status_rpc_requests_failed" ~help ~namespace ~subsystem

  let get_node_status_rpc_responses_failed : Counter.t =
    let help = "# of Get_node_status rpc requests failed to respond" in
    Counter.v "get_node_status_rpc_responses_failed" ~help ~namespace ~subsystem

  let get_ancestry_rpcs_sent =
    let help = "# of Get_ancestry rpc requests sent" in
    let name = "get_ancestry_rpcs_sent" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_ancestry_rpcs_received =
    let help = "# of Get_ancestry rpc requests received" in
    let name = "get_ancestry_rpcs_received" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_ancestry_rpc_requests_failed : Counter.t =
    let help = "# of Get_ancestry rpc requests failed" in
    Counter.v "get_ancestry_rpc_requests_failed" ~help ~namespace ~subsystem

  let get_ancestry_rpc_responses_failed : Counter.t =
    let help = "# of Get_ancestry rpc requests failed to respond" in
    Counter.v "get_ancestry_rpc_responses_failed" ~help ~namespace ~subsystem

  let ban_notify_rpcs_sent =
    let help = "# of Ban_notify rpc requests sent" in
    let name = "ban_notify_rpcs_sent" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let ban_notify_rpcs_received =
    let help = "# of Ban_notify rpc requests received" in
    let name = "ban_notify_rpcs_received" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let ban_notify_rpc_requests_failed : Counter.t =
    let help = "# of Ban_notify rpc requests failed" in
    Counter.v "ban_notify_rpc_requests_failed" ~help ~namespace ~subsystem

  let ban_notify_rpc_responses_failed : Counter.t =
    let help = "# of Ban_notify rpc requests failed to respond" in
    Counter.v "ban_notify_rpc_responses_failed" ~help ~namespace ~subsystem

  let get_best_tip_rpcs_sent =
    let help = "# of Get_best_tip rpc requests sent" in
    let name = "get_best_tip_rpcs_sent" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_best_tip_rpcs_received =
    let help = "# of Get_best_tip rpc requests received" in
    let name = "get_best_tip_rpcs_received" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_best_tip_rpc_requests_failed : Counter.t =
    let help = "# of Get_best_tip rpc requests failed" in
    Counter.v "get_best_tip_rpc_requests_failed" ~help ~namespace ~subsystem

  let get_best_tip_rpc_responses_failed : Counter.t =
    let help = "# of Get_best_tip rpc requests failed to respond" in
    Counter.v "get_best_tip_rpc_responses_failed" ~help ~namespace ~subsystem

  let get_epoch_ledger_rpcs_sent =
    let help = "# of Get_epoch_ledger rpc requests sent" in
    let name = "get_epoch_ledger_rpcs_sent" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let get_epoch_ledger_rpcs_received =
    let help = "# of Get_epoch_ledger rpc requests received" in
    let name = "get_epoch_ledger_rpcs_received" in
    ( Counter.v name ~help ~namespace ~subsystem
    , Gauge.v (name ^ surfix) ~help ~namespace ~subsystem )

  let new_state_received =
    let help = "# of blocks received" in
    Gauge.v "new_state_received" ~help ~namespace ~subsystem

  let new_state_broadcasted =
    let help = "# of block broadcasted" in
    Gauge.v "new_state_broadcasted" ~help ~namespace ~subsystem

  let snark_pool_diff_received =
    let help = "# of snark_pool_diff received" in
    Gauge.v "snark_pool_diff_received" ~help ~namespace ~subsystem

  let snark_pool_diff_broadcasted =
    let help = "# of snark_pool_diff broadcasted" in
    Gauge.v "snark_pool_diff_broadcasted" ~help ~namespace ~subsystem

  let transaction_pool_diff_received =
    let help = "# of txn_pool_diff received" in
    Gauge.v "transaction_pool_diff_received" ~help ~namespace ~subsystem

  let transaction_pool_diff_broadcasted =
    let help = "# of txn_pool_diff broadcasted" in
    Gauge.v "transaction_pool_diff_broadcasted" ~help ~namespace ~subsystem

  let get_epoch_ledger_rpc_requests_failed : Counter.t =
    let help = "# of Get_epoch_ledger rpc requests failed" in
    Counter.v "get_epoch_ledger_rpc_requests_failed" ~help ~namespace ~subsystem

  let get_epoch_ledger_rpc_responses_failed : Counter.t =
    let help = "# of Get_epoch_ledger rpc requests failed to respond" in
    Counter.v "get_epoch_ledger_rpc_responses_failed" ~help ~namespace
      ~subsystem

  let rpc_connections_failed : Counter.t =
    let help = "# of failed connections for rpc requests" in
    Counter.v "rpc_connections_failed" ~help ~namespace ~subsystem

  module Gauge_map = Metric_map (struct
    type t = Gauge.t

    let subsystem = subsystem

    let v = Gauge.v
  end)

  module Ipc_latency_histogram = Histogram (struct
    let spec = Histogram_spec.of_exponential 1000. 10. 5
  end)

  module Rpc_latency_histogram = Histogram (struct
    let spec = Histogram_spec.of_exponential 1000. 10. 5
  end)

  module Rpc_size_histogram = Histogram (struct
    let spec = Histogram_spec.of_exponential 500. 2. 7
  end)

  module Histogram_map = Metric_map (struct
    type t = Rpc_size_histogram.t

    let subsystem = subsystem

    let v = Rpc_size_histogram.v
  end)

  let rpc_latency_table = Gauge_map.of_alist_exn []

  let rpc_size_table = Histogram_map.of_alist_exn []

  let rpc_latency_ms ~name : Gauge.t =
    let help = "time elapsed while doing RPC calls in ms" in
    let name = name ^ "_latency" in
    Gauge_map.add rpc_latency_table ~name ~help

  let rpc_size_bytes ~name : Rpc_size_histogram.t =
    let help = "size for RPC response in bytes" in
    let name = name ^ "_size" in
    Histogram_map.add rpc_size_table ~name ~help

  let rpc_max_bytes ~name : Rpc_size_histogram.t =
    let help = "maximum size for RPC response in bytes" in
    let name = name ^ "_max_size" in
    Histogram_map.add rpc_size_table ~name ~help

  let rpc_avg_bytes ~name : Rpc_size_histogram.t =
    let help = "average size for RPC response in bytes" in
    let name = name ^ "_avg_size" in
    Histogram_map.add rpc_size_table ~name ~help

  let rpc_latency_ms_summary : Rpc_latency_histogram.t =
    let help = "A histogram for all RPC call latencies" in
    Rpc_latency_histogram.v "rpc_latency_ms_summary" ~help ~namespace ~subsystem

  let ipc_latency_ns_summary : Ipc_latency_histogram.t =
    let help = "A histogram for all IPC message latencies" in
    Ipc_latency_histogram.v "ipc_latency_ns_summary" ~help ~namespace ~subsystem

  let ipc_logs_received_total : Counter.t =
    let help = "Total number of logs received from libp2p helper subprocess" in
    Counter.v "ipc_logs_received_total" ~help ~namespace ~subsystem
end

module Pipe = struct
  let subsystem = "Pipe"

  module Drop_on_overflow = struct
    let subsystem = subsystem ^ "_overflow"

    let bootstrap_sync_ledger : Counter.t =
      let help = "Overflow in sync ledger pipe when bootstrapping" in
      Counter.v "bootstrap_sync_ledger_pipe" ~help ~namespace ~subsystem

    let verified_network_pool_diffs : Counter.t =
      let help =
        "Overflow in verified network pool diffs pipe (transactions or snark \
         work)"
      in
      Counter.v "verified_network_pool_diffs" ~help ~namespace ~subsystem

    let transition_frontier_valid_transitions : Counter.t =
      let help =
        "Overflow in valid transitions pipe that has validated network \
         transitions"
      in
      Counter.v "transition_frontier_valid_transitions" ~help ~namespace
        ~subsystem

    let transition_frontier_primary_transitions : Counter.t =
      let help = "Overflow in primary transitions pipe" in
      Counter.v "transition_frontier_primary_transitions" ~help ~namespace
        ~subsystem

    let router_transition_frontier_controller : Counter.t =
      let help =
        "Overflow in transition frontier controller pipe in Transition_router"
      in
      Counter.v "router_transition_frontier_controller" ~help ~namespace
        ~subsystem

    let router_bootstrap_controller : Counter.t =
      let help = "Overflow in bootstrap controller pipe in Transition_router" in
      Counter.v "router_bootstrap_controller_pipe" ~help ~namespace ~subsystem

    let router_verified_transitions : Counter.t =
      let help = "Overflow in verified transitions pipe in Transition_router" in
      Counter.v "router_verified_transitions" ~help ~namespace ~subsystem

    let router_transitions : Counter.t =
      let help = "Overflow in transitions pipe in Transition_router" in
      Counter.v "router_transitions" ~help ~namespace ~subsystem

    let router_valid_transitions : Counter.t =
      let help = "Overflow in valid transitions pipe in Transition_router" in
      Counter.v "router_valid_transitions" ~help ~namespace ~subsystem
  end
end

module Snark_work = struct
  let subsystem = "Snark_work"

  let useful_snark_work_received_time_sec : Gauge.t =
    let help =
      "Time at which useful snark work was seen (seconds since 1/1/1970)"
    in
    Gauge.v "useful_snark_work_received_time_sec" ~help ~namespace ~subsystem

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

  let snark_work_failed_rpc : Counter.t =
    let help = "# of snark work failures reported by snark workers" in
    Counter.v "snark_work_failed_rpc" ~help ~namespace ~subsystem

  let snark_pool_size : Gauge.t =
    let help = "# of completed snark work bundles in the snark pool" in
    Gauge.v "snark_pool_size" ~help ~namespace ~subsystem

  let pending_snark_work : Gauge.t =
    let help = "total # of snark work bundles that are yet to be generated" in
    Gauge.v "pending_snark_work" ~help ~namespace ~subsystem

  module Snark_pool_serialization_ms_histogram = Histogram (struct
    let spec = Histogram_spec.of_linear 0. 2000. 20
  end)

  let snark_pool_serialization_ms =
    let help = "A histogram for snark pool serialization time" in
    Snark_pool_serialization_ms_histogram.v "snark_pool_serialization_ms" ~help
      ~namespace ~subsystem

  module Snark_fee_histogram = Histogram (struct
    let spec = Histogram_spec.of_linear 0. 1. 10
  end)

  let snark_fee =
    let help = "A histogram for snark fees" in
    Snark_fee_histogram.v "snark_fee" ~help ~namespace ~subsystem
end

module Scan_state_metrics = struct
  let subsystem = "Scan_state"

  module Metric = struct
    type t = Gauge.t

    let subsystem = subsystem

    let v = Gauge.v
  end

  module Gauge_metric_map = Metric_map (Metric)

  let base_snark_required_map = Gauge_metric_map.of_alist_exn []

  let slots_available_map = Gauge_metric_map.of_alist_exn []

  let merge_snark_required_map = Gauge_metric_map.of_alist_exn []

  let scan_state_available_space ~name : Gauge.t =
    let help = "# of slots available" in
    let name = "slots_available_" ^ name in
    Gauge_metric_map.add slots_available_map ~help ~name

  let scan_state_base_snarks ~name : Gauge.t =
    let help = "# of base snarks required" in
    let name = "base_snarks_required_" ^ name in
    Gauge_metric_map.add base_snark_required_map ~help ~name

  let scan_state_merge_snarks ~name : Gauge.t =
    let help = "# of merge snarks required" in
    let name = "merge_snarks_required_" ^ name in
    Gauge_metric_map.add merge_snark_required_map ~help ~name

  let snark_fee_per_block : Gauge.t =
    let help = "Total snark fee per block" in
    Gauge.v "snark_fees_per_block" ~help ~namespace ~subsystem

  let transaction_fees_per_block : Gauge.t =
    let help = "Total transaction fee per block" in
    Gauge.v "transaction_fees_per_block" ~help ~namespace ~subsystem

  let purchased_snark_work_per_block : Gauge.t =
    let help = "# of snark work bundles purchased per block" in
    Gauge.v "purchased_snark_work_per_block" ~help ~namespace ~subsystem

  let snark_work_required : Gauge.t =
    let help =
      "# of snark work bundles in the scan state that are yet to be \
       done/purchased"
    in
    Gauge.v "snark_work_required" ~help ~namespace ~subsystem
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

module Block_producer = struct
  let subsystem = "Block_producer"

  let slots_won : Counter.t =
    let help =
      "slots which the loaded block production keys have won (does not \
       represent that a block was actually produced)"
    in
    Counter.v "slots_won" ~help ~namespace ~subsystem

  let blocks_produced : Counter.t =
    let help = "blocks produced and submitted by the daemon" in
    Counter.v "blocks_produced" ~help ~namespace ~subsystem

  module Block_production_delay_histogram = Histogram (struct
    (* First bucket: 60s, buckets with linear increase up to 3m30s *)
    let spec = Histogram_spec.of_linear 60000. 30000. 6
  end)

  let block_production_delay =
    let help =
      "A histogram for delay between start of slot and time of block production"
    in
    Block_production_delay_histogram.v "block_production_delay" ~help ~namespace
      ~subsystem
end

module Transition_frontier = struct
  let subsystem = "Transition_frontier"

  let max_blocklength_observed = ref 0

  let max_blocklength_observed_metrics : Gauge.t =
    let help = "max blocklength observed by the system" in
    Gauge.v "max_blocklength_observed" ~help ~namespace ~subsystem

  let update_max_blocklength_observed : int -> unit =
   fun blockchain_length ->
    if blockchain_length > !max_blocklength_observed then (
      Gauge.set max_blocklength_observed_metrics
      @@ Int.to_float blockchain_length ;
      max_blocklength_observed := blockchain_length )

  let max_unvalidated_blocklength_observed = ref 0

  let max_unvalidated_blocklength_observed_metrics : Gauge.t =
    let help = "max unvalidated blocklength observed by the system" in
    Gauge.v "max_unvalidated_blocklength_observed" ~help ~namespace ~subsystem

  let update_max_unvalidated_blocklength_observed : int -> unit =
   fun blockchain_length ->
    if blockchain_length > !max_unvalidated_blocklength_observed then (
      Gauge.set max_unvalidated_blocklength_observed_metrics
      @@ Int.to_float blockchain_length ;
      max_unvalidated_blocklength_observed := blockchain_length )

  let slot_fill_rate : Gauge.t =
    let help =
      "fill rate for the last k slots (or fewer if there have not been k slots \
       between the best tip and the frontier root)"
    in
    Gauge.v "slot_fill_rate" ~help ~namespace ~subsystem

  let min_window_density : Gauge.t =
    let help = "min window density for the best tip" in
    Gauge.v "min_window_density" ~help ~namespace ~subsystem

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

  module TPS_30min =
    Moving_bucketed_average
      (struct
        let bucket_interval = Core.Time.Span.of_min 3.0

        let num_buckets = 10

        let render_average buckets =
          let total =
            List.fold buckets ~init:0.0 ~f:(fun acc (n, _) -> acc +. n)
          in
          total /. Core.Time.Span.(of_min 30.0 |> to_sec)

        let subsystem = subsystem

        let name = "tps_30min"

        let help =
          "moving average for transaction per second, the rolling interval is \
           set to 30 min"
      end)
      ()

  let recently_finalized_staged_txns : Gauge.t =
    let help =
      "# of staged txns that were finalized during the last transition \
       frontier root transition"
    in
    Gauge.v "recently_finalized_staged_txns" ~help ~namespace ~subsystem

  let best_tip_user_txns : Gauge.t =
    let help = "# of transactions in the current best tip" in
    Gauge.v "best_tip_user_txns" ~help ~namespace ~subsystem

  let best_tip_zkapp_txns : Gauge.t =
    let help = "# of transactions in the current best tip" in
    Gauge.v "best_tip_zkapp_txns" ~help ~namespace ~subsystem

  let best_tip_coinbase : Gauge.t =
    let help =
      "0 if there is no coinbase in the current best tip, 1 otherwise"
    in
    let t = Gauge.v "best_tip_coinbase" ~help ~namespace ~subsystem in
    Gauge.set t 1. ; t

  let longest_fork : Gauge.t =
    let help = "Length of the longest path in the frontier" in
    Gauge.v "longest_fork" ~help ~namespace ~subsystem

  let empty_blocks_at_best_tip : Gauge.t =
    let help =
      "Number of blocks at the best tip that have no user-commands in them"
    in
    Gauge.v "empty_blocks_at_best_tip" ~help ~namespace ~subsystem

  let accepted_block_slot_time_sec : Gauge.t =
    let help =
      "Slot time (seconds since 1/1/1970) corresponding to the most recently \
       accepted block"
    in
    Gauge.v "accepted_block_slot_time_sec" ~help ~namespace ~subsystem

  let best_tip_slot_time_sec : Gauge.t =
    let help =
      "Slot time (seconds since 1/1/1970) corresponding to the most recent \
       best tip"
    in
    Gauge.v "best_tip_slot_time_sec" ~help ~namespace ~subsystem

  let best_tip_block_height : Gauge.t =
    let help = "Height of most recent best tip" in
    Gauge.v "best_tip_block_height" ~help ~namespace ~subsystem

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

module Catchup = struct
  let subsystem = "Catchup"

  let download_time : Gauge.t =
    let help = "time to download 1 transition in ms" in
    Gauge.v "download_time" ~help ~namespace ~subsystem

  let initial_validation_time : Gauge.t =
    let help = "time to do initial validation in ms" in
    Gauge.v "initial_validation_time" ~help ~namespace ~subsystem

  let verification_time : Gauge.t =
    let help = "time to do verificatin in ms" in
    Gauge.v "verification_time" ~help ~namespace ~subsystem

  let build_breadcrumb_time : Gauge.t =
    let help = "time to build breadcrumb in ms" in
    Gauge.v "build_breadcrumb_time" ~help ~namespace ~subsystem

  let initial_catchup_time : Gauge.t =
    let help = "time for initial catchup in min" in
    Gauge.v "initial_catchup_time" ~help ~namespace ~subsystem
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

(* these block latency metrics are recomputed every half a slot, and the averages span 20 slots *)
module Block_latency = struct
  let subsystem = "Block_latency"

  module Upload_to_gcloud = struct
    let upload_to_gcloud_blocks : Gauge.t =
      let help = "Number of pending `gsutil cp` jobs for block dumping" in
      Gauge.v "upload_to_gcloud_blocks" ~help ~namespace ~subsystem
  end

  module Latency_time_spec = struct
    let tick_interval =
      Core.Time.Span.of_ms (Int.to_float (block_window_duration / 2))

    let rolling_interval =
      Core.Time.Span.of_ms (Int.to_float (block_window_duration * 20))
  end

  module Gossip_slots =
    Moving_bucketed_average
      (struct
        let bucket_interval =
          Core.Time.Span.of_ms (Int.to_float (block_window_duration / 2))

        let num_buckets = 40

        let subsystem = subsystem

        let name = "gossip_slots"

        let help =
          "average delay, in slots, after which produced blocks are received"

        let render_average buckets =
          let total_sum, count_sum =
            List.fold buckets ~init:(0.0, 0)
              ~f:(fun (total_sum, count_sum) (total, count) ->
                (total_sum +. total, count_sum + count) )
          in
          total_sum /. Float.of_int count_sum
      end)
      ()

  module Gossip_time =
    Moving_time_average
      (struct
        include Latency_time_spec

        let subsystem = subsystem

        let name = "gossip_time"

        let help =
          "average delay, in seconds, after which produced blocks are received"
      end)
      ()

  module Inclusion_time =
    Moving_time_average
      (struct
        include Latency_time_spec

        let subsystem = subsystem

        let name = "inclusion_time"

        let help =
          "average delay, in seconds, after which produced blocks are included \
           into our frontier"
      end)
      ()

  module Validation_acceptance_time =
    Moving_time_average
      (struct
        include Latency_time_spec

        let subsystem = subsystem

        let name = "validation_acceptance_time"

        let help =
          "average delay, in seconds, between the time blocks are initially \
           received from the libp2p_helper, and when they are accepted as \
           valid"
      end)
      ()
end

module Rejected_blocks = struct
  let subsystem = "Rejected_blocks"

  let worse_than_root =
    let help =
      "The number of blocks rejected due to the blocks are not selected over \
       our root"
    in
    Counter.v "worse_than_root" ~help ~namespace ~subsystem

  let no_common_ancestor =
    let help =
      "The number of blocks rejected due to the blocks do not share a common \
       ancestor with our root"
    in
    Counter.v "no_common_ancestor" ~help ~namespace ~subsystem

  let invalid_proof =
    let help = "The number of blocks rejected due to invalid proof" in
    Counter.v "invalid_proof" ~help ~namespace ~subsystem

  let received_late =
    let help =
      "The number of blocks rejected due to blocks being received too late"
    in
    Counter.v "received_late" ~help ~namespace ~subsystem

  let received_early =
    let help =
      "The number of blocks rejected due to blocks being received too early"
    in
    Counter.v "received_early" ~help ~namespace ~subsystem
end

module Object_lifetime_statistics = struct
  let subsystem = "Object_lifetime_statistics"

  module Counter_map = Metric_map (struct
    type t = Counter.t

    let subsystem = subsystem

    let v = Counter.v
  end)

  module Gauge_map = Metric_map (struct
    type t = Gauge.t

    let subsystem = subsystem

    let v = Gauge.v
  end)

  let allocated_count_table = Counter_map.of_alist_exn []

  let allocated_count ~name : Counter.t =
    let help =
      "total number of objects allocated (including previously collected \
       objects)"
    in
    let name = "allocated_count_" ^ name in
    Counter_map.add allocated_count_table ~name ~help

  let collected_count_table = Counter_map.of_alist_exn []

  let collected_count ~name : Counter.t =
    let help = "total number of objects collected" in
    let name = "collected_count_" ^ name in
    Counter_map.add collected_count_table ~name ~help

  let lifetime_quartile_ms_table = Gauge_map.of_alist_exn []

  let live_count_table = Gauge_map.of_alist_exn []

  let live_count ~name : Gauge.t =
    let help = "total number of objects currently allocated" in
    let name = "live_count_" ^ name in
    Gauge_map.add live_count_table ~name ~help

  let lifetime_quartile_ms ~name ~quartile : Gauge.t =
    let q =
      match quartile with
      | `Q1 ->
          "q1"
      | `Q2 ->
          "q2"
      | `Q3 ->
          "q3"
      | `Q4 ->
          "q4"
    in
    let help =
      "quartile of active object lifetimes, expressed in milliseconds"
    in
    let name = "lifetime_" ^ name ^ "_" ^ q ^ "_ms" in
    Gauge_map.add lifetime_quartile_ms_table ~name ~help
end

module Execution_times = struct
  let tracked_metrics = String.Table.create ()

  let create_metric thread =
    let name = O1trace.Thread.name thread in
    let info : MetricInfo.t =
      { name =
          MetricName.v
            (Printf.sprintf "Mina_Daemon_time_spent_in_thread_%s_ms" name)
      ; help = Printf.sprintf "Total number of ms spent on '%s'" name
      ; metric_type = Counter
      ; label_names = []
      }
    in
    let collect () =
      let elapsed = O1trace.Execution_timer.elapsed_time_of_thread thread in
      LabelSetMap.singleton []
        [ Sample_set.sample (Time_ns.Span.to_ms elapsed) ]
    in
    CollectorRegistry.register CollectorRegistry.default info collect

  let sync_metrics () =
    O1trace.Thread.iter_threads ~f:(fun thread ->
        let name = O1trace.Thread.name thread in
        if not (Hashtbl.mem tracked_metrics name) then
          Hashtbl.add_exn tracked_metrics ~key:name ~data:(create_metric thread) )

  let () = CollectorRegistry.(register_pre_collect default sync_metrics)
end

let generic_server ?forward_uri ~port ~logger ~registry () =
  let open Cohttp in
  let open Cohttp_async in
  let handle_error _ exn =
    [%log error]
      ~metadata:[ ("error", `String (Exn.to_string exn)) ]
      "Encountered error while handling request to prometheus server: $error"
  in
  let callback ~body:_ _ req =
    let uri = Request.uri req in
    match (Request.meth req, Uri.path uri) with
    | `GET, "/metrics" ->
        let%bind other_data =
          match forward_uri with
          | Some uri -> (
              Monitor.try_with ~here:[%here] (fun () ->
                  let%bind resp, body = Client.get uri in
                  let status = Response.status resp in
                  if Code.is_success (Code.code_of_status status) then
                    let%map body = Body.to_string body in
                    Some body
                  else (
                    [%log error]
                      "Could not forward request to $url, got: $status"
                      ~metadata:
                        [ ("url", `String (Uri.to_string uri))
                        ; ("status_code", `Int (Code.code_of_status status))
                        ; ("status", `String (Code.string_of_status status))
                        ] ;
                    return None ) )
              >>| function
              | Ok a ->
                  a
              | Error e ->
                  [%log error]
                    "Could not forward request to $url, got error: $error"
                    ~metadata:
                      [ ("url", `String (Uri.to_string uri))
                      ; ("error", `String (Exn.to_string_mach e))
                      ] ;
                  None )
          | None ->
              return None
        in
        let data = CollectorRegistry.(collect registry) in
        let body = Fmt.to_to_string TextFormat_0_0_4.output data in
        let body =
          match other_data with
          | Some other_data ->
              body ^ "\n" ^ other_data
          | None ->
              body
        in
        let headers =
          Header.init_with "Content-Type" "text/plain; version=0.0.4"
        in
        Server.respond_string ~status:`OK ~headers body
    | _ ->
        Server.respond_string ~status:`Bad_request "Bad request"
  in
  Server.create ~mode:`TCP ~on_handler_error:(`Call handle_error)
    (Async.Tcp.Where_to_listen.of_port port)
    callback

type t = (Async.Socket.Address.Inet.t, int) Cohttp_async.Server.t

let server ?forward_uri ~port ~logger () =
  O1trace.background_thread "collect_gc_metrics" Runtime.gc_stat ;
  O1trace.thread "serve_metrics"
    (generic_server ?forward_uri ~port ~logger
       ~registry:CollectorRegistry.default )

module Archive = struct
  type t =
    { registry : CollectorRegistry.t
    ; gauge_metrics : (string, Gauge.t) Hashtbl.t
    }

  let subsystem = "Archive"

  let find_or_add t ~name ~help ~subsystem =
    match Hashtbl.find t.gauge_metrics name with
    | None ->
        let g = Gauge.v name ~help ~namespace ~subsystem ~registry:t.registry in
        Hashtbl.add_exn t.gauge_metrics ~key:name ~data:g ;
        g
    | Some m ->
        m

  let unparented_blocks t : Gauge.t =
    let help = "Number of blocks without a parent" in
    let name = "unparented_blocks" in
    find_or_add t ~name ~help ~subsystem

  let max_block_height t : Gauge.t =
    let help = "Max block height recorded in the archive database" in
    let name = "max_block_height" in
    find_or_add t ~name ~help ~subsystem

  let missing_blocks t : Gauge.t =
    let help =
      "Number of missing blocks in the last n (n = 2000 by default) blocks. A \
       block for a specific height is missing if there is no entry in the \
       blocks table for that height"
    in
    let name = "missing_blocks" in
    find_or_add t ~name ~help ~subsystem

  let create_archive_server ?forward_uri ~port ~logger () =
    let open Async_kernel.Deferred.Let_syntax in
    let archive_registry = CollectorRegistry.create () in
    let%map _ =
      generic_server ?forward_uri ~port ~logger ~registry:archive_registry ()
    in
    { registry = archive_registry
    ; gauge_metrics = Hashtbl.create (module String)
    }
end
