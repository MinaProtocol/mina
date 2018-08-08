open Core_kernel

module Make (Source : sig
  type t [@@deriving sexp]
end) (Has_target : sig
  type t [@@deriving sexp]

  val target_state : t -> Source.t
end) =
struct
  type t = {source: Source.t; path: Has_target.t list} [@@deriving sexp]

  let of_tree_path = function
    | [] -> failwith "Path can't be empty"
    | source :: path -> {source= Has_target.target_state source; path}

  let findi t ~f = List.findi t.path ~f

  let drop t i =
    match List.drop t.path (i - 1) with
    | x :: xs -> {source= Has_target.target_state x; path= xs}
    | [] -> failwith "Since we (i-1) this is impossible"
end
