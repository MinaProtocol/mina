open Core_kernel
open Async

type t = string

let create () = Deferred.Or_error.return "s3://o1labs-snarkette-data"

let put t filename =
  let subcommand = ["s3"; "cp"] in
  let result = Process.run ~prog:"aws" ~args:(subcommand @ [filename; t]) () in
  result |> Deferred.Result.ignore
