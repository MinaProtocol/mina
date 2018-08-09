open Core_kernel

module Make (Node : sig
  type t [@@deriving sexp]
end) (Edge : sig
  type t [@@deriving sexp]

  val target : t -> Node.t
end) =
struct
  type t = {source: Node.t; path: Edge.t list} [@@deriving sexp]

  let of_tree_path = function
    | [] -> failwith "Path can't be empty"
    | source :: path -> {source= Edge.target source; path}

  let findi t ~f = List.findi t.path ~f

  let drop t i =
    match List.drop t.path (i - 1) with
    | x :: xs -> {source= Edge.target x; path= xs}
    | [] -> failwith "Since we (i-1) this is impossible"
end
