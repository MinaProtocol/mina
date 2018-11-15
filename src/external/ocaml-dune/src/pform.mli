open! Stdune

module Var : sig
  type t =
    | Values of Value.t list
    | Project_root
    | First_dep
    | Deps
    | Targets
    | Named_local
end

module Macro : sig
  type t =
    | Exe
    | Dep
    | Bin
    | Lib
    | Libexec
    | Lib_available
    | Version
    | Read
    | Read_strings
    | Read_lines
    | Path_no_dep
    | Ocaml_config
    | Env
end

module Expansion : sig
  type t =
    | Var   of Var.t
    | Macro of Macro.t * string

  val to_sexp : t -> Sexp.t
end

module Map : sig
  type t

  val create : context:Context.t -> cxx_flags:string list -> t

  val superpose : t -> t -> t

  (** Map with all named values as [Named_local] *)
  val of_bindings : _ Bindings.t -> t

  val singleton : string -> Var.t -> t

  val of_list_exn : (string * Var.t) list -> t

  val input_file : Path.t -> t

  val expand : t -> Expansion.t option String_with_vars.expander

  val empty : t

  type stamp

  val to_stamp : t -> stamp
end
