type t = int * int * int

let make x = x

let of_ocaml_config ocfg =
  Ocaml_config.version ocfg

let supports_no_keep_locs version =
  version >= (4, 03, 0)

let supports_opaque_for_mli version =
  version >= (4, 03, 0)

let always_reads_alias_cmi version =
  version < (4, 03, 0)

let supports_color_in_ocamlparam version =
  version >= (4, 03, 0)

let supports_ocaml_color version =
  version >= (4, 05, 0)

let supports_response_file version =
  version >= (4, 05, 0)

let ocamlmklib_supports_response_file version =
  version >= (4, 08, 0)

let pervasives_includes_result version =
  version >= (4, 03, 0)

let stdlib_includes_uchar version =
  version >= (4, 03, 0)

let stdlib_includes_bigarray version =
  version >= (4, 07, 0)
