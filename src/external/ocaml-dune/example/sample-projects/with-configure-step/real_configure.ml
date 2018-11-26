#use "config_common.ml"
#use "config"

let with_blah =
  match enable_blah with
  | Yes  -> true
  | No   -> false
  | Auto -> true (* replace by some detection code *)

let blah_path =
  if with_blah then
    (* replace by some relevant stuff *)
    "/path/to/blah"
  else
    "<no support for blah>"

let () =
  let oc = open_out_bin "config.full" in
  Printf.fprintf oc {|
let with_blah = %B
let blah_path = %S
|}
    with_blah blah_path

