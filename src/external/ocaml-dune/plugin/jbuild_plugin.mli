(** API for jbuild plugins *)

module V1 : sig
  (** Current build context *)
  val context : string

  (** OCaml version for the current buid context. It might not be the
      same as [Sys.ocaml_version] *)
  val ocaml_version : string

  (** Output of [ocamlc -config] for this context *)
  val ocamlc_config : (string * string) list

  (** [send s] send [s] to jbuilder. [s] should be the contents of a
      jbuild file following the specification described in the manual. *)
  val send : string -> unit

  (** Execute a command and read it's output *)
  val run_and_read_lines : string -> string list
end
