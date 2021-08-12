open Async
open Core
open Pipe_lib
open O1trace

exception Libp2p_helper_died_unexpectedly

module Go_log = struct
  let ours_of_go lvl =
    let open Logger.Level in
    match lvl with
    | "error" | "panic" | "fatal" ->
        Error
    | "warn" ->
        Debug
    | "info" ->
        (* this is intentionally debug, because the go info logs are too verbose for our info *)
        Debug
    | "debug" ->
        Spam
    | _ ->
        Spam

  (* there should be no other levels. *)

  type record =
    { ts : string
    ; module_ : string [@key "logger"]
    ; level : string
    ; msg : string
    ; metadata : Yojson.Safe.t String.Map.t
    }

  let record_of_yojson (json : Yojson.Safe.t) =
    let open Result.Let_syntax in
    let prefix = "Mina_net2.Go_log.record_of_yojson: " in
    match json with
    | `Assoc fields ->
        let set_field field_name prev_value parse json =
          match prev_value with
          | Some _ ->
              Error
                (prefix ^ "Field '" ^ field_name ^ "' appears multiple times")
          | None ->
              parse json
              |> Result.map_error ~f:(fun err ->
                     prefix ^ "Could not parse field '" ^ field_name ^ "':"
                     ^ err)
              |> Result.map ~f:Option.return
        in
        let get_field field_name value =
          match value with
          | Some x ->
              Ok x
          | None ->
              Error (prefix ^ "Field '" ^ field_name ^ "' is required")
        in
        let string_of_yojson = function
          | `String s ->
              Ok s
          | _ ->
              Error "Expected a string"
        in
        let%bind ts, module_, level, msg, metadata =
          List.fold_result ~init:(None, None, None, None, String.Map.empty)
            fields ~f:(fun (ts, module_, level, msg, metadata) (field, json) ->
              match field with
              | "ts" ->
                  let%map ts = set_field "ts" ts string_of_yojson json in
                  (ts, module_, level, msg, metadata)
              | "logger" ->
                  let%map module_ =
                    set_field "logger" module_ string_of_yojson json
                  in
                  (ts, module_, level, msg, metadata)
              | "level" ->
                  let%map level =
                    set_field "level" level string_of_yojson json
                  in
                  (ts, module_, level, msg, metadata)
              | "msg" ->
                  let%map msg = set_field "msg" msg string_of_yojson json in
                  (ts, module_, level, msg, metadata)
              | _ ->
                  let field =
                    if String.equal field "error" then "go_error" else field
                  in
                  Ok
                    ( ts
                    , module_
                    , level
                    , msg
                    , Map.set ~key:field ~data:json metadata ))
        in
        let%bind ts = get_field "ts" ts in
        let%bind module_ = get_field "logger" module_ in
        let%bind level = get_field "level" level in
        let%map msg = get_field "msg" msg in
        { ts; module_; level; msg; metadata }
    | _ ->
        Error (prefix ^ "Expected a JSON object")

  let record_to_message r =
    Logger.Message.
      { timestamp = Time.of_string r.ts
      ; level = ours_of_go r.level
      ; source =
          Some
            (Logger.Source.create
               ~module_:(sprintf "Libp2p_helper.Go.%s" r.module_)
               ~location:"(not tracked)")
      ; message = r.msg
      ; metadata = r.metadata
      ; event_id = None
      }
end

type t =
  { process : Child_processes.t
  ; logger : Logger.t
  ; mutable finished : bool
  ; outstanding_requests :
      Libp2p_ipc.rpc_response_body Or_error.t Ivar.t
      Libp2p_ipc.Sequence_number.Table.t
  }

