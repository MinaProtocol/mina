open Core
open Async
open Stationary_std_internal

type t =
  | File of File.t
  | Directory of directory
and directory =
  | Synthetic of string * t list
  | Copy_directory of { path : string; name : string }
  | Symlink_directory of { path : string; name : string }

let file file = File file

let directory name ts =
  validate_filename name;
  Directory (Synthetic (name, ts))

let copy_directory ?name path =
  let name =
    match name with
    | None -> Filename.basename path
    | Some name -> name
  in
  Directory (Copy_directory {path; name})

let symlink_directory ?name path =
  let name =
    match name with
    | None -> Filename.basename path
    | Some name -> name
  in
  Directory (Symlink_directory {path; name})

let rec build t ~dst =
  match t with
  | File file ->
    File.build file ~in_directory:dst

  | Directory (Copy_directory {path; name}) ->
    Process.run_expect_no_output_exn ~prog:"cp"
      ~args:["-r"; path; dst ^/ name] ()

  | Directory (Synthetic (name, ts)) ->
    let name' = dst ^/ name in
    let%bind () = Unix.mkdir name' in
    Deferred.List.iter ts ~f:(fun t' ->
      build t' ~dst:name')

  | Directory (Symlink_directory {path; name}) ->
    let%bind cwd = Sys.getcwd () in
    Process.run_expect_no_output_exn ~prog:"ln"
      ~args:["-s"; cwd ^/ path ; dst ^/ name] ()
