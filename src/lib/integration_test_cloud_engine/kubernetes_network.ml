open Core
open Async

module Node = struct
  type t =
    { namespace: string
    ; pod_id: string }

  let run_in_container node cmd =
    let kubectl_cmd =
      Printf.sprintf
        "kubectl -n %s -c coda exec -i $(kubectl get pod -n %s -l \"app=%s\" -o name) -- %s"
        node.namespace
        node.namespace
        node.pod_id
        cmd
    in
    let%bind cwd = Unix.getcwd () in
    Cmd_util.run_cmd_exn cwd "sh" ["-c"; kubectl_cmd]

  let start ~fresh_state node =
    let open Deferred.Or_error.Let_syntax in
    let%bind () =
      if fresh_state then
        Deferred.map ~f:Or_error.return
          (run_in_container node "rm -rf .coda-config")
      else
        Deferred.Or_error.return ()
    in
    Deferred.map ~f:Or_error.return
      (run_in_container node "./start.sh")

  let stop node = run_in_container node "./stop.sh" >>| Or_error.return

  let send_payment _ _ = failwith "TODO"
end

type t =
  { constraint_constants: Genesis_constants.Constraint_constants.t
  ; genesis_constants: Genesis_constants.t
  ; block_producers: Node.t list
  ; snark_coordinators: Node.t list
  ; archive_nodes: Node.t list
  ; testnet_log_filter: string }

let all_nodes {block_producers; snark_coordinators; archive_nodes; _} =
  block_producers @ snark_coordinators @ archive_nodes