let handle_libp2p_helper_termination t ~pids ~killed result =
  Hashtbl.iter t.outstanding_requests ~f:(fun iv ->
      Ivar.fill_if_empty iv
        (Or_error.error_string "libp2p_helper process died before answering")) ;
  Hashtbl.clear t.outstanding_requests ;
  Child_processes.Termination.remove pids (Child_processes.pid t.process) ;
  if (not killed) && not t.finished then (
    match result with
    | Ok ((Error (`Exit_non_zero _) | Error (`Signal _)) as e) ->
        [%log' fatal t.logger]
          !"libp2p_helper process died unexpectedly: $exit_status"
          ~metadata:
            [ ("exit_status", `String (Unix.Exit_or_signal.to_string_hum e)) ] ;
        t.finished <- true ;
        raise Libp2p_helper_died_unexpectedly
    | Error err ->
        [%log' fatal t.logger]
          !"Child processes library could not track libp2p_helper process: $err"
          ~metadata:[ ("err", Error_json.error_to_yojson err) ] ;
        t.finished <- true ;
        let%map () = Deferred.ignore_m (Child_processes.kill t.process) in
        raise Libp2p_helper_died_unexpectedly
    | Ok (Ok ()) ->
        [%log' error t.logger]
          "libp2p helper process exited peacefully but it should have been \
           killed by shutdown!" ;
        Deferred.unit )
  else
    let exit_status =
      match result with
      | Ok e ->
          `String (Unix.Exit_or_signal.to_string_hum e)
      | Error err ->
          Error_json.error_to_yojson err
    in
    [%log' info t.logger]
      !"libp2p_helper process killed successfully: $exit_status"
      ~metadata:[ ("exit_status", exit_status) ] ;
    Deferred.unit

let handle_incoming_message t msg ~handle_push_message =
  let open Libp2p_ipc.Reader in
  let open DaemonInterface.Message in
  let record_message_delay time_sent =
    let time_received = Time_ns.(now () |> to_span_since_epoch |> Span.to_ns) in
    let message_delay =
      time_received -. Float.of_int (Stdint.Uint64.to_int time_sent)
    in
    Mina_metrics.Network.(
      Ipc_latency_histogram.observe ipc_latency_ns_summary message_delay)
  in
  match msg with
  | Libp2pHelperResponse rpc_response ->
      let rpc_header =
        Libp2pHelperInterface.RpcResponse.header_get rpc_response
      in
      let sequence_number = RpcMessageHeader.sequence_number_get rpc_header in
      record_message_delay (RpcMessageHeader.time_sent_get rpc_header) ;
      ( match Hashtbl.find t.outstanding_requests sequence_number with
      | Some ivar ->
          if Ivar.is_full ivar then failwith "TODO: log an error, don't crash"
          else Ivar.fill ivar (Libp2p_ipc.rpc_response_to_or_error rpc_response)
      | None ->
          failwith "TODO" ) ;
      Deferred.unit
  | PushMessage push_msg ->
      let push_header = DaemonInterface.PushMessage.header_get push_msg in
      record_message_delay (PushMessageHeader.time_sent_get push_header) ;
      handle_push_message t (DaemonInterface.PushMessage.get push_msg)
  | Undefined n ->
      Libp2p_ipc.undefined_union ~context:"DaemonInterface.Message" n ;
      Deferred.unit

let spawn ~logger ~pids ~conf_dir ~handle_push_message =
  let termination_handler = ref (fun ~killed:_ _result -> Deferred.unit) in
  match%map
    Child_processes.start_custom ~logger ~name:"libp2p_helper"
      ~git_root_relative_path:"src/app/libp2p_helper/result/bin/libp2p_helper"
      ~conf_dir ~args:[] ~stdout:`Chunks ~stderr:`Lines
      ~termination:
        (`Handler
          (fun ~killed _process result -> !termination_handler ~killed result))
  with
  | Error e ->
      Or_error.tag (Error e)
        ~tag:
          "Could not start libp2p_helper. If you are a dev, did you forget to \
           `make libp2p_helper` and set MINA_LIBP2P_HELPER_PATH? Try \
           MINA_LIBP2P_HELPER_PATH=$PWD/src/app/libp2p_helper/result/bin/libp2p_helper."
  | Ok process ->
      Child_processes.register_process pids process Libp2p_helper ;
      let t =
        { process
        ; logger
        ; finished = false
        ; outstanding_requests = Libp2p_ipc.Sequence_number.Table.create ()
        }
      in
      termination_handler := handle_libp2p_helper_termination t ~pids ;
      trace_recurring_task "process libp2p_helper stderr" (fun () ->
          Child_processes.stderr process
          |> Strict_pipe.Reader.iter ~f:(fun line ->
                 ( match
                     line |> Yojson.Safe.from_string |> Go_log.record_of_yojson
                   with
                 | Ok record ->
                     record |> Go_log.record_to_message |> Logger.raw logger
                 | Error error ->
                     [%log error]
                       "failed to parse record over libp2p_helper stderr: \
                        $error"
                       ~metadata:[ ("error", `String error) ] ) ;
                 Deferred.unit)) ;
      trace_recurring_task "process libp2p_helper stdout" (fun () ->
          Child_processes.stdout process
          |> Libp2p_ipc.read_incoming_messages
          |> Strict_pipe.Reader.iter ~f:(function
               | Ok msg ->
                   msg |> Libp2p_ipc.Reader.DaemonInterface.Message.get
                   |> handle_incoming_message t ~handle_push_message
               | Error _err ->
                   failwith "TODO: handle the error")) ;
      Or_error.return t

let shutdown t =
  t.finished <- true ;
  Deferred.ignore_m (Child_processes.kill t.process)

let do_rpc (type a b) (t : t) ((module Rpc) : (a, b) Libp2p_ipc.Rpcs.rpc)
    (request : a) : b Deferred.Or_error.t =
  let open Deferred.Or_error.Let_syntax in
  if
    (not t.finished)
    && (not @@ Writer.is_closed (Child_processes.stdin t.process))
  then (
    [%log' spam t.logger] "sending $message_type to libp2p_helper"
      ~metadata:[ ("message_type", `String Rpc.name) ] ;
    let ivar = Ivar.create () in
    let sequence_number = Libp2p_ipc.Sequence_number.create () in
    Hashtbl.add_exn t.outstanding_requests ~key:sequence_number ~data:ivar ;
    request |> Rpc.Request.to_rpc_request_body
    |> Libp2p_ipc.create_rpc_request ~sequence_number
    |> Libp2p_ipc.rpc_request_to_outgoing_message
    |> Libp2p_ipc.write_outgoing_message (Child_processes.stdin t.process) ;
    let%bind response = Ivar.read ivar in
    match Rpc.Response.of_rpc_response_body response with
    | Some r ->
        Deferred.Or_error.return r
    | None ->
        Deferred.Or_error.error_string "invalid RPC response" )
  else
    Deferred.Or_error.errorf "helper process already exited (doing RPC %s)"
      Rpc.name

let send_validation t ~validation_id ~validation_result =
  if
    (not t.finished)
    && (not @@ Writer.is_closed (Child_processes.stdin t.process))
  then
    Libp2p_ipc.create_push_message ~validation_id ~validation_result
    |> Libp2p_ipc.push_message_to_outgoing_message
    |> Libp2p_ipc.write_outgoing_message (Child_processes.stdin t.process)
