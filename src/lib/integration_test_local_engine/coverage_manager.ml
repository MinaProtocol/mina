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
    nodes |> Map.to_alist
      |> Malleable_error.List.fold ~init:[] ~f:(fun acc (id, node) ->
             let%bind container_id = get_container_id id in
             let%bind () = Node.stop node in
             let%bind files_in_root = Node.list_files ~logger:t.logger id ~root in
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
                      let%bind _ = run_in_container container_id ~cmd:[] in
                      Malleable_error.return "coverage_file")
    in
       Malleable_error.return (acc @ coverage_files)
   )
end
