open Core_kernel
open Async

type t = string

let create () = Deferred.Or_error.return "s3://o1labs-snarkette-data"

let put t directory =
  let subcommand = ["s3"; "sync"] in
  let result =
    Process.run ~prog:"aws"
      ~args:(subcommand @ [directory; t; "--exclude"; "*.temp*"])
      ()
  in
  result |> Deferred.Result.ignore
