(** Output a binary or Yojson-compatable representation of WebKit trace events.
  Spec at
  https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/
*)

open Core
open Async

type event_kind =
  | New_thread
  | Thread_switch
  | Cycle_start
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

module Output = struct
  module Binary = struct
    (** This output is designed to be consumed by trace-tool in src/app/trace-tool.
        Some fields are ommitted for the different kinds of event, and inferred
        from the meta-events [New_thread], [Cycle_start], [Cycle_end],
        [Pid_is].

        See the implementation in [emit_event] and the trace-tool
        source code for more details. *)

    let emitk ~buf (k : event_kind) pos =
      let num =
        match k with
        | New_thread -> 0
        | Thread_switch -> 1
        | Cycle_start -> 2
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
      Bigstring.From_string.blit ~src:s ~src_pos:0 ~len:sl ~dst:buf
        ~dst_pos:pos ;
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
      | Cycle_start -> ()
      | Cycle_end ->
          emitk ~buf Cycle_end 0 |> emiti ~buf event.timestamp
          |> finish ~buf wr
      | Pid_is -> emitk ~buf Pid_is 0 |> emiti ~buf event.pid |> finish ~buf wr
      | Event ->
          emitk ~buf Event 0 |> emiti ~buf event.timestamp
          |> emits ~buf event.name |> finish ~buf wr
      | Start ->
          emitk ~buf Start 0 |> emiti ~buf event.timestamp
          |> emits ~buf event.name |> finish ~buf wr
      | End -> emitk ~buf End 0 |> emiti ~buf event.timestamp |> finish ~buf wr
  end

  module JSON = struct
    (** This output is designed to mirror Yojson's JSON format, and can be
        passed directly to [Yojson.to_channel], etc. to output it to file.

        This library deliberately avoid including Yojson here to avoid bloating
        the dependency tree of its downstream users.*)
    let phase_of_kind = function
      | New_thread | Pid_is -> `String "M" (* Meta-events *)
      | Cycle_start -> `String "b" (* Async event start *)
      | Cycle_end -> `String "e" (* Async event end *)
      | Thread_switch -> `String "X"
      | Event -> `String "i"
      | Start -> `String "B"
      | End -> `String "E"

    let json_of_event {name; categories; phase; timestamp; pid; tid} =
      let categories = String.concat ~sep:"," categories in
      match phase with
      | New_thread | Pid_is ->
          `Assoc
            [ ("name", `String "thread_name")
            ; ("cat", `String categories)
            ; ("ph", phase_of_kind phase)
            ; ("pid", `Int pid)
            ; ("tid", `Int tid)
            ; ("args", `Assoc [("name", `String name)]) ]
      | Thread_switch ->
          `Assoc
            [ ("name", `String name)
            ; ("cat", `String categories)
            ; ("ph", phase_of_kind phase)
            ; ("dur", `Int 0) (* Placeholder value *)
            ; ("ts", `Int timestamp)
            ; ("pid", `Int pid)
            ; ("tid", `Int tid) ]
      | Cycle_start | Cycle_end ->
          `Assoc
            [ ("name", `String name)
            ; ("cat", `String categories)
            ; ("ph", phase_of_kind phase)
            ; ("id", `Int 0) (* Placeholder value *)
            ; ("ts", `Int timestamp)
            ; ("pid", `Int pid)
            ; ("tid", `Int tid) ]
      | Event | Start | End ->
          `Assoc
            [ ("name", `String name)
            ; ("cat", `String categories)
            ; ("ph", phase_of_kind phase)
            ; ("ts", `Int timestamp)
            ; ("pid", `Int pid)
            ; ("tid", `Int tid) ]

    let json_of_events events = `List (List.map ~f:json_of_event events)
  end
end
