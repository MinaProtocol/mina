(* subprocess.ml -- run a program and collect its output *)

open Core
open Async

(* Runs [prog] with [args] and waits for it. The error is the reason the
   program could not be started. [secrets] are replaced by <hidden> in the log
   and in the error. *)
let run ~logger ?(secrets = []) ~prog ~args () =
  let hide text =
    List.fold secrets ~init:text ~f:(fun text secret ->
        String.substr_replace_all text ~pattern:secret ~with_:"<hidden>" )
  in
  let shown = List.map args ~f:hide in
  [%log debug] "Running $prog $args"
    ~metadata:
      [ ("prog", `String prog)
      ; ("args", `List (List.map shown ~f:(fun arg -> `String arg)))
      ] ;
  match%bind Process.create ~prog ~args () with
  | Error err ->
      return (Error (Error.of_string (hide (Error.to_string_hum err))))
  | Ok process ->
      let%map output = Process.collect_output_and_wait process in
      if not (String.is_empty output.stderr) then
        [%log warn] "$prog wrote to stderr: $stderr"
          ~metadata:
            [ ("prog", `String prog); ("stderr", `String output.stderr) ] ;
      Ok output
