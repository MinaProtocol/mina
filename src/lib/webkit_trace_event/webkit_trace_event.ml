(** Output a binary representation of WebKit trace events.
  Spec at
  https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/
*)

open Core
open Async

type event_kind =
  | New_thread
  | Thread_switch
  | Cycle_end
  | Pid_is
  | Event
  | Start
  | End

type event =
  { name: string
  ; categories: string list
  ; phase: event_kind
  ; timestamp: int
  ; pid: int
  ; tid: int }

let emitk ~buf (k : event_kind) pos =
  let num =
    match k with
    | New_thread -> 0
    | Thread_switch -> 1
    | Cycle_end -> 3
    | Pid_is -> 4
    | Event -> 5
    | Start -> 6
    | End -> 7
  in
  Bigstring.set_uint8 buf ~pos num ;
  pos + 1

let emiti ~buf (i : int) pos =
  Bigstring.set_uint64_le buf ~pos i ;
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
  | Cycle_end ->
      emitk ~buf Cycle_end 0 |> emiti ~buf event.timestamp |> finish ~buf wr
  | Pid_is -> emitk ~buf Pid_is 0 |> emiti ~buf event.pid |> finish ~buf wr
  | Event ->
      emitk ~buf Event 0 |> emiti ~buf event.timestamp |> emits ~buf event.name
      |> finish ~buf wr
  | Start ->
      emitk ~buf Start 0 |> emiti ~buf event.timestamp |> emits ~buf event.name
      |> finish ~buf wr
  | End -> emitk ~buf End 0 |> emiti ~buf event.timestamp |> finish ~buf wr
