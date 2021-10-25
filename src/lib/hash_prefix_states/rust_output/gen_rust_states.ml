open Core_kernel

let outfile_name = Sys.argv.(1)

let formatter =
  Stdlib.Format.formatter_of_out_channel (Out_channel.create outfile_name)

let emit_state name state =
  let open Stdlib.Format in
  fprintf formatter "pub const %s : [Field; 2] = [%a]@." name
    (pp_print_list
       ~pp_sep:(fun fmt () -> fprintf fmt ", ")
       (fun fmt field ->
         fprintf fmt "\"%s\"" (Snark_params.Tick.Field.to_string field)))
    (Random_oracle.State.to_list state)

open Hash_prefix_states

let () = emit_state "coinbase" coinbase
