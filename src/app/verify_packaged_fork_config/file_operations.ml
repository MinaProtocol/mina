(** File system operations utilities.

    This module provides safe, logged file system operations used throughout
    the verification process. All operations use Async for non-blocking I/O
    and include comprehensive logging.
*)

open Core
open Async

(** Create directories recursively, similar to 'mkdir -p'.

    @param path The directory path to create
    @return Deferred unit on success
*)
let rec mkdir_p path =
  let%bind exists = Sys.file_exists path in
  match exists with
  | `Yes ->
      Log.Global.debug "Directory already exists: %s" path ;
      return ()
  | `No | `Unknown ->
      let parent = Filename.dirname path in
      let%bind () =
        if String.equal parent path then return () else mkdir_p parent
      in
      Log.Global.info "Creating directory: %s" path ;
      Unix.mkdir path ~perm:Constants.Permissions.directory_default

(** Copy a file from source to destination.

    @param src Source file path
    @param dst Destination file path
    @return Deferred unit on success
*)
let copy_file ~src ~dst =
  Log.Global.info "Copying file: %s -> %s" src dst ;
  let%bind src_content = Reader.file_contents src in
  Writer.save dst ~contents:src_content

(** Move/rename a file from source to destination.

    @param src Source file path
    @param dst Destination file path
    @return Deferred unit on success
*)
let move_file ~src ~dst =
  Log.Global.info "Moving file: %s -> %s" src dst ;
  Unix.rename ~src ~dst

(** Set file permissions.

    @param path File or directory path
    @param perm Unix permission bits
    @return Deferred unit on success
*)
let set_permissions path perm =
  Log.Global.info "Setting permissions 0o%o on: %s" perm path ;
  Unix.chmod path ~perm

(** Check if two files have identical contents using cmp.

    This uses the system 'cmp' utility for efficient binary comparison.

    @param file1 First file path
    @param file2 Second file path
    @return true if files are identical, false otherwise
*)
let files_equal file1 file2 =
  let cmd =
    sprintf "cmp -s %s %s" (Filename.quote file1) (Filename.quote file2)
  in
  Log.Global.debug "Comparing files: %s vs %s" file1 file2 ;
  match%map Unix.system cmd with
  | Ok () ->
      Log.Global.debug "Files are identical: %s = %s" file1 file2 ;
      true
  | Error _ ->
      Log.Global.debug "Files differ: %s ≠ %s" file1 file2 ;
      false

(** Move all .tar.gz files from source directory to destination directory.

    @param src_dir Source directory path
    @param dst_dir Destination directory path
    @return Deferred unit on success
*)
let move_tar_gz_files ~src_dir ~dst_dir =
  Log.Global.info "Moving .tar.gz files from %s to %s" src_dir dst_dir ;
  let%bind files = Sys.ls_dir src_dir in
  let tar_files = List.filter files ~f:(String.is_suffix ~suffix:".tar.gz") in
  Log.Global.debug "Found %d .tar.gz files to move" (List.length tar_files) ;
  Deferred.List.iter tar_files ~f:(fun file ->
      let src = sprintf "%s/%s" src_dir file in
      let dst = sprintf "%s/%s" dst_dir file in
      match%bind Sys.file_exists src with
      | `Yes ->
          move_file ~src ~dst
      | `No | `Unknown ->
          Log.Global.info "Warning: File not found for move: %s" src ;
          return () )

(** Create the standard working directory structure.

    Creates subdirectories: ledgers, ledgers-backup, keys, ledgers-downloaded

    @param workdir Base working directory
    @return Deferred unit on success
*)
let create_workdir_structure workdir =
  Log.Global.info "Creating working directory structure in: %s" workdir ;
  let%bind () = mkdir_p workdir in
  let%bind () = mkdir_p (Filename.concat workdir Constants.Subdirs.ledgers) in
  let%bind () =
    mkdir_p (Filename.concat workdir Constants.Subdirs.ledgers_backup)
  in
  let%bind () =
    mkdir_p (Filename.concat workdir Constants.Subdirs.ledgers_downloaded)
  in
  let%bind () = mkdir_p (Filename.concat workdir Constants.Subdirs.keys) in
  let keys_dir = Filename.concat workdir Constants.Subdirs.keys in
  set_permissions keys_dir Constants.Permissions.keys_directory

(** Resolve the full path within the working directory.

    @param workdir Base working directory
    @param relative_path Relative path or filename
    @return Full absolute path
*)
let workdir_path workdir relative_path = Filename.concat workdir relative_path
