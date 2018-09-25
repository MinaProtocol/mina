open Core_kernel
open Async

type t = string

let create () =
  let s3_path = "SNARKETTE_S3_PATH" in
  Sys.getenv s3_path
  |> Result.of_option
       ~error:
         (Error.createf !"Could not find environment variable: %s" s3_path)

let put t filenames =
  let subcommand = ["s3"; "cp"] in
  let result =
    Process.run ~prog:"aws"
      ~args:(subcommand @ List.rev_append [t] filenames)
      ()
  in
  result |> Deferred.Result.ignore
