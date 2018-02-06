(* From: https://stackoverflow.com/questions/20411450/ocaml-exposing-a-printf-function-in-an-objects-method *)
type log_level =
  | Error
  | Warn
  | Info
  | Debug

let ord lvl =
  match lvl with
  | Error -> 50
  | Warn -> 40
  | Info -> 30
  | Debug -> 20

let current_level = ref (ord Warn)

let logf name lvl =
  let do_log str =
    if (ord lvl) >= !current_level then
      print_endline (name ^ ": " ^ str)
  in
  Printf.ksprintf do_log

class logger (name: string) =
  object(self)
  method logf : 'a. log_level -> ('a, unit, string, unit) format4 -> 'a =
    fun lvl -> logf name lvl
  end


