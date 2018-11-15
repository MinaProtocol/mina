(** Version numbers for ocamlc and ocamlopt *)
type t

val make : int * int * int -> t

val of_ocaml_config : Ocaml_config.t -> t

(** Does this support [-no-keep-locs]? *)
val supports_no_keep_locs : t -> bool

(** Does this support [-opaque] for [.mli] files? *)
val supports_opaque_for_mli : t -> bool

(** Does it read the [.cmi] file of module alias
    even when [-no-alias-deps] is passed? *)
val always_reads_alias_cmi : t -> bool

(** Does this support ['color'] in [OCAMLPARAM]? *)
val supports_color_in_ocamlparam : t -> bool

(** Does this support [OCAML_COLOR]? *)
val supports_ocaml_color : t -> bool

(** Does this this support [-args0]? *)
val supports_response_file : t -> bool

(** Does ocamlmklib support [-args0]? *)
val ocamlmklib_supports_response_file : t -> bool

(** Whether [Pervasives] includes the [result] type *)
val pervasives_includes_result : t -> bool

(** Whether the standard library includes the [Uchar] module *)
val stdlib_includes_uchar : t -> bool

(** Whether the standard library includes the [Bigarray] module *)
val stdlib_includes_bigarray : t -> bool
