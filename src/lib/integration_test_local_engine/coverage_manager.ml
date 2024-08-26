(* Submodule responsible for managing test coverage files. Responsible for code coverage raw files generatation from pods.
   Requires tailored mina images with instrumentation and BISECT_SIGTEM env variable set.
   Function traverse all applicable pods (those which has mina process) and kills them.
   This operation dumps raw bissect files (.coverage) and downloads it to gcloud bucket.
   WARNING: operations of test coverage retrieval is destructive (as it kills mina processes).
*)
open Integration_test_lib
open Core

module Coverage_manager = struct
  type t = { logger : Logger.t }

  let create ~logger = { logger }

  let download_coverage_data_from_containers t ~nodes =
    let open Malleable_error.Let_syntax in
    let open Docker_network in
    let root = "/root/.mina-config" in
    [%log' info t.logger] "Generating test coverage data..." ;
    let%bind coverage_files =
      nodes |> Map.to_alist
      |> Malleable_error.List.map ~f:(fun (_id, node) ->
             let%bind () = Node.stop node in
             let container_id = Node.id node in
             let%bind files_in_root =
               Node.list_files ~logger:t.logger node ~root
             in
             let%bind coverage_files =
               files_in_root
               |> List.filter ~f:(String.is_substring ~substring:".coverage")
               |> Malleable_error.List.map ~f:(fun coverage_file ->
                      [%log' info t.logger]
                        "Downloading coverage file to ($file) from $pod'."
                        ~metadata:
                          [ ("file", `String coverage_file)
                          ; ("container", `String container_id)
                          ] ;
                      let%bind _ =
                        Node.copy_file_from_container node
                          (Printf.sprintf "%s/%s" root coverage_file)
                          coverage_file
                      in
                      Malleable_error.return coverage_file )
             in
             Malleable_error.return coverage_files )
    in

    Malleable_error.return (List.concat coverage_files)
end
