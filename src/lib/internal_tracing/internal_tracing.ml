open Core

module Block_id = struct
  type t =
    | Global_slot of Mina_numbers.Global_slot.t
    | State_hash of Mina_base.State_hash.t
  [@@deriving sexp, hash, compare, equal]

  let to_string = function
    | Global_slot slot ->
        Mina_numbers.Global_slot.to_string slot
    | State_hash hash ->
        Mina_base.State_hash.to_base58_check hash
end

let no_block = Block_id.Global_slot Mina_numbers.Global_slot.zero

let last_block_id = ref no_block

let last_call_id = ref 0

let enabled = ref false

let is_enabled () = !enabled

let toggle_callbacks = ref []

let disable_tracing ~logger () =
  [%log internal] "@internal_tracing_disabled" ;
  enabled := false

let enable_tracing ~logger () =
  (* Reset the last block information, we don't want it around when tracing gets restarted *)
  last_block_id := no_block ;
  enabled := true ;
  [%log internal] "@internal_tracing_enabled" ;
  [%log internal] "@mina_node_metadata"
    ~metadata:
      [ ("version", `String Mina_version.commit_id)
      ; ("branch", `String Mina_version.branch)
      ]

let register_toggle_callback (f : bool -> unit Async_kernel.Deferred.t) =
  toggle_callbacks := !toggle_callbacks @ [ f ]

let call_toggle_callbacks enable =
  Async_kernel.Deferred.List.iter
    ~f:(fun cb -> cb enable)
    ~how:`Parallel !toggle_callbacks

let toggle ~logger ?(force = false) = function
  | `Enabled ->
      if force || not (is_enabled ()) then (
        enable_tracing ~logger () ; call_toggle_callbacks true )
      else Async_kernel.Deferred.unit
  | `Disabled ->
      if force || is_enabled () then (
        disable_tracing ~logger () ;
        call_toggle_callbacks false )
      else Async_kernel.Deferred.unit

let current_block_id_key =
  Univ_map.Key.create ~name:"current_block_id" Block_id.sexp_of_t

let with_block block_id f =
  Async_kernel.Async_kernel_scheduler.with_local current_block_id_key block_id
    ~f

let with_state_hash state_hash f = with_block (Some (State_hash state_hash)) f

let with_slot slot f = with_block (Some (Global_slot slot)) f

let get_current_block_id () =
  Async_kernel.Async_kernel_scheduler.find_local current_block_id_key

let handling_current_block_id_change' ~last_block_id ~make block_id =
  if Block_id.equal !last_block_id block_id then []
  else (
    last_block_id := block_id ;
    [ make block_id ] )

(** If the current context has a different block from last time,
    record a block context change. It is important to call this when generating
    events that relate to a block to detect and record context switches
    made by the Async scheduler. *)
let handling_current_block_id_change ~last_block_id ~make events =
  let block_id = Option.value ~default:no_block @@ get_current_block_id () in
  handling_current_block_id_change' ~last_block_id block_id ~make @ events

let handling_current_call_id_change' ~last_call_id ~make ~tag call_id =
  if Int.equal !last_call_id call_id then []
  else (
    last_call_id := call_id ;
    [ make tag call_id ] )

(** If the current context has a different call ID from last time,
    record a call ID context change. It is important to call this when generating
    events that relate to different concurrent calls to detect and record
    context switches made by the Async scheduler. *)
let handling_current_call_id_change ~last_call_id ~make events =
  let call_id, tag = Internal_tracing_context_call.get () in
  handling_current_call_id_change' ~last_call_id ~make ~tag call_id @ events

module For_logger = struct
  module Json_lines_rotate_transport = struct
    type t = Json_lines_rotate.t

    let transport t lines = Json_lines_rotate.transport t lines
  end

  module Processor = struct
    type t = unit

    module Event = struct
      let metadata_json = Logger.Metadata.Stable.Latest.to_yojson

      let checkpoint checkpoint timestamp =
        `List
          [ `String checkpoint
          ; `Float
              (Time.Span.to_sec @@ Logger.Time.to_span_since_epoch timestamp)
          ]

      let checkpoint_metadata metadata =
        `Assoc [ ("metadata", metadata_json metadata) ]

      let block_metadata metadata =
        `Assoc [ ("block_metadata", metadata_json metadata) ]

      let internal_tracing_enabled timestamp =
        `Assoc
          [ ( "internal_tracing_enabled"
            , `Float
                (Time.Span.to_sec @@ Logger.Time.to_span_since_epoch timestamp)
            )
          ]

      let internal_tracing_disabled timestamp =
        `Assoc
          [ ( "internal_tracing_disabled"
            , `Float
                (Time.Span.to_sec @@ Logger.Time.to_span_since_epoch timestamp)
            )
          ]

      let mina_node_metadata metadata =
        `Assoc [ ("mina_node_metadata", metadata_json metadata) ]

      let produced_block_state_hash metadata =
        let state_hash =
          Option.value ~default:`Null (String.Map.find metadata "state_hash")
        in
        `Assoc [ ("produced_block_state_hash", state_hash) ]

      let current_block block_id =
        `Assoc [ ("current_block", `String (Block_id.to_string block_id)) ]

      let current_call_id tag call_id =
        `Assoc
          ( ("current_call_id", `Int call_id)
          :: Internal_tracing_context_call.Call_tag.to_metadata tag )
    end

    let expand_log_message ~last_block_id ~last_call_id ~timestamp ~message
        ~metadata =
      let handling_current_block_id_change =
        handling_current_block_id_change ~last_block_id
          ~make:Event.current_block
      in
      let handling_current_call_id_change =
        handling_current_call_id_change ~last_call_id
          ~make:Event.current_call_id
      in
      let json_lines : Yojson.Safe.t list =
        match message with
        | "@metadata" ->
            handling_current_block_id_change
            @@ handling_current_call_id_change
                 [ Event.checkpoint_metadata metadata ]
        | "@block_metadata" ->
            handling_current_block_id_change [ Event.block_metadata metadata ]
        | "@internal_tracing_enabled" ->
            [ Event.internal_tracing_enabled timestamp ]
        | "@internal_tracing_disabled" ->
            [ Event.internal_tracing_disabled timestamp ]
        | "@mina_node_metadata" ->
            [ Event.mina_node_metadata metadata ]
        | "@produced_block_state_hash" ->
            handling_current_block_id_change
              [ Event.produced_block_state_hash metadata ]
        | checkpoint ->
            let checkpoint_event_json = Event.checkpoint checkpoint timestamp in
            let metadata_event_json =
              if String.Map.is_empty metadata then []
              else [ Event.checkpoint_metadata metadata ]
            in
            handling_current_block_id_change
            @@ handling_current_call_id_change
                 (checkpoint_event_json :: metadata_event_json)
      in
      json_lines

    let process () msg =
      let { Logger.Message.level; message; metadata; timestamp; _ } = msg in
      if is_enabled () && Logger.Level.equal level Logger.Level.Internal then
        let json_lines =
          expand_log_message ~last_block_id ~last_call_id ~timestamp ~message
            ~metadata
        in
        Some
          ( String.concat ~sep:"\n"
          @@ List.map ~f:(Yojson.Safe.to_string ~std:true) json_lines )
      else None
  end

  let json_lines_rotate_transport ~directory
      ?(log_filename = "internal-trace.jsonl") ?(max_size = 1024 * 1024 * 10)
      ?(num_rotate = 50) () =
    let state =
      Json_lines_rotate.create ~directory ~log_filename ~max_size ~num_rotate
    in
    Logger.Transport.create (module Json_lines_rotate_transport) state

  let processor = Logger.Processor.create (module Processor) ()
end

module For_itn_logger = struct
  let last_block_id = ref no_block

  let last_call_id = ref 0

  (* Used by ITN logging handler. Unlike the above, this produces raw messages
     instead of JSON output.

     IMPORTANT: this must replicate the same logic as [For_logger.Processor.process] *)
  let post_process_message ~timestamp ~message ~metadata =
    let metadata = String.Map.of_alist_reduce ~f:(fun a _b -> a) metadata in
    if is_enabled () then
      let json_lines =
        For_logger.Processor.expand_log_message ~last_block_id ~last_call_id
          ~timestamp ~message ~metadata
      in
      let log_messages : (Time.t * string * (string * Yojson.Safe.t) list) list
          =
        List.filter_map json_lines ~f:(function
          | `List [ `String checkpoint; _ ] ->
              Some (timestamp, checkpoint, [])
          | `Assoc assoc ->
              Some (timestamp, "@control", assoc)
          | _ ->
              None )
      in
      log_messages
    else []
end

module Context_logger = Internal_tracing_context_logger
module Context_call = Internal_tracing_context_call
