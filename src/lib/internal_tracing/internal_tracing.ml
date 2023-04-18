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

let enabled = ref false

let is_enabled () = !enabled

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

let toggle ~logger ?(force = false) = function
  | `Enabled ->
      if force || not (is_enabled ()) then enable_tracing ~logger ()
  | `Disabled ->
      disable_tracing ~logger ()

let current_block_id_key =
  Univ_map.Key.create ~name:"current_block_id" Block_id.sexp_of_t

let with_block block_id f =
  Async_kernel.Async_kernel_scheduler.with_local current_block_id_key block_id
    ~f

let with_state_hash state_hash f = with_block (Some (State_hash state_hash)) f

let with_slot slot f = with_block (Some (Global_slot slot)) f

let get_current_block_id () =
  Async_kernel.Async_kernel_scheduler.find_local current_block_id_key

let handling_current_block_id_change' block_id =
  if Block_id.equal !last_block_id block_id then []
  else (
    last_block_id := block_id ;
    [ `Assoc [ ("current_block", `String (Block_id.to_string block_id)) ] ] )

(** If the current context has a different block from last time,
    record a block context change. It is important to call this when generating
    events that relate to a block to detect and record context switches
    made by the Async scheduler. *)
let handling_current_block_id_change events =
  match get_current_block_id () with
  | None ->
      handling_current_block_id_change' no_block @ events
  | Some block_id ->
      handling_current_block_id_change' block_id @ events

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
    end

    let process () msg =
      let { Logger.Message.level; message; metadata; timestamp; _ } = msg in
      if is_enabled () && Logger.Level.equal level Logger.Level.Internal then
        let json_lines : Yojson.Safe.t list =
          match message with
          | "@metadata" ->
              handling_current_block_id_change
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
              let checkpoint_event_json =
                Event.checkpoint checkpoint timestamp
              in
              let metadata_event_json =
                if String.Map.is_empty metadata then []
                else [ Event.checkpoint_metadata metadata ]
              in
              handling_current_block_id_change
                (checkpoint_event_json :: metadata_event_json)
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
