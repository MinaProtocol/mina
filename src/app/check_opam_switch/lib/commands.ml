(** runs an external command and recovers stdout as a string *)
let run_string prog args =
  let in_channel = Unix.open_process_args_in prog args in
  let output = In_channel.input_all in_channel in
  match Unix.close_process_in in_channel with
  | WEXITED 0 ->
      output
  | _ ->
      let () =
        Format.printf "failure calling: %s with args [|%a|]\n" prog
          Format.(
            pp_print_list
              ~pp_sep:(fun fmt () -> pp_print_string fmt "; ")
              pp_print_string)
          (Array.to_list args)
      in
      exit 1
