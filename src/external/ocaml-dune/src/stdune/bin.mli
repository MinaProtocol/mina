(** OCaml binaries *)

(** Character used to separate entries in [PATH] and similar
    environment variables *)
val path_sep : char

(** Parse a [PATH] like variable *)
val parse_path : ?sep:char -> string -> Path.t list

val cons_path : Path.t -> _PATH:string option -> string

(** Extension to append to executable filenames *)
val exe : string

(** Look for a program in the PATH *)
val which : path:Path.t list -> string -> Path.t option

(** Return the .opt version of a tool if available. If the tool is not available at all in
    the given directory, returns [None]. *)
val best_prog : Path.t -> string -> Path.t option

(** "make" program *)
val make : path:Path.t list -> Path.t option

