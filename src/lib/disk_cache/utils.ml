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
  let open Deferred.Let_syntax in
  match%bind Sys.is_directory path with
  | `Yes ->
      let%bind () = File_system.clear_dir path in
      Deferred.Result.return path
  | `No -> (
      match%bind Sys.is_file path with
      | `Yes ->
          Deferred.Result.fail
            (failed_to_get_cache_folder_status ~logger
               ~error_msg:
                 "Invalid path to proof cache folder. Path points to a file"
               ~path )
      | `No ->
          let%bind () = File_system.create_dir path in
          Deferred.Result.return path
      | `Unknown ->
          Deferred.Result.fail
            (failed_to_get_cache_folder_status ~logger
               ~error_msg:"Cannot evaluate existence of cache folder" ~path ) )
  | `Unknown ->
      Deferred.Result.fail
        (failed_to_get_cache_folder_status ~logger
           ~error_msg:"Cannot evaluate existence of cache folder" ~path )
