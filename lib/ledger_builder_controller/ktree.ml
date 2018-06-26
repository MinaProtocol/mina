open Core_kernel

(* See https://en.wikipedia.org/wiki/Rose_tree *)
module Rose = struct
  type 'a t = Rose of 'a * 'a t list [@@deriving fold]

  let single a = Rose (a, [])

  include Container.Make (struct
    type nonrec 'a t = 'a t

    let fold t ~init ~f = fold f init t

    let iter = `Define_using_fold
  end)
end

(** A Rose tree with max-depth k. Whenever we want to add a node that would increase the depth past k, we instead move the tree forward and root it at the node towards that path *)
module Make (Elem : sig
  type t [@@deriving eq]
  include Hashable.S with type t := t
end) (Small_k : sig
  val k : int
  (** The idea is k is "small" in the sense of probability of forking within k is < some nontrivial epsilon (like once a week?) *)
end) =
struct
  type t =
    { tree : Elem.t Rose.t
    ; elems : unit Elem.Table.t
    }

  let add t e parent =
    if Elem.Table.mem t.elems e then t.tree else (
      let rec go node depth =
        let Rose.Rose (x, xs) = node in
        if Elem.equal x parent then
          (Rose.Rose (x, (Rose.single e) :: xs), depth)
        else
          Rose.Rose (x, List.map xs ~f:(fun x -> go x (depth + 1)))
      in
      let x, (tree, depth) list =
        let Rose.Rose (x, xs) = t.tree in
        x, List.map xs ~f:(fun x -> go x 1)
      in
      let longest =
        List.max_elt ~compare:(fun (_, d) (_, d') -> d' - d) |> Option.value_exn
      in
      if depth >= k then
        List
    )
  in
  failwith "TODO"
end
