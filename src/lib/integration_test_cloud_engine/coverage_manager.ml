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

  let download_coverage_data_from_nodes t ~nodes =
    let open Kubernetes_network in
    let root = "/root/.mina-config" in
    let open Malleable_error.Let_syntax in
    [%log' info t.logger] "Generating test coverage data..." ;
    let coverage_files =
      nodes |> Map.to_alist
      |> Malleable_error.List.fold ~init:[] ~f:(fun acc (_id, pod) ->
             let pod_id = Node.id pod in
             let%bind () = Node.stop pod in
             [%log' info t.logger] "Mina process in '$pod' killed."
               ~metadata:[ ("pod", `String pod_id) ] ;
             let%bind files_in_root = Node.list_files pod root in
             [%log' debug t.logger] "Listing files in  '$pod' '$list'"
               ~metadata:
                 [ ("pod", `String pod_id)
                 ; ( "list"
                   , `List (List.map files_in_root ~f:(fun x -> `String x)) )
                 ] ;
             let%bind coverage_files =
               files_in_root
               |> List.filter ~f:(String.is_substring ~substring:".coverage")
               |> Malleable_error.List.map ~f:(fun coverage_file ->
                      [%log' info t.logger]
                        "Downloading coverage file to ($file) from $pod'."
                        ~metadata:
                          [ ("file", `String coverage_file)
                          ; ("pod", `String pod_id)
                          ] ;
                      let%bind () =
                        Node.download_file_legacy pod
                          ~source_file:
                            (String.concat ~sep:"/" [ root; coverage_file ])
                          ~target_file:coverage_file
                      in
                      Malleable_error.return coverage_file )
             in
             Malleable_error.return (acc @ coverage_files) )
    in
    coverage_files
end
