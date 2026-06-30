(** Access to the embedded rosetta-cli config files.

    The four files under [src/app/rosetta/rosetta-cli-config/] are
    baked into the binary at compile time so neither
    [rosetta-client] nor [rosetta-healthcheck] depend on an
    installed filesystem path. *)

(** Logical identifier for an embedded file. *)
type file =
  [ `Config  (** config.json *)
  | `Mina_ros  (** mina.ros *)
  | `Mina_no_delegation_ros  (** mina-no-delegation-test.ros *)
  | `Mina_with_return_funds_ros  (** mina-with-return-funds.ros *) ]

(** Canonical filename for a logical identifier. *)
val filename : file -> string

(** Contents of the embedded file corresponding to the given logical
    identifier. *)
val contents : file -> string

(** All embedded files as [(logical_id, filename, contents)] triples. *)
val all : (file * string * string) list

(** [find_by_name n] locates an embedded file by its canonical filename
    (e.g. ["config.json"]). *)
val find_by_name : string -> file option

(** [names ()] returns a comma-separated listing of the canonical
    filenames of embedded files. *)
val names : unit -> string

(** [export_to_dir ~dir] writes every embedded file into [dir]. Creates
    the directory if absent.  Returns the list of written absolute
    paths on success. *)
val export_to_dir : dir:string -> string list Core_kernel.Or_error.t
