open Ctypes

let () =
  let type_oc = open_out "lib_gen/sodium_types_detect.c" in
  let fmt = Format.formatter_of_out_channel type_oc in
  Format.fprintf fmt "#include <sodium.h>@." ;
  Cstubs.Types.write_c fmt (module Sodium_types.C) ;
  close_out type_oc
