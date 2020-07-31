module Node = struct
  type t = string

  let start _ = failwith "TODO"

  let stop _ = failwith "TODO"

  let send_payment _ _ = failwith "TODO"
end

type t =
  { block_producers: Node.t list
  ; snark_coordinators: Node.t list
  ; archive_nodes: Node.t list
  ; testnet_log_filter: string }

let all_nodes {block_producers; snark_coordinators; archive_nodes; _} =
  block_producers @ snark_coordinators @ archive_nodes
