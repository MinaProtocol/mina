open Core_kernel

(* See https://en.wikipedia.org/wiki/Rose_tree *)
module Rose = struct
  type 'a t = Rose of 'a * 'a t list [@@deriving eq, sexp, bin_io, fold]

  let singleton a = Rose (a, [])

  let extract (Rose (x, _)) = x

  let gen a_gen =
    Quickcheck.Generator.fixed_point (fun self ->
        let open Quickcheck.Generator.Let_syntax in
        let%bind children = Quickcheck.Generator.list self in
        let%map a = a_gen in
        Rose (a, children) )

  module C = Container.Make (struct
    type nonrec 'a t = 'a t

    let fold t ~init ~f = fold f init t

    let iter = `Define_using_fold
  end)

  let to_list = C.to_list

  let to_array = C.to_array

  let mem = C.mem

  let find = C.find
end

(** A Rose tree with max-depth k. Whenever we want to add a node that would increase the depth past k, we instead move the tree forward and root it at the node towards that path *)
module Make (Elem : sig
  type t [@@deriving compare, bin_io, sexp]
end)
(Security : Protocols.Coda_pow.Security_intf) =
struct
  module Elem_set = Set.Make_binable (Elem)

  type t = {tree: Elem.t Rose.t; elems: Elem_set.t} [@@deriving sexp, bin_io]

  let root {tree; _} = Rose.extract tree

  let find_map {elems; _} ~f = Elem_set.find_map elems ~f

  (** Path from the root to the first node where the predicate returns true *)
  let path {tree; _} ~f =
    let rec go tree path =
      match tree with
      | Rose.Rose (x, _) when f x -> Some (x :: path)
      | Rose.Rose (x, []) when not (f x) -> None
      | Rose.Rose (x, children) ->
          List.find_map children ~f:(fun c -> go c (x :: path))
    in
    go tree [] |> Option.map ~f:List.rev

  let singleton (e : Elem.t) : t =
    {tree= Rose.singleton e; elems= Elem_set.singleton e}

  let gen elem_gen =
    let open Quickcheck.Generator.Let_syntax in
    (* We need to force the ref to be under the monad so it regenerates *)
    let%bind () = return () in
    let r = ref Elem_set.empty in
    let elem_unique_gen =
      let%map e =
        Quickcheck.Generator.filter elem_gen ~f:(fun e ->
            not (Elem_set.mem !r e) )
      in
      r := Elem_set.add !r e ;
      e
    in
    let%map tree = Rose.gen elem_unique_gen in
    {tree; elems= !r}

  (* Note: This won't work in proof-of-work, but it's not a prefix of the proof-of-stakeversion, so I'm just going to use a longest heuristic for now *)
  let longest_path {tree; _} =
    let rec go tree depth path =
      match tree with
      | Rose.Rose (x, []) -> (x :: path, depth)
      | Rose.Rose (x, children) ->
          let path_depths =
            List.map children ~f:(fun c -> go c (depth + 1) (x :: path))
          in
          List.max_elt path_depths ~compare:(fun (_, d) (_, d') ->
              Int.compare d d' )
          |> Option.value_exn
    in
    go tree 0 [] |> fst |> List.rev

  (** Extends tree with e at the first node n where (parent n) returns true *)
  let add t e ~parent =
    if Elem_set.mem t.elems e then `Repeat
    else if Elem_set.find t.elems ~f:parent |> Option.is_none then `No_parent
    else
      let rec go node depth =
        let (Rose.Rose (x, xs)) = node in
        if parent x then (Rose.Rose (x, Rose.singleton e :: xs), depth + 1)
        else
          let xs, ds =
            List.map xs ~f:(fun x -> go x (depth + 1)) |> List.unzip
          in
          (Rose.Rose (x, xs), List.fold ds ~init:0 ~f:max)
      in
      let root, tree_and_depths =
        let (Rose.Rose (root, root_children)) = t.tree in
        let children_and_depths =
          List.map root_children ~f:(fun x -> go x 1)
        in
        if parent root then (root, (Rose.singleton e, 1) :: children_and_depths)
        else (
          assert (List.length root_children <> 0) ;
          (root, children_and_depths) )
      in
      let default =
        { tree= Rose.Rose (root, tree_and_depths |> List.map ~f:fst)
        ; elems= Elem_set.add t.elems e }
      in
      match tree_and_depths with
      | [] | [_] -> `Added default
      | _ ->
          let longest_subtree, longest_depth =
            List.max_elt tree_and_depths ~compare:(fun (_, d) (_, d') ->
                Int.compare d d' )
            |> Option.value_exn
          in
          let ( >= ) a b =
            match b with `Infinity -> false | `Finite b -> a >= b
          in
          if longest_depth >= Security.max_depth then
            `Added
              { tree= longest_subtree
              ; elems= Elem_set.of_list (Rose.to_list longest_subtree) }
          else `Added default
end

let%test_module "K-tree" =
  ( module struct
    module Make_quickchecks (Elem : sig
      type t [@@deriving eq, compare, bin_io, sexp]

      val gen : t Quickcheck.Generator.t
    end) (Security : sig
      val max_depth : int
    end) =
    struct
      include Make
                (Elem)
                (struct
                  let max_depth = `Finite Security.max_depth
                end)

      let%test_unit "Adding an element either changes the tree or it was \
                     already in the set" =
        Quickcheck.test ~sexp_of:[%sexp_of: t * Elem.t * Elem.t]
          (let open Quickcheck.Generator.Let_syntax in
          let%bind r = gen Elem.gen and e = Elem.gen in
          let candidates = Rose.to_array r.tree in
          let%map idx = Int.gen_incl 0 (Array.length candidates - 1) in
          (r, e, candidates.(idx)))
          ~f:(fun (r, e, parent) ->
            match add r e ~parent:(Elem.equal parent) with
            | `No_parent -> failwith "Unexpected"
            | `Repeat -> assert (Elem_set.mem r.elems e)
            | `Added r' -> assert (not (Rose.equal Elem.equal r.tree r'.tree))
            )

      let%test_unit "Adding to the end of the longest_path extends the path \
                     (modulo the last thing / first-thing)" =
        Quickcheck.test ~sexp_of:[%sexp_of: t * Elem.t]
          ( Quickcheck.Generator.tuple2 (gen Elem.gen) Elem.gen
          |> Quickcheck.Generator.filter ~f:(fun (r, e) ->
                 not (Rose.mem r.tree e ~equal:Elem.equal) ) )
          ~f:(fun (r, e) ->
            let path = longest_path r in
            match add r e ~parent:(Elem.equal (List.last_exn path)) with
            | `No_parent | `Repeat -> failwith "Unexpected"
            | `Added r' ->
                assert (Elem.equal e (List.last_exn (longest_path r'))) ;
                (* If there were two paths of the same length, we may be missing the
             * last thing in our first path *)
                let path = longest_path r in
                let potential_prefix = List.take path (List.length path - 1) in
                let path' = longest_path r' in
                assert (
                  List.is_prefix ~equal:Elem.equal ~prefix:potential_prefix
                    path'
                  || List.is_prefix ~equal:Elem.equal
                       ~prefix:(List.drop potential_prefix 1)
                       path' ) )

      let%test_unit "There exists a path between the root and any node" =
        Quickcheck.test ~sexp_of:[%sexp_of: t * Elem.t]
          (let open Quickcheck.Generator.Let_syntax in
          let%bind r = gen Elem.gen in
          let%map e =
            Quickcheck.Generator.of_list (Elem_set.to_list r.elems)
          in
          (r, e))
          ~f:(fun (r, e) -> assert (Option.is_some (path r ~f:(Elem.equal e))))

      let%test_unit "Extending a tree with depth-k, extends full-tree properly"
          =
        let elem_pairs =
          Quickcheck.random_value ~seed:(`Deterministic "seed")
            (Quickcheck.Generator.list_with_length Security.max_depth
               (Quickcheck.Generator.tuple2 Elem.gen Elem.gen))
        in
        let (e1, e2), es = (List.hd_exn elem_pairs, List.tl_exn elem_pairs) in
        let t =
          let tree =
            List.fold es
              ~init:(Rose.Rose (e1, []))
              ~f:(fun r (e, e') -> Rose.Rose (e, [Rose.singleton e'; r]))
          in
          {tree; elems= Elem_set.of_list (Rose.to_list tree)}
        in
        assert (List.length (longest_path t) = Security.max_depth) ;
        let (Rose.Rose (head, first_children)) = t.tree in
        match add t e2 ~parent:(Elem.equal e1) with
        | `No_parent | `Repeat -> failwith "Unexpected"
        | `Added t' ->
            assert (List.length (longest_path t') = Security.max_depth) ;
            assert (not (Rose.mem t'.tree head ~equal:Elem.equal)) ;
            assert (
              not
                (Rose.mem t'.tree
                   (Rose.extract (List.hd_exn first_children))
                   ~equal:Elem.equal) ) ;
            assert (
              Rose.mem t'.tree
                (Rose.extract (List.nth_exn first_children 1))
                ~equal:Elem.equal )
    end

    module Tree =
      Make_quickchecks
        (Int)
        (struct
          let max_depth = 10
        end)

    module Big_tree =
      Make_quickchecks
        (Int)
        (struct
          let max_depth = 50
        end)

    let sample_tree =
      { Tree.tree=
          Rose.Rose (1, [Rose.Rose (2, [Rose.singleton 3]); Rose.singleton 4])
      ; elems= Tree.Elem_set.of_list [1; 2; 3; 4] }

    let%test_unit "longest_path finds longest path" =
      assert (
        List.equal ~equal:Int.equal (Tree.longest_path sample_tree) [1; 2; 3]
      )

    let%test_unit "Adding with an always false parent reports No_parent" =
      match Tree.add sample_tree 5 ~parent:(fun _ -> false) with
      | `No_parent -> ()
      | _ -> failwith "Unexpected"

    let%test_unit "Paths are found in the middle of some tree" =
      assert (
        List.equal ~equal:Int.equal
          (Tree.path sample_tree ~f:(Int.equal 2) |> Option.value_exn)
          [1; 2] )
  end )
