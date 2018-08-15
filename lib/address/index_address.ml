open Core

module T = struct
  type t = {depth: int; index: int}
  [@@deriving sexp, bin_io, hash, eq, compare]
end

module Make (Depth : sig
  val depth : int
end) =
struct
  include T
  include Hashable.Make (T)

  let depth {depth; _} = depth

  let bit_val = function `Left -> 0 | `Right -> 1

  let child {depth; index} d =
    if depth + 1 < Depth.depth then
      Ok {depth= depth + 1; index= index lor (bit_val d lsl depth)}
    else Or_error.error_string "Addr.child: Depth was too large"

  let child_exn a d = child a d |> Or_error.ok_exn

  let dirs_from_root {depth; index} =
    List.init depth ~f:(fun i ->
        if (index lsr i) land 1 = 1 then `Right else `Left )

  (* FIXME: this could be a lot faster. https://graphics.stanford.edu/~seander/bithacks.html#BitReverseObvious etc *)
  let to_index a =
    List.foldi
      (List.rev @@ dirs_from_root a)
      ~init:0
      ~f:(fun i acc dir -> acc lor (bit_val dir lsl i))

  let of_index index =
    let depth = Depth.depth in
    let bits = List.init depth ~f:(fun i -> (index lsr i) land 1) in
    (* XXX: LSB first *)
    {depth; index= List.fold bits ~init:0 ~f:(fun acc b -> (acc lsl 1) lor b)}

  let clear_all_but_first k i = i land ((1 lsl k) - 1)

  let parent {depth; index} =
    if depth > 0 then
      Ok {depth= depth - 1; index= clear_all_but_first (depth - 1) index}
    else Or_error.error_string "Addr.parent: depth <= 0"

  let parent_exn a = Or_error.ok_exn (parent a)

  let root = {depth= 0; index= 0}
end
