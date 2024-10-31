let debug = false

let print_fp (module Snark : Snark_intf.S) lab x =
  if debug then
    Snark.as_prover
      Snark.As_prover.(
        fun () ->
          Printf.printf !"%s: %{sexp:Backend.Tick.Field.t}\n%!" lab (read_var x))

let print_bool (module Snark : Snark_intf.S) lab x =
  if debug then
    Snark.as_prover (fun () ->
        Printf.printf "%s: %b\n%!" lab (Snark.As_prover.read Boolean.typ x) )
