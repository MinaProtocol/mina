(** Generate JSON for the WebKit flamegraph visualiser.

  Based on the spec at
  https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/
*)
open Yojson

type event_phase = Begin | End

type event =
  { name: string
  ; categories: string list
  ; phase: event_phase
  ; timestamp: int
  ; pid: int
  ; tid: int
  ; args: unit }

type events = event list

let create_event ?(categories = []) ?(pid = 0) ?(tid = 0) ~phase ~timestamp
    name =
  {name; categories; phase; timestamp; pid; tid; args= ()}

let json_of_phase = function Begin -> `String "B" | End -> `String "E"

let json_of_event {name; categories; phase; timestamp; pid; tid; _} =
  `Assoc
    [ ("name", `String name)
    ; ("cat", `String (String.concat "," categories))
    ; ("ph", json_of_phase phase)
    ; ("ts", `Int timestamp)
    ; ("pid", `Int pid)
    ; ("tid", `Int tid)
    ; ("args", `Assoc []) ]

let json_of_events events = `List (List.map json_of_event events)

let to_string ?buf ?len ?std events =
  to_string ?buf ?len ?std @@ json_of_events events

let to_channel ?buf ?len ?std out_channel events =
  to_channel ?buf ?len ?std out_channel @@ json_of_events events

let to_file ?buf ?len ?std filename events =
  to_channel ?buf ?len ?std (open_out filename) events
