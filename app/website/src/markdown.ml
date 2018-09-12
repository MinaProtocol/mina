open Core
open Async
open Stationary

let pandoc = "pandoc"

(*  let pandoc = "/nix/store/s27yv5yixgjggw4pk40y36q2d9fsrpwy-pandoc-2.1.2/bin/pandoc"  *)

let load path =
  Process.run_exn ~prog:pandoc ~args:[path; "--mathjax"] () >>| Html.literal

let of_string s =
  Process.run_exn ~prog:pandoc ~stdin:s ~args:["--mathjax"] () >>| Html.literal
