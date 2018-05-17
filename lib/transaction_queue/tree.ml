open Core_kernel

(* See http://okmij.org/ftp/Haskell/perfect-shuffle.txt *)
module Oleg_tree = struct
  type ('a, 'hole) t =
    | Node of (* size *) int * ('a, 'hole) t * ('a, 'hole) t * 'hole
    | Leaf of 'a * 'hole
  [@@deriving bin_io]

  let hole t =
    match t with
    | Leaf (_, h) | Node (_, _, _, h) -> h

  let rec find_hole t path ~valid =
    match (t, path) with
    | n, [] -> if (valid n) then Some (hole n) else None
    | Node (_, l, _, _), false::path' -> find_hole l path' ~valid
    | Node (_, _, r, _), true::path' -> find_hole r path' ~valid
    | Leaf _, _::_ -> None

  let create xs ~default_hole =
    let leaves =
      List.map xs ~f:(fun x -> Leaf (x, default_hole))
    in
    let join e1 e2 =
      match (e1, e2) with
      | ((Leaf _ as l), (Leaf _ as r)) ->
        Node (2, l, r, default_hole)
      | ((Node (ct, _, _, _) as l), (Leaf(_) as r)) ->
        Node (ct+1, l, r, default_hole)
      | ((Leaf _ as l), (Node (ct, _, _, _) as r)) -> Node (ct+1, l, r, default_hole)
      | ((Node (ctl, _, _, _) as l), (Node(ctr, _, _, _) as r)) -> Node (ctl+ctr, l, r, default_hole)
    in
    let rec inner : ('a, 'hole) t list -> ('a, 'hole) t list = function
      | [] -> []
      | [_] as x -> x
      | e1::e2::rest -> (join e1 e2) :: inner rest
    in
    let rec grow_level = function
      | [] -> failwith "Don't make an empty tree"
      | [node] -> node
      | l -> grow_level (inner l)
    in
    grow_level leaves

  let rec shuffle' t randomness =
    let rec extract_tree n tree k =
      match (n, tree) with
      | 0, Node (_, Leaf (e, _), r, _) -> e::(k r)
      | 1, Node (2, ((Leaf _) as l), Leaf (r, _), _) -> r::(k l)
      | _, Node (c, ((Leaf _) as l), r, h) ->
          extract_tree (n-1) r (fun new_r -> k (Node (c-1, l, new_r, h)))
      | _, Node (n1, l, (Leaf (e, _)), _) when n+1 = n1 -> e::(k l)
      | _, Node (c, (Node (c1, _, _, hl) as l), r, hr) ->
          if n < c1 then
            extract_tree n l (fun new_l -> k (Node (c-1, new_l, r, hr)))
          else
            extract_tree (n-c1) r (fun new_r -> k (Node (c-1, l, new_r, hl)))
      | _, _ -> failwith "Tree was not complete"
    in
    match (t, randomness) with
    | Leaf (e, _), [] -> [e]
    | tree, (ri::rothers) -> extract_tree ri tree
                              (fun tree -> shuffle' tree rothers)
    | _, _ -> failwith "randomness should be same length as t"

  let shuffle xs =
    let tree = create ~default_hole:() xs in
    let randomness = List.init (List.length xs - 1) ~f:(fun _ -> Random.bits ()) in
    shuffle' tree randomness
end

module Make
  (Input : sig
    type t [@@deriving eq, bin_io]
    include Constraint_count.Cost_s with type t := t
  end)
  (Proof : sig type t [@@deriving eq, bin_io] end)
  (Work : Work_intf.S with type proof := Proof.t and type input := Input.t)
  (Merge_cost : sig val cost : int end)
= struct
  module With_path = struct
    type 'a t =
      { path : bool list
      ; data : 'a
      }
    [@@deriving fields, bin_io]
  end

  module Evidence = struct
    type record =
      { work : Work.t
      ; proof : Proof.t
      }
    [@@deriving bin_io]

    type t = record With_path.t
    [@@deriving bin_io]

    let cost {With_path.data={work}} =
      Work.cost work

    let create {With_path.path;data} proof =
      {With_path.path; data={work=data; proof}}
  end

  module Index = struct
    type t = Work.t With_path.t list
    [@@deriving bin_io]
  end

  let rebuild_index tree =
    let rec go t path idx =
      let open Oleg_tree in
      let open Work in
      match tree with
      | Leaf (x, {contents=None}) -> {With_path.path; data=Base x}::idx
      | Leaf (_, {contents=Some _}) -> idx
      | Node (_, _, _, {contents=Some _}) -> idx
      | Node (_,
          Leaf (_, {contents=Some p1}),
          Leaf (_, {contents=Some p2}),
        {contents=None}) -> {path; data=Merge (p1, p2)}::idx
      | Node (_, l, r, {contents=None}) ->
          let idx' = go l (false::path) idx in
          go r (true::path) idx'
    in
    go tree [] []

  type t =
    { tree : (Input.t, Proof.t option ref) Oleg_tree.t
    ; index : Index.t
    }
  [@@deriving bin_io]

  (* TODO: Is greedy a decent heuristic here? Seems like it to me *)
  let random t ~geq:budget =
    let works = Oleg_tree.shuffle t.index in
    List.fold_until works ~init:(budget, []) ~f:(fun (budget, work) w ->
      if budget < 0 then
        Stop work
      else
        let open With_path in
        match w with
        | {path=_; data=Work.Base x} ->
          Continue (budget - (Input.cost x), w::work)
        | {path=_; data=Merge _} ->
          Continue (budget - Merge_cost.cost, w::work)
    )

  let create ~data =
    let tree = Oleg_tree.create data ~default_hole:(ref None) in
    { tree
    ; index = rebuild_index tree
    (* TODO: Is it worth it to special-case rebuild firsttime)
      let rec go c t path =
        let open Oleg_tree in
        match t with
        | Leaf _ -> List.rev path
        | Node (n, l, r, _) ->
          let lower_power_2 = Int.floor_log2(n) in
          if c < lower_power_2 then
            go c l (false::path)
          else
            go (c - lower_power_2) r (true::path)
      in
      let path = go i o_tree [] in
      (path, Work.Base (x, 1))
      *)
    }

  let free t =
    let rec go tree cost =
      let open Oleg_tree in
      let open Work in
      match tree with
      | Leaf (x, {contents=Some _}) -> Input.cost x
      | Leaf _ -> 0
      | Node (_, l, r, {contents=Some _}) ->
          let cost' = go l (Merge_cost.cost) in
          go r cost'
      | Node (_, _, _, {contents=None}) -> 0
    in
    go t.tree 0

  (* Try to annotate the tree with proofs,
   * returns all proofs that got filled in by someone else and the new tree *)
  let attempt_prove t proofs : t option * Evidence.t list =
    let rec go ps leftovers =
      let open With_path in
      match ps with
      | [] -> leftovers
      | evidence::rest ->
          let {path;data={Evidence.work;proof}} = evidence in
          let valid tree =
            let open Oleg_tree in
            let open Work in
            match (tree, work) with
            | Leaf (a, _), Base a' -> Input.equal a a'
            | Node (_,
                Leaf (_, {contents=Some p1}),
                Leaf (_, {contents=Some p2}),
              _), Merge (p1', p2') -> Proof.equal p1 p1' && Proof.equal p2 p2'
            | _ -> false
          in
          let path : bool list = path in
          let proof : 'pi = proof in
          (match Oleg_tree.find_hole t.tree path ~valid with
          | None
          | Some {contents=Some _} ->
            go rest (evidence::leftovers)
          | Some hole ->
            hole := Some proof;
            go rest leftovers
          )
    in
    let new_tree = { t with index = rebuild_index t.tree } in
    let new_tree =
      (* If there is no work left to do, then there is no new tree *)
      if List.length new_tree.index = 0 then
        None
      else
        Some new_tree
    in
    new_tree, go proofs []
end
