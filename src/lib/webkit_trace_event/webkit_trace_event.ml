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

let buf = Bigstring.create 128

let emitk (k : event_kind) pos =
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

let emiti (i : int) pos =
  Bigstring.set_uint64_le buf ~pos i ;
  pos + 8

let emits (s : string) pos =
  let sl = String.length s in
  let pos = emiti sl pos in
  Bigstring.From_string.blit ~src:s ~src_pos:0 ~len:sl ~dst:buf ~dst_pos:pos ;
  pos + sl

let finish wr final_len = Writer.write_bigstring wr ~pos:0 ~len:final_len buf

let emit_event wr (event : event) =
  match event.phase with
  | New_thread ->
      emitk New_thread 0 |> emiti event.timestamp |> emiti event.tid
      |> emits event.name |> finish wr
  | Thread_switch ->
      emitk Thread_switch 0 |> emiti event.timestamp |> emiti event.tid
      |> finish wr
  | Cycle_end -> emitk Cycle_end 0 |> emiti event.timestamp |> finish wr
  | Pid_is -> emitk Pid_is 0 |> emiti event.pid |> finish wr
  | Event ->
      emitk Event 0 |> emiti event.timestamp |> emits event.name |> finish wr
  | Start ->
      emitk Start 0 |> emiti event.timestamp |> emits event.name |> finish wr
  | End -> emitk End 0 |> emiti event.timestamp |> finish wr
