let () =
  let fmt = Format.formatter_of_out_channel (open_out "snarky_bn382.c") in
  Format.pp_print_string fmt {c|
#include "snarky_bn382.h"
|c} ;
  Cstubs_applicative.write_c ~prefix:"snarky_bn382" fmt
    (module Snarky_bn382_bindings.Full) ;
  let fmt =
    Format.formatter_of_out_channel
      (open_out "snarky_bn382_generated_stubs.ml")
  in
  Cstubs_applicative.write_ml ~prefix:"snarky_bn382" fmt
    (module Snarky_bn382_bindings.Full)
