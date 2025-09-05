(** This output is designed to be consumed by trace-tool in src/app/trace-tool.
    Some fields are ommitted for the different kinds of event, and inferred
    from the meta-events [New_thread], [Cycle_start], [Cycle_end], [Pid_is].

    See the implementation in [emit_event] and the trace-tool source code for
    more details.
*)

open Core
open Async
open Webkit_trace_event

let emitk ~buf (k : event_kind) pos =
  let num =
    match k with
    | New_thread ->
        0
    | Thread_switch ->
        1
    | Cycle_start ->
        2
    | Cycle_end ->
        3
    | Pid_is ->
        4
    | Event ->
        5
    | Measure_start ->
        6
    | Measure_end ->
        7
    | Trace_end ->
        8
  in
  Bigstring.set_uint8_exn buf ~pos num ;
  pos + 1

let emiti ~buf (i : int) pos =
  Bigstring.set_uint64_le_exn buf ~pos i ;
  pos + 8

let emits ~buf (s : string) (pos : int) =
  let sl = String.length s in
  let pos = emiti ~buf sl pos in
  Bigstring.From_string.blit ~src:s ~src_pos:0 ~len:sl ~dst:buf ~dst_pos:pos ;
  pos + sl

let finish wr ~buf final_len =
  Writer.write_bigstring wr ~pos:0 ~len:final_len buf

let emit_event wr ~buf (event : event) =
  match event.phase with
  | New_thread ->
      emitk ~buf New_thread 0 |> emiti ~buf event.timestamp
      |> emiti ~buf event.tid |> emits ~buf event.name |> finish ~buf wr
  | Thread_switch ->
      emitk ~buf Thread_switch 0 |> emiti ~buf event.timestamp
      |> emiti ~buf event.tid |> finish ~buf wr
  | Cycle_start ->
      ()
  | Cycle_end ->
      emitk ~buf Cycle_end 0 |> emiti ~buf event.timestamp |> finish ~buf wr
  | Pid_is ->
      emitk ~buf Pid_is 0 |> emiti ~buf event.pid |> finish ~buf wr
  | Event ->
      emitk ~buf Event 0 |> emiti ~buf event.timestamp |> emits ~buf event.name
      |> finish ~buf wr
  | Measure_start ->
      emitk ~buf Measure_start 0 |> emiti ~buf event.timestamp
      |> emits ~buf event.name |> finish ~buf wr
  | Measure_end ->
      emitk ~buf Measure_end 0 |> emiti ~buf event.timestamp |> finish ~buf wr
  | Trace_end ->
      emitk ~buf Trace_end 0 |> emiti ~buf event.timestamp |> finish ~buf wr
