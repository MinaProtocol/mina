let buy_it = "buy " ^ Y.it
let print x = Js_of_ocaml.Js.to_string x##.name
external external_print  : Js.js_string Js.t -> unit = "jsPrint"
