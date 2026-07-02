open Core_kernel
open Async_kernel
open Network_peer

type participant = Us | Them [@@deriving equal, show]

let name_of_participant = function
  | Us ->
      "the local host"
  | Them ->
      "the remote host"

type state =
  | FullyOpen  (** Streams start in this state. Both sides can still write *)
  | HalfClosed of participant
      (** Streams move from [FullyOpen] to [HalfClosed `Us] when the write pipe is closed. Streams move from [FullyOpen] to [HalfClosed `Them] when [Stream.reset] is called or the remote host closes their write stream. *)
  | FullyClosed
      (** Streams move from [HalfClosed peer] to FullyClosed once the party that isn't peer has their "close write" event. Once a stream is FullyClosed, its resources are released. *)
[@@deriving equal, show]

type queue_release_reason =
  [ `Lost | `Handler_done | `Handshake_failed | `Shutdown_or_release ]

module Queue_metrics = struct
  let env_var ~name ~default =
    match Sys.getenv_opt name with
    | None ->
        default
    | Some value -> (
        try
          let parsed = Int.of_string value in
          if parsed > 0 then parsed else raise_s [%message "non-positive"]
        with _ ->
          failwithf "%s must be a positive integer, got %S" name value () )

  let env_var_float ~name ~default ~min =
    match Sys.getenv_opt name with
    | None ->
        default
    | Some value -> (
        try
          let parsed = Float.of_string value in
          if Float.compare parsed min > 0 then parsed
          else raise_s [%message "below minimum"]
        with _ -> failwithf "%s must be > %f, got %S" name min value () )

  let threshold_messages =
    env_var ~name:"MINA_LIBP2P_STREAM_QUEUE_LOG_THRESHOLD_MESSAGES" ~default:256

  let threshold_bytes =
    env_var ~name:"MINA_LIBP2P_STREAM_QUEUE_LOG_THRESHOLD_BYTES"
      ~default:(32 * 1024 * 1024)

  let summary_interval =
    env_var ~name:"MINA_LIBP2P_STREAM_QUEUE_LOG_SUMMARY_INTERVAL_MINUTES"
      ~default:5

  let growth_factor =
    env_var_float ~name:"MINA_LIBP2P_STREAM_QUEUE_GROWTH_FACTOR" ~default:1.3
      ~min:1.

  type queue = Stream_inbound | Stream_outbound | Rpc_adapter

  let queue_label = function
    | Stream_inbound ->
        "stream_inbound"
    | Stream_outbound ->
        "stream_outbound"
    | Rpc_adapter ->
        "rpc_adapter"

  let reason_label = function
    | `Lost ->
        "lost"
    | `Handler_done ->
        "handler_done"
    | `Handshake_failed ->
        "handshake_failed"
    | `Shutdown_or_release ->
        "shutdown_or_release"

  type entry =
    { id : string
    ; protocol : string
    ; queue : queue
    ; reader : string Pipe.Reader.t
    ; logger : Logger.t
    ; mutable approx_bytes : int
    ; mutable released : bool
    ; mutable last_warn_messages : int
    ; mutable last_warn_bytes : int
    }

  type aggregate =
    { protocol : string
    ; queue : string
    ; mutable max_messages : int
    ; mutable sum_messages : int
    ; mutable max_bytes : int
    ; mutable sum_bytes : int
    }

  let entries : entry String.Table.t = String.Table.create ()

  let known_labels : unit String.Table.t = String.Table.create ()

  let summary_started = ref false

  let key ~protocol ~queue = protocol ^ "\000" ^ queue

  let add_known_label ~protocol ~queue =
    Hashtbl.set known_labels ~key:(key ~protocol ~queue) ~data:()

  let split_key key =
    match String.lsplit2 key ~on:'\000' with
    | Some (protocol, queue) ->
        (protocol, queue)
    | None ->
        (key, "unknown")

  let empty_aggregate ~protocol ~queue =
    { protocol
    ; queue
    ; max_messages = 0
    ; sum_messages = 0
    ; max_bytes = 0
    ; sum_bytes = 0
    }

  let collect_aggregates () =
    let aggregates = String.Table.create () in
    Hashtbl.iter entries ~f:(fun entry ->
        if not entry.released then (
          let queue = queue_label entry.queue in
          let key = key ~protocol:entry.protocol ~queue in
          let aggregate =
            Hashtbl.find_or_add aggregates key ~default:(fun () ->
                empty_aggregate ~protocol:entry.protocol ~queue )
          in
          let messages = Pipe.length entry.reader in
          let bytes = entry.approx_bytes in
          aggregate.max_messages <- max aggregate.max_messages messages ;
          aggregate.sum_messages <- aggregate.sum_messages + messages ;
          aggregate.max_bytes <- max aggregate.max_bytes bytes ;
          aggregate.sum_bytes <- aggregate.sum_bytes + bytes ) ) ;
    aggregates

  let set_gauges ~protocol ~queue ~max_messages ~sum_messages ~max_bytes
      ~sum_bytes =
    Mina_metrics.(
      Gauge.set
        (Network.stream_queue_messages_max ~protocol ~queue)
        (Float.of_int max_messages) ;
      Gauge.set
        (Network.stream_queue_messages_sum ~protocol ~queue)
        (Float.of_int sum_messages) ;
      Gauge.set
        (Network.stream_queue_bytes_max ~protocol ~queue)
        (Float.of_int max_bytes) ;
      Gauge.set
        (Network.stream_queue_bytes_sum ~protocol ~queue)
        (Float.of_int sum_bytes))

  let recompute_gauges () =
    Hashtbl.iter_keys known_labels ~f:(fun key ->
        let protocol, queue = split_key key in
        set_gauges ~protocol ~queue ~max_messages:0 ~sum_messages:0 ~max_bytes:0
          ~sum_bytes:0 ) ;
    let aggregates = collect_aggregates () in
    Hashtbl.iter aggregates ~f:(fun aggregate ->
        set_gauges ~protocol:aggregate.protocol ~queue:aggregate.queue
          ~max_messages:aggregate.max_messages
          ~sum_messages:aggregate.sum_messages ~max_bytes:aggregate.max_bytes
          ~sum_bytes:aggregate.sum_bytes ) ;
    aggregates

  let should_warn current threshold last =
    if current < threshold then (
      last := 0 ;
      false )
    else if !last = 0 || Float.(of_int current >= of_int !last * growth_factor)
    then (
      last := current ;
      true )
    else false

  let maybe_log_warning entry ~latest_message_bytes =
    let messages = Pipe.length entry.reader in
    let bytes = entry.approx_bytes in
    let last_warn_messages = ref entry.last_warn_messages in
    let last_warn_bytes = ref entry.last_warn_bytes in
    let warn_messages =
      should_warn messages threshold_messages last_warn_messages
    in
    let warn_bytes = should_warn bytes threshold_bytes last_warn_bytes in
    entry.last_warn_messages <- !last_warn_messages ;
    entry.last_warn_bytes <- !last_warn_bytes ;
    if warn_messages || warn_bytes then
      [%log' warn entry.logger]
        "libp2p stream queue exceeded configured retention threshold"
        ~metadata:
          [ ("stream_id", `String entry.id)
          ; ("protocol", `String entry.protocol)
          ; ("queue", `String (queue_label entry.queue))
          ; ("messages", `Int messages)
          ; ("approx_bytes", `Int bytes)
          ; ("latest_message_bytes", `Int latest_message_bytes)
          ; ("message_threshold", `Int threshold_messages)
          ; ("byte_threshold", `Int threshold_bytes)
          ]

  let start_summary_logging ~logger =
    if not !summary_started then (
      summary_started := true ;
      every
        (Time_ns.Span.of_min (Float.of_int summary_interval))
        (fun () ->
          let aggregates = recompute_gauges () in
          Hashtbl.iter aggregates ~f:(fun aggregate ->
              if aggregate.sum_messages > 0 || aggregate.sum_bytes > 0 then
                [%log' debug logger] "libp2p stream queue retention summary"
                  ~metadata:
                    [ ("protocol", `String aggregate.protocol)
                    ; ("queue", `String aggregate.queue)
                    ; ("max_messages", `Int aggregate.max_messages)
                    ; ("sum_messages", `Int aggregate.sum_messages)
                    ; ("max_approx_bytes", `Int aggregate.max_bytes)
                    ; ("sum_approx_bytes", `Int aggregate.sum_bytes)
                    ] ) ) )

  let register ~logger ~protocol ~stream_id ~queue reader =
    start_summary_logging ~logger ;
    let queue_label = queue_label queue in
    add_known_label ~protocol ~queue:queue_label ;
    let id = sprintf "%s:%s" stream_id queue_label in
    let entry =
      { id
      ; protocol
      ; queue
      ; reader
      ; logger
      ; approx_bytes = 0
      ; released = false
      ; last_warn_messages = 0
      ; last_warn_bytes = 0
      }
    in
    Hashtbl.set entries ~key:id ~data:entry ;
    ignore (recompute_gauges () : aggregate String.Table.t) ;
    entry

  let record_enqueue entry ~bytes =
    if not entry.released then (
      entry.approx_bytes <- entry.approx_bytes + bytes ;
      maybe_log_warning entry ~latest_message_bytes:bytes ;
      ignore (recompute_gauges () : aggregate String.Table.t) )

  let release entry ~reason =
    if not entry.released then (
      entry.released <- true ;
      let messages = Pipe.length entry.reader in
      let bytes = entry.approx_bytes in
      Pipe.close_read entry.reader ;
      Hashtbl.remove entries entry.id ;
      let protocol = entry.protocol in
      let queue = queue_label entry.queue in
      let reason = reason_label reason in
      Mina_metrics.(
        Counter.inc
          (Network.stream_queue_discarded_messages ~protocol ~queue ~reason)
          (Float.of_int messages) ;
        Counter.inc
          (Network.stream_queue_discarded_bytes ~protocol ~queue ~reason)
          (Float.of_int bytes)) ;
      if messages > 0 || bytes > 0 then
        [%log' info entry.logger] "released queued libp2p stream data"
          ~metadata:
            [ ("stream_id", `String entry.id)
            ; ("protocol", `String protocol)
            ; ("queue", `String queue)
            ; ("reason", `String reason)
            ; ("discarded_messages", `Int messages)
            ; ("discarded_bytes", `Int bytes)
            ] ;
      ignore (recompute_gauges () : aggregate String.Table.t) )
end

type t =
  { protocol : string
  ; id : Libp2p_ipc.stream_id
  ; mutable state : state
  ; peer : Peer.t
  ; incoming_r : string Pipe.Reader.t
  ; incoming_w : string Pipe.Writer.t
  ; outgoing_r : string Pipe.Reader.t
  ; outgoing_w : string Pipe.Writer.t
  ; release_stream : Libp2p_ipc.stream_id -> unit
  ; incoming_queue : Queue_metrics.entry
  ; outgoing_queue : Queue_metrics.entry
  ; mutable rpc_adapter_queue : Queue_metrics.entry option
  ; mutable buffers_released : bool
  }

let id { id; _ } = id

let protocol { protocol; _ } = protocol

let remote_peer { peer; _ } = peer

let state { state; _ } = state

let pipes { incoming_r; outgoing_w; _ } = (incoming_r, outgoing_w)

let stream_id_string t = Libp2p_ipc.stream_id_to_string t.id

let data_received ({ incoming_w; incoming_queue; _ } as _t) data =
  Queue_metrics.record_enqueue incoming_queue ~bytes:(String.length data) ;
  don't_wait_for (Pipe.write_if_open incoming_w data)

let register_rpc_adapter_queue t reader =
  let entry =
    Queue_metrics.register ~logger:t.incoming_queue.logger ~protocol:t.protocol
      ~stream_id:(stream_id_string t) ~queue:Queue_metrics.Rpc_adapter reader
  in
  t.rpc_adapter_queue <- Some entry

let record_rpc_adapter_enqueue t ~bytes =
  Option.iter t.rpc_adapter_queue ~f:(fun entry ->
      Queue_metrics.record_enqueue entry ~bytes )

let release_rpc_adapter_queue t ~reason =
  Option.iter t.rpc_adapter_queue ~f:(Queue_metrics.release ~reason) ;
  t.rpc_adapter_queue <- None

let release_buffers t ~reason =
  Pipe.close t.incoming_w ;
  Pipe.close t.outgoing_w ;
  Queue_metrics.release t.incoming_queue ~reason ;
  Queue_metrics.release t.outgoing_queue ~reason ;
  release_rpc_adapter_queue t ~reason ;
  t.state <- FullyClosed ;
  (* All steps above are idempotent:
     - Pipe.close on an already-closed pipe is a no-op.
     - Queue_metrics.release guards with its own released flag.
     - release_rpc_adapter_queue is None after the first call.
     - release_stream (Hashtbl.remove) is also idempotent when the key is
     absent; buffers_released is a fast-path guard against the redundant
     AVL-tree lookup. *)
  if not t.buffers_released then (
    t.buffers_released <- true ;
    t.release_stream t.id )

let reset ~helper { id; _ } =
  (* NOTE: do not close the pipes here. Reset_stream should end up
      notifying us that streamReadComplete. We can reset the stream (telling
      the remote peer to stop writing) and still be sending data ourselves. *)
  Libp2p_helper.do_rpc helper
    (module Libp2p_ipc.Rpcs.ResetStream)
    (Libp2p_ipc.Rpcs.ResetStream.create_request ~stream_id:id)
  |> Deferred.Or_error.ignore_m

let stream_state_invariant ~logger t =
  let us_closed = Pipe.is_closed t.outgoing_w in
  let them_closed = Pipe.is_closed t.incoming_w in
  [%log trace] "%sus_closed && %sthem_closed"
    (if us_closed then "" else "not ")
    (if them_closed then "" else "not ") ;
  match t.state with
  | FullyOpen ->
      (not us_closed) && not them_closed
  | HalfClosed Us ->
      us_closed && not them_closed
  | HalfClosed Them ->
      (not us_closed) && them_closed
  | FullyClosed ->
      us_closed && them_closed

(** Advance the stream_state automata, closing pipes as necessary. This
    executes atomically, using a bool + condition variable to synchronize
    updates. *)
let stream_closed ~logger ~who_closed t =
  (* FIXME: related to https://github.com/libp2p/go-libp2p-circuit/issues/18
         "preemptive" or half-closing a stream doesn't actually seem supported:
         after closing it we can't read anymore.
       NOTE: if we reintroduce this logic, it will make this function deferred,
         so we will need to also reintroduce a state lock here using
         `Async.Throttle.Sequencer.t`.
     let%map () =
       match who_closed with
       | Us ->
           match%map
             do_rpc net (module Rpcs.Close_stream) {stream_idx= stream.idx}
           with
           | Ok "closeStream success" ->
               ()
           | Ok v ->
               failwithf "helper broke RPC protocol: closeStream got %s" v
                 ()
           | Error e ->
               Error.raise e )
       | Them ->
           (* Helper notified us that the Go side closed its write pipe. *)
           Pipe.close t.incoming_w ;
           Deferred.unit
     in
  *)
  (* Helper notified us that the Go side closed its write pipe. *)
  if equal_participant who_closed Them then Pipe.close t.incoming_w ;
  let new_state =
    let log_double_close () =
      [%log error] "stream with index $index closed twice by $party"
        ~metadata:
          [ ("index", `String (Libp2p_ipc.stream_id_to_string t.id))
          ; ("party", `String (name_of_participant who_closed))
          ]
    in
    match t.state with
    | FullyOpen ->
        HalfClosed who_closed
    | HalfClosed previous_closer ->
        if equal_participant previous_closer who_closed then (
          log_double_close () ; HalfClosed previous_closer )
        else FullyClosed
    | FullyClosed ->
        log_double_close () ; FullyClosed
  in
  let old_state = t.state in
  t.state <- new_state ;
  (* TODO: maybe we can check some invariants on the Go side too? *)
  if not (stream_state_invariant ~logger t) then
    [%log error]
      "after $who_closed closed the stream, stream state invariant broke \
       (previous state: $old_stream_state)"
      ~metadata:
        [ ("who_closed", `String (name_of_participant who_closed))
        ; ("old_stream_state", `String (show_state old_state))
        ] ;
  `Stream_should_be_released (equal_state FullyClosed t.state)

let max_chunk_size = 16777216 (* 16 MiB *)

let split_string ~every b =
  let blen = String.length b in
  let num_chunks = (blen + every - 1) / every in
  List.init num_chunks ~f:(fun i ->
      let pos = i * every in
      let len = if i + 1 = num_chunks then blen - pos else every in
      String.sub ~pos ~len b )

let%test_unit "split_string" =
  let gen =
    let module Gen = Quickcheck.Generator in
    let%bind.Gen every = Gen.small_positive_int in
    let%bind.Gen total = Gen.small_non_negative_int in
    let%bind.Gen last =
      if total % every = 0 then Gen.return []
      else
        let%map.Gen s = String.gen_with_length (total % every) Gen.char_print in
        [ s ]
    in
    let%map.Gen rest =
      Gen.list_with_length (total / every)
        (String.gen_with_length every Gen.char_print)
    in
    (every, List.append rest last)
  in
  Quickcheck.test gen ~f:(fun (every, expected) ->
      let s = String.concat expected in
      assert (List.equal String.equal expected @@ split_string ~every s) )

let create_from_existing ~logger ~helper ~stream_id ~protocol ~peer
    ~release_stream =
  let incoming_r, incoming_w = Pipe.create () in
  let outgoing_r, outgoing_w_task = Pipe.create () in
  let outgoing_r_tracked, outgoing_w = Pipe.create () in
  let stream_id_string = Libp2p_ipc.stream_id_to_string stream_id in
  let incoming_queue =
    Queue_metrics.register ~logger ~protocol ~stream_id:stream_id_string
      ~queue:Queue_metrics.Stream_inbound incoming_r
  in
  let outgoing_queue =
    Queue_metrics.register ~logger ~protocol ~stream_id:stream_id_string
      ~queue:Queue_metrics.Stream_outbound outgoing_r
  in
  don't_wait_for
    (Pipe.iter outgoing_r_tracked ~f:(fun msg ->
         Queue_metrics.record_enqueue outgoing_queue ~bytes:(String.length msg) ;
         Pipe.write_without_pushback_if_open outgoing_w_task msg ;
         Deferred.unit ) ) ;
  let t =
    { id = stream_id
    ; protocol
    ; state = FullyOpen
    ; peer
    ; incoming_r
    ; incoming_w
    ; outgoing_r
    ; outgoing_w
    ; release_stream
    ; incoming_queue
    ; outgoing_queue
    ; rpc_adapter_queue = None
    ; buffers_released = false
    }
  in
  let send_outgoing_messages_task =
    Pipe.fold ~init:false outgoing_r ~f:(fun encountered_error msg ->
        if encountered_error then
          (* The stream has already failed, no need to process this message. *)
          Deferred.return encountered_error
        else
          let parts = split_string msg ~every:max_chunk_size in
          match%map
            Deferred.Or_error.List.iter parts ~f:(fun data ->
                Deferred.Or_error.ignore_m
                @@ Libp2p_helper.do_rpc helper
                     (module Libp2p_ipc.Rpcs.SendStream)
                     (Libp2p_ipc.Rpcs.SendStream.create_request ~stream_id ~data) )
          with
          | Ok _ ->
              false
          | Error e ->
              [%log error] "error sending message on stream $idx: $error"
                ~metadata:
                  [ ("idx", `String (Libp2p_ipc.stream_id_to_string stream_id))
                  ; ("error", Error_json.error_to_yojson e)
                  ] ;
              Pipe.close outgoing_w ;
              true )
    (* TODO implement proper stream closing *)
    (* >>= ( fun () ->
       match%map Libp2p_helper.do_rpc helper
           (module Libp2p_ipc.Rpcs.CloseStream)
           (Libp2p_ipc.Rpcs.CloseStream.create_request ~stream_id) with
         | Ok _ ->
             ()
         | Error e ->
           [%log error] "error closing stream $idx: $error"
             ~metadata:
               [ ("idx", `String (Libp2p_ipc.stream_id_to_string stream_id))
               ; ("error", Error_json.error_to_yojson e)
               ] ;
             ) *)
  in
  upon send_outgoing_messages_task (fun _encountered_error ->
      if not t.buffers_released then
        let (`Stream_should_be_released should_release) =
          stream_closed ~logger ~who_closed:Us t
        in
        if should_release then release_buffers t ~reason:`Handler_done ) ;
  t

(* TODO: should we really even be parsing the peer back from the client here?
   We will always have already had the full peer record by now... *)
let open_ ~logger ~helper ~protocol ~peer_id ~release_stream =
  let open Deferred.Or_error.Let_syntax in
  let%map response =
    Libp2p_helper.do_rpc helper
      (module Libp2p_ipc.Rpcs.OpenStream)
      (Libp2p_ipc.Rpcs.OpenStream.create_request ~peer_id ~protocol)
  in
  let open Libp2p_ipc.Reader.Libp2pHelperInterface.OpenStream.Response in
  let stream_id = stream_id_get response in
  let peer = Libp2p_ipc.unsafe_parse_peer (peer_get response) in
  create_from_existing ~logger ~helper ~stream_id ~protocol ~peer
    ~release_stream
