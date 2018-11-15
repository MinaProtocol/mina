(** Opam install file *)

open! Stdune

module Section : sig
  type t =
    | Lib
    | Lib_root
    | Libexec
    | Libexec_root
    | Bin
    | Sbin
    | Toplevel
    | Share
    | Share_root
    | Etc
    | Doc
    | Stublibs
    | Man
    | Misc

  val decode : t Dune_lang.Decoder.t

  (** [true] iff the executable bit should be set for files installed
      in this location. *)
  val should_set_executable_bit : t -> bool

  module Paths : sig
    type section = t

    type t =
      { lib          : Path.t
      ; lib_root     : Path.t
      ; libexec      : Path.t
      ; libexec_root : Path.t
      ; bin          : Path.t
      ; sbin         : Path.t
      ; toplevel     : Path.t
      ; share        : Path.t
      ; share_root   : Path.t
      ; etc          : Path.t
      ; doc          : Path.t
      ; stublibs     : Path.t
      ; man          : Path.t
      }

    val make
      :  package:Package.Name.t
      -> destdir:Path.t
      -> ?libdir:Path.t
      -> unit
      -> t

    val install_path : t -> section -> string -> Path.t
  end with type section := t
end

module Entry : sig
  type t = private
    { src     : Path.t
    ; dst     : string option
    ; section : Section.t
    }

  val make : Section.t -> ?dst:string -> Path.t -> t
  val set_src : t -> Path.t -> t

  val relative_installed_path : t -> paths:Section.Paths.t -> Path.t
  val add_install_prefix : t -> paths:Section.Paths.t -> prefix:Path.t -> t
end

val files : Entry.t list -> Path.Set.t
val gen_install_file : Entry.t list -> string

val load_install_file : Path.t -> Entry.t list
