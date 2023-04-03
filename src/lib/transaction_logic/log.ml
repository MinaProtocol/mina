open Core_kernel

type t = Disabled | Stdout | Channel of Out_channel.t

let log : t -> ('a, Format.formatter, unit) format -> 'a =
 fun l ->
  Format.kdprintf (fun pp ->
      let pp_newline fmt =
        pp fmt ;
        Format.pp_print_newline fmt ()
      in
      match l with
      | Disabled ->
          ()
      | Stdout ->
          pp_newline Format.std_formatter
      | Channel ch ->
          pp_newline (Format.formatter_of_out_channel ch) )
