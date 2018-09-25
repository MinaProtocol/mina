open Core_kernel
open Async

type t = string

let create () = Deferred.Or_error.return "s3://o1labs-snarkette-data"

let put t filenames =
  let subcommand = ["s3"; "cp"] in
  let result =
    Process.run ~prog:"aws"
      ~args:(subcommand @ List.rev_append [t] filenames)
      ()
  in
  result |> Deferred.Result.ignore
