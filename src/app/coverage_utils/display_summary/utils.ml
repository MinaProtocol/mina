(** Some utility functions *)

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

(** read file as a string *)
let read_whole_file filename =
  let ch = open_in filename in
  let s = really_input_string ch (in_channel_length ch) in
  close_in ch ; String.trim s

(** split string into non empty lines *)
let lines string =
  string |> String.split_on_char '\n' |> List.filter (( <> ) "")

(** split string into non empty words *)
let words string =
  string |> Str.split (Str.regexp "[ \n\r\x0c\t]+") |> List.filter (( <> ) "")

(** tests if [search] is a substring of [target]*)
let contains_substring search target =
  Base.String.substr_index ~pattern:search target <> None
