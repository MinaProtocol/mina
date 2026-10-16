(* Timestamped progress lines on stdout. *)

open Core

let printf fmt =
  ksprintf (fun s -> printf "%s %s\n%!" (Time.to_string (Time.now ())) s) fmt
