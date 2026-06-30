(** File system utilities for Mina stdlib Unix operations.

    This module provides asynchronous file and directory manipulation functions
    built on top of Core and Async libraries, offering safe operations for
    temporary directories, process output handling, and directory management. *)

open Async

(** {2 Directory Operations} *)

(** [dir_exists dir] checks if the given directory path exists and is actually
    a directory.

    @param dir The directory path to check
    @return A deferred boolean indicating whether the directory exists *)
val dir_exists : string -> bool Deferred.t

(** [remove_dir dir] removes a directory and all its contents recursively
    using the system 'rm -rf' command.

    This function is implemented using an external process call and will
    not raise exceptions on failure.

    @param dir The directory path to remove *)
val remove_dir : string -> unit Deferred.t

(** [rmrf path] recursively removes files and directories starting from the
    given path using Core's synchronous file system operations.

    This is a synchronous alternative to {!remove_dir} that uses Core's
    file system functions directly.

    @param path The file or directory path to remove *)
val rmrf : string -> unit

(** [clear_dir toplevel_dir] removes all contents of a directory while
    preserving the directory itself.

    This function recursively traverses the directory structure, removing
    all files first, then removing empty directories in reverse order.

    @param toplevel_dir The directory whose contents should be cleared *)
val clear_dir : string -> unit Deferred.t

(** [create_dir ?clear_if_exists dir] creates a directory, with optional
    clearing of existing contents.

    @param clear_if_exists If [true], clear the directory if it already exists.
                          Defaults to [false].
    @param dir The directory path to create *)
val create_dir : ?clear_if_exists:bool -> string -> unit Deferred.t

(** {2 Temporary Directory Management} *)

(** [try_finally ~f ~finally] executes function [f] and ensures [finally]
    is called regardless of whether [f] succeeds or fails.

    This provides exception-safe resource management for deferred computations.

    @param f The main computation to execute
    @param finally The cleanup function to execute after [f]
    @return The result of [f] if successful, or re-raises any exception after cleanup *)
val try_finally :
     f:(unit -> 'a Deferred.t)
  -> finally:(unit -> unit Deferred.t)
  -> 'a Deferred.t

(** [with_temp_dir ~f dir] creates a temporary directory, executes function [f]
    with the directory path, and ensures the directory is cleaned up afterwards.

    The temporary directory is created with a unique name based on the provided
    template directory path.

    @param f Function to execute with the temporary directory path
    @param dir Template path for the temporary directory
    @return The result of executing [f] with the temporary directory *)
val with_temp_dir : f:(string -> 'a Deferred.t) -> string -> 'a Deferred.t

(** {2 Process Output Handling} *)

(** [dup_stdout ?f process] duplicates the stdout of a process to the current
    process's stdout, optionally applying a transformation function.

    @param f Optional transformation function to apply to each line.
             Defaults to the identity function.
    @param process The process whose stdout should be duplicated *)
val dup_stdout : ?f:(string -> string) -> Process.t -> unit

(** [dup_stderr ?f process] duplicates the stderr of a process to the current
    process's stderr, optionally applying a transformation function.

    @param f Optional transformation function to apply to each line.
             Defaults to the identity function.
    @param process The process whose stderr should be duplicated *)
val dup_stderr : ?f:(string -> string) -> Process.t -> unit
