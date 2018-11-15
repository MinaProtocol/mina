open! Stdune

module Outputs = struct
  type t =
    | Stdout
    | Stderr
    | Outputs (** Both Stdout and Stderr *)
end

module Diff_mode = struct
  type t =
    | Binary      (** no diffing, just raw comparison      *)
    | Text        (** diffing after newline normalization  *)
    | Text_jbuild (** diffing but no newline normalization *)
end

module type Ast = sig
  type program
  type path
  type string

  module Diff : sig
    type file = { src : path; dst : path }

    type t =
      { optional : bool
      ; mode     : Diff_mode.t
      ; file1    : path
      ; file2    : path
      }
  end

  type t =
    | Run            of program * string list
    | Chdir          of path * t
    | Setenv         of string * string * t
    | Redirect       of Outputs.t * path * t
    | Ignore         of Outputs.t * t
    | Progn          of t list
    | Echo           of string list
    | Cat            of path
    | Copy           of path * path
    | Symlink        of path * path
    | Copy_and_add_line_directive of path * path
    | System         of string
    | Bash           of string
    | Write_file     of path * string
    | Rename         of path * path
    | Remove_tree    of path
    | Mkdir          of path
    | Digest_files   of path list
    | Diff           of Diff.t
    | Merge_files_into of path list * string list * path
end

module type Helpers = sig
  type program
  type path
  type string
  type t

  val run : program -> string list -> t
  val chdir : path -> t -> t
  val setenv : string -> string -> t -> t
  val with_stdout_to : path -> t -> t
  val with_stderr_to : path -> t -> t
  val with_outputs_to : path -> t -> t
  val ignore_stdout : t -> t
  val ignore_stderr : t -> t
  val ignore_outputs : t -> t
  val progn : t list -> t
  val echo : string list -> t
  val cat : path -> t
  val copy : path -> path -> t
  val symlink : path -> path -> t
  val copy_and_add_line_directive : path -> path -> t
  val system : string -> t
  val bash : string -> t
  val write_file : path -> string -> t
  val rename : path -> path -> t
  val remove_tree : path -> t
  val mkdir : path -> t
  val digest_files : path list -> t
  val diff : ?optional:bool -> ?mode:Diff_mode.t -> path -> path -> t
end
