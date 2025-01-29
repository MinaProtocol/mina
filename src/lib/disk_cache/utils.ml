open Core
open Async

let failed_to_get_cache_folder_status ~logger ~(error_msg : string) ~path =
  [%log error] "%s" error_msg ~metadata:[ ("path", `String path) ] ;
  failwithf "%s (%s)" error_msg path ()

let validate_path path ~logger =
  let open Deferred.Let_syntax in
  let failed_to_get_cache_folder_status ~logger ~(error_msg : string) ~path =
    [%log error] "%s" error_msg ~metadata:[ ("path", `String path) ] ;
    failwithf "%s (%s)" error_msg path ()
  in

  match%bind Sys.is_directory path with
  | `Yes ->
      let%bind () = File_system.clear_dir path in
      Deferred.Result.return path
  | `No -> (
      match%bind Sys.is_file path with
      | `Yes ->
          failed_to_get_cache_folder_status ~logger
            ~error_msg:
              "Invalid path to proof cache folder. Path points to a file" ~path
      | `No ->
          let%bind () = File_system.create_dir path in
          Deferred.Result.return path
      | `Unknown ->
          failed_to_get_cache_folder_status ~logger
            ~error_msg:"Cannot evaluate existence of cache folder" ~path )
  | `Unknown ->
      failed_to_get_cache_folder_status ~logger
        ~error_msg:"Cannot evaluate existence of cache folder" ~path
