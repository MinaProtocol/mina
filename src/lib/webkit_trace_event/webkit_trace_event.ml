(** Output a binary or Yojson-compatable representation of WebKit trace events.
  Spec at
  https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/
*)

open Core_kernel

type event_kind =
  | New_thread
  | Thread_switch
  | Cycle_start
  | Cycle_end
  | Pid_is
  | Event
  | Measure_start
  | Measure_end
  | Trace_end

type event =
  { name : string
  ; categories : string list
  ; phase : event_kind
  ; timestamp : int
  ; pid : int
  ; tid : int
  }

type events = event list

let create_event ?(categories = []) ?(pid = 0) ?(tid = 0) ~phase ~timestamp name
    =
  { name; categories; phase; timestamp; pid; tid }

module Output = struct
  module JSON = struct
    (** This output is designed to mirror Yojson's JSON format, and can be
        passed directly to [Yojson.to_channel], etc. to output it to file.

        This library deliberately avoid including Yojson here to avoid bloating
        the dependency tree of its downstream users.*)
    let phase_of_kind = function
      | New_thread | Pid_is ->
          `String "M" (* Meta-events *)
      | Cycle_start ->
          `String "b" (* Async event start *)
      | Cycle_end ->
          `String "e" (* Async event end *)
      | Thread_switch ->
          `String "X"
      | Event ->
          `String "i"
      | Measure_start ->
          `String "B"
      | Measure_end ->
          `String "E"
      | Trace_end ->
          `String "e"

    let json_of_event { name; categories; phase; timestamp; pid; tid } =
      let categories = String.concat ~sep:"," categories in
      match phase with
      | New_thread | Pid_is ->
          `Assoc
            [ ("name", `String "thread_name")
            ; ("cat", `String categories)
            ; ("ph", phase_of_kind phase)
            ; ("pid", `Int pid)
            ; ("tid", `Int tid)
            ; ("args", `Assoc [ ("name", `String name) ])
            ]
      | Thread_switch ->
          `Assoc
            [ ("name", `String name)
            ; ("cat", `String categories)
            ; ("ph", phase_of_kind phase)
            ; ("dur", `Int 0) (* Placeholder value *)
            ; ("ts", `Int timestamp)
            ; ("pid", `Int pid)
            ; ("tid", `Int tid)
            ]
      | Cycle_start | Cycle_end | Trace_end ->
          `Assoc
            [ ("name", `String name)
            ; ("cat", `String categories)
            ; ("ph", phase_of_kind phase)
            ; ("id", `Int 0) (* Placeholder value *)
            ; ("ts", `Int timestamp)
            ; ("pid", `Int pid)
            ; ("tid", `Int tid)
            ]
      | Event | Measure_start | Measure_end ->
          `Assoc
            [ ("name", `String name)
            ; ("cat", `String categories)
            ; ("ph", phase_of_kind phase)
            ; ("ts", `Int timestamp)
            ; ("pid", `Int pid)
            ; ("tid", `Int tid)
            ]

    let json_of_events (events : events) =
      `List (List.map ~f:json_of_event events)
  end
end
