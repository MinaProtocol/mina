open Core_kernel

module Direction = struct
  type t =
    | Left
    | Right
  [@@deriving eq, bin_io]
end

module Dep_node = struct
  type 'a t =
    { data : 'a
    ; dep : ('a t * Direction.t) option
    }
  [@@deriving bin_io]

  let create a =
    { data = a; dep = None }

  let link ~dir ~src:t ~dst:t' =
    { t with dep = Some (t', dir) }
end

module Tree_like = struct
  module Node = struct
    type 'a t =
      | Node of 'a * 'a t * 'a t
      | Empty
  end

  (* A top and the rest of the tree *)
  type 'a t = 'a * 'a Node.t
end

(*
 *
 *        0
 *        4
 *    5       1
 *  2   3   6    7
 *
 *
 *
 *     1
 *   2  3
 *
 *     5
 *   6   7
 *
 *
 *)

let build_dependency_tree size_log_2 =

  let nums starting_at count = List.init count ~f:(fun i -> starting_at+i) in

  let build_layers num_layers =
    let rec go curr_layer i build =
      if curr_layer = 1 then
        build
      else
        let layer_idx = num_layers - curr_layer in
        let size = Int.pow 2 layer_idx in
        go (curr_layer-1) (i+size) ((nums i size)::build)
    in
    go num_layers 1 [] |> List.rev
  in

  let layers = build_layers (size_log_2+1) in
  let mid_point = Int.pow 2 size_log_2 in
  [mid_point] :: (
    List.mapi layers ~f:(fun i l ->
      let new_stuff = List.map l ~f:(fun x -> x + mid_point) in
      if (i mod 2) = 0 then
        new_stuff @ l
      else
        l @ new_stuff
    ))

let%test_unit "dependency tree works for small trees" =
  let tree_one =
    [    [2]
    ;  [3 ; 1]
    ]
  and tree_two =
    [    [4]
    ;  [5 ; 1]
    ; [2;3;6;7]
    ]
  and tree_three =
    [           [8]
    ;    [9      ;      1]
    ;  [2 ;   3  ;  10   ;   11]
    ;[12 ;13;14;15;4 ; 5; 6 ;  7]
    ]
  in

  assert (tree_one = (build_dependency_tree 1));
  assert (tree_two = (build_dependency_tree 2));
  assert (tree_three = (build_dependency_tree 3))

let build_dependency_map ~parallelism_log_2 =
  let dependency_tree = build_dependency_tree parallelism_log_2 in
  let table = Int.Table.create () in
  let zed = Dep_node.create 0 in
  Int.Table.set table ~key:0 ~data:zed;
  List.fold dependency_tree ~init:[zed] ~f:(fun acc layer ->
    let make dir src dst =
      let node = Dep_node.create src |> (fun src -> Dep_node.link ~src ~dst ~dir) in
      Int.Table.set table ~key:src ~data:node;
      node
    in
    let rec go last this build =
      let open Direction in
      match last,this with
      | [],[] -> build
      | l::last,t::t'::this ->
          go last this ((make Left t l)::(make Right t' l)::build)
      (* handle the first case *)
      | l::last,t::this ->
          go last this ((make Left t l)::build)
      | _, _ -> failwith "Impossible"
    in
    go acc layer []
  ) |> ignore;
  table

let%test_unit "dependency map from tree seems sane" =
  let map = build_dependency_map 2 in
  let points_to x y dir =
    let {Dep_node.data;dep} = Int.Table.find_exn map x in
    assert (x = data);
    match dep with
    | None -> failwithf "%d doesn't point to anything (it should have pointed to %d)" x y ()
    | Some ({data=y'}, dir') ->
        if y <> y' then begin
          failwithf "%d points to %d, but should have pointed to %d" x y' y ()
        end;
        if not (Direction.equal dir dir') then begin
          failwithf "%d points to %d, but should have pointed to %d" x y' y ()
        end
  in
  points_to 4 0 Left;
  points_to 5 4 Left;
  points_to 1 4 Right;
  points_to 2 5 Left;
  points_to 3 5 Right;
  points_to 6 1 Left;
  points_to 7 1 Right


