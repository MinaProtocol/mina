open Core_kernel
module Js = Js_of_ocaml.Js

external get_ts_bindings : unit -> Js.Unsafe.any Js.Optdef.t = "getTsBindings"

(* the ?. operator from JS *)
let ( |. ) (value : _ Js.Optdef.t) (key : string) =
  Js.(
    if phys_equal value undefined then undefined
    else Unsafe.get value (string key))

module Js_environment = struct
  type t = Node | Web | Unknown

  let value =
    let env = get_ts_bindings () |. "jsEnvironment" in
    Js.(
      if phys_equal env (def (string "node")) then Node
      else if phys_equal env (def (string "web")) then Web
      else Unknown)
end

let _console_log_string s = Js_of_ocaml.Firebug.console##log (Js.string s)

let _console_log s = Js_of_ocaml.Firebug.console##log s

let _console_dir s : unit =
  let f =
    Js.Unsafe.eval_string {js|(function(s) { console.dir(s, {depth: 5}); })|js}
  in
  Js.Unsafe.(fun_call f [| inject s |])

let _console_trace s : unit =
  let f = Js.Unsafe.eval_string {js|(function(s) { console.trace(s); })|js} in
  Js.Unsafe.(fun_call f [| inject s |])

let raise_error s =
  Js.Js_error.(raise_ @@ of_error (new%js Js.error_constr (Js.string s)))

external raise_exn_js : exn -> Js.js_string Js.t -> 'a = "custom_reraise_exn"

let raise_exn exn = raise_exn_js exn (Js.string (Exn.to_string exn))

let json_parse (str : Js.js_string Js.t) =
  Js.Unsafe.(fun_call global ##. JSON##.parse [| inject str |])
