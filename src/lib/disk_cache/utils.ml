open Core
open Async

let failed_to_get_cache_folder_status ~logger ~(error_msg : string) ~path =
  [%log error] "%s" error_msg ~metadata:[ ("path", `String path) ] ;
  `Initialization_error (Error.createf "%s (%s)" error_msg path)

(** Initialize a directory at a path:
      - if it does not exist, create it
      - if it exists, clear it
      - if the path provided is a file, fail
      - if it is not impossible to retrieve the status of the path, fail
*)
let initialize_dir path ~logger =
  let fail error_msg =
    Deferred.Result.fail
      (failed_to_get_cache_folder_status ~logger ~error_msg ~path)
  in
  match%bind Sys.is_directory path with
  | `Yes ->
      let%map () = File_system.clear_dir path in
      Ok path
  | `No -> (
      match%bind Sys.file_exists ~follow_symlinks:false path with
      | `Yes ->
          fail "Path to proof cache folder points to a non-directory"
      | `No ->
          let%map () = File_system.create_dir path in
          Ok path
      | `Unknown ->
          fail "Cannot evaluate existence of cache folder" )
  | `Unknown ->
      fail "Cannot evaluate existence of cache folder"
