open Core

(** A digit is a container of 1-4 elements. *)
module Digit = struct
  (* We use GADTs to track whether it's valid to remove/add an element to a
     digit, which gets us type safe (un)cons and (un)snoc. *)

  [@@@warning "-37"]

  type addable = Type_addable

  type not_addable = Type_not_addable

  type removable = Type_removable

  type not_removable = Type_not_removable

  [@@@warning "+37"]

  type (_, _, 'e) t =
    | One : 'e -> (addable, not_removable, 'e) t
    | Two : 'e * 'e -> (addable, removable, 'e) t
    | Three : 'e * 'e * 'e -> (addable, removable, 'e) t
    | Four : 'e * 'e * 'e * 'e -> (not_addable, removable, 'e) t

  (* "Eliminators" dispatching on addability/removability. You could achieve
      the same effect more directly using or-patterns, but the code that
      makes the typechecker understand existentials under or-patterns isn't
      in our compiler version. (ocaml/ocaml#2110)
  *)
  let addable_elim : type a r.
         ((addable, r, 'e) t -> 'o) (** Function handling addable case *)
      -> ((not_addable, removable, 'e) t -> 'o)
         (** Function handling non-addable case *)
      -> (a, r, 'e) t
      -> 'o =
   fun f g t ->
    match t with One _ -> f t | Two _ -> f t | Three _ -> f t | Four _ -> g t

  let removable_elim : type a r.
         ((a, removable, 'e) t -> 'o) (** Function handling removable case*)
      -> ((addable, not_removable, 'e) t -> 'o)
         (** Function handling non-removable case *)
      -> (a, r, 'e) t
      -> 'o =
   fun f g t ->
    match t with One _ -> g t | Two _ -> f t | Three _ -> f t | Four _ -> f t

  (** Existential type for when addability is determined at runtime. *)
  type ('r, 'e) t_any_a = Mk_any_a : ('a, 'r, 'e) t -> ('r, 'e) t_any_a

  (** Same for removability. *)
  type ('a, 'e) t_any_r = Mk_any_r : ('a, 'r, 'e) t -> ('a, 'e) t_any_r

  (** Both. *)
  type 'e t_any_ar = Mk_any_ar : ('a, 'r, 'e) t -> 'e t_any_ar

  (** "Broaden" a t_any_a into a t_any_ar, i.e. forget that we know the
      removability status. *)
  let broaden_any_a : ('r, 'e) t_any_a -> 'e t_any_ar =
   fun (Mk_any_a t) -> Mk_any_ar t

  (** Same deal for t_any_r *)
  let broaden_any_r : ('a, 'e) t_any_r -> 'e t_any_ar =
   fun (Mk_any_r t) -> Mk_any_ar t

  let cons : type r. 'e -> (addable, r, 'e) t -> (removable, 'e) t_any_a =
   fun v d ->
    match d with
    | One a ->
        Mk_any_a (Two (v, a))
    | Two (a, b) ->
        Mk_any_a (Three (v, a, b))
    | Three (a, b, c) ->
        Mk_any_a (Four (v, a, b, c))

  let snoc : type r. (addable, r, 'e) t -> 'e -> (removable, 'e) t_any_a =
   fun d v ->
    match d with
    | One a ->
        Mk_any_a (Two (a, v))
    | Two (a, b) ->
        Mk_any_a (Three (a, b, v))
    | Three (a, b, c) ->
        Mk_any_a (Four (a, b, c, v))

  let uncons : type a. (a, removable, 'e) t -> 'e * (addable, 'e) t_any_r =
    function
    | Two (a, b) ->
        (a, Mk_any_r (One b))
    | Three (a, b, c) ->
        (a, Mk_any_r (Two (b, c)))
    | Four (a, b, c, d) ->
        (a, Mk_any_r (Three (b, c, d)))

  let unsnoc : type a. (a, removable, 'e) t -> (addable, 'e) t_any_r * 'e =
    function
    | Two (a, b) ->
        (Mk_any_r (One a), b)
    | Three (a, b, c) ->
        (Mk_any_r (Two (a, b)), c)
    | Four (a, b, c, d) ->
        (Mk_any_r (Three (a, b, c)), d)

  let foldr : type a r. ('e -> 'acc -> 'acc) -> 'acc -> (a, r, 'e) t -> 'acc =
   fun f z d ->
    match d with
    | One a ->
        f a z
    | Two (a, b) ->
        f a (f b z)
    | Three (a, b, c) ->
        f a (f b (f c z))
    | Four (a, b, c, d) ->
        f a (f b (f c (f d z)))

  let foldl : type a r. ('acc -> 'e -> 'acc) -> 'acc -> (a, r, 'e) t -> 'acc =
   fun f z d ->
    match d with
    | One a ->
        f z a
    | Two (a, b) ->
        f (f z a) b
    | Three (a, b, c) ->
        f (f (f z a) b) c
    | Four (a, b, c, d) ->
        f (f (f (f z a) b) c) d

  let to_list : type a r. (a, r, 'e) t -> 'e list =
   fun t -> foldr List.cons [] t

  let gen_any_ar : int t_any_ar Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let gen_measure = Int.gen_incl 1 20 in
    let%bind a, b, c, d =
      Quickcheck.Generator.tuple4 gen_measure gen_measure gen_measure
        gen_measure
    in
    Quickcheck.Generator.of_list
      [ Mk_any_ar (One a)
      ; Mk_any_ar (Two (a, b))
      ; Mk_any_ar (Three (a, b, c))
      ; Mk_any_ar (Four (a, b, c, d)) ]

  (** Given a measurement function, compute the total measure of a digit.
      See below for an explanation of what measure is.
  *)
  let measure : ('e -> int) -> (_, _, 'e) t -> int =
   fun measure' -> foldl (fun m e -> m + measure' e) 0

  (** Split a digit by measure. Again see below. *)
  let split : type a r.
         ('e -> int)
      -> int
      -> int
      -> (a, r, 'e) t
      -> 'e t_any_ar option * 'e * 'e t_any_ar option =
   fun measure' target acc t ->
    (* Addable inputs go to addable outputs, but non-addable inputs may go to
       either. We use a separate function for addables to represent this and
       minimizing the amount of Obj.magicking we need to do. *)
    let rec split_addable : type r.
           int
        -> (addable, r, 'e) t
        -> (addable, 'e) t_any_r option * 'e * (addable, 'e) t_any_r option =
     fun acc t ->
      removable_elim
        (fun t' ->
          let head, Mk_any_r tail = uncons t' in
          if acc + measure' head > target then
            (None, head, Some (Mk_any_r tail))
          else
            match split_addable (acc + measure' head) tail with
            | Some (Mk_any_r lhs), m, rhs ->
                let (Mk_any_a cons_res) = cons head lhs in
                (* t' is addable, so the tail of t' is twice-addable. We just
                   passed that tail to split_addable, which always returns
                   digits with <= the number of elements of the input. So
                   cons_res is addable but it's not possible to convince the
                   typechecker of that, as far as I can tell.
                *)
                let cons_res' : (addable, removable, 'e) t =
                  Obj.magic cons_res
                in
                (Some (Mk_any_r cons_res'), m, rhs)
            | None, m, rhs ->
                (Some (Mk_any_r (One head)), m, rhs) )
        (fun (One a) ->
          if acc + measure' a > target then (None, a, None)
          else failwith "Digit.split index out of bounds" )
        t
    in
    addable_elim
      (fun t' ->
        let lhs, m, rhs = split_addable acc t' in
        (Option.map ~f:broaden_any_r lhs, m, Option.map ~f:broaden_any_r rhs)
        )
      (fun t' ->
        let head, Mk_any_r tail = uncons t' in
        if acc + measure' head > target then (None, head, Some (Mk_any_ar tail))
        else
          let lhs, m, rhs = split_addable (acc + measure' head) tail in
          match lhs with
          | None ->
              (Some (Mk_any_ar (One head)), m, Option.map ~f:broaden_any_r rhs)
          | Some (Mk_any_r lhs') ->
              ( Some (broaden_any_a (cons head lhs'))
              , m
              , Option.map ~f:broaden_any_r rhs ) )
      t

  let opt_to_list : 'a t_any_ar option -> 'a list = function
    | None ->
        []
    | Some (Mk_any_ar dig) ->
        to_list dig

  let%test_unit "Digit.split preserves contents and order" =
    Quickcheck.test
      (let open Quickcheck.Generator.Let_syntax in
      let%bind (Mk_any_ar dig as dig') = gen_any_ar in
      let%bind idx = Int.gen_incl 0 ((List.length @@ to_list dig) - 1) in
      return (dig', idx))
      ~f:(fun (Mk_any_ar dig, target) ->
        let lhs_opt, m, rhs_opt = split Fn.id target 0 dig in
        let lhs', rhs' = (opt_to_list lhs_opt, opt_to_list rhs_opt) in
        [%test_eq: int list] (lhs' @ [m] @ rhs') (to_list dig) )

  let%test_unit "Digit.split matches list implementation" =
    Quickcheck.test
      ~sexp_of:(fun (Mk_any_ar dig, idx) ->
        Tuple2.sexp_of_t
          (List.sexp_of_t Int.sexp_of_t)
          Int.sexp_of_t
          (to_list dig, idx) )
      ~shrinker:
        (Quickcheck.Shrinker.create (fun (Mk_any_ar dig, idx) ->
             removable_elim
               (fun t ->
                 let len = List.length @@ to_list t in
                 Sequence.of_list
                   ( (if idx > 0 then [(Mk_any_ar dig, idx - 1)] else [])
                   @ [ ( broaden_any_r (Tuple2.get2 @@ uncons t)
                       , Int.max (len - 2) idx ) ] ) )
               (fun t ->
                 if idx = 1 then Sequence.singleton (Mk_any_ar t, idx - 1)
                 else Sequence.empty )
               dig ))
      (let open Quickcheck.Generator.Let_syntax in
      let%bind (Mk_any_ar dig) = gen_any_ar in
      let%bind idx = Int.gen_incl 0 ((List.length @@ to_list dig) - 1) in
      return (Mk_any_ar dig, idx))
      ~f:(fun (Mk_any_ar dig, idx) ->
        let as_list = to_list dig in
        let lhs_list = List.take as_list idx in
        let m_list = List.nth_exn as_list idx in
        let rhs_list = List.drop as_list (idx + 1) in
        [%test_eq: int list] (lhs_list @ (m_list :: rhs_list)) as_list ;
        let lhs_fseq, m_fseq, rhs_fseq = split (Fn.const 1) idx 0 dig in
        let lhs_fseq', rhs_fseq' =
          (opt_to_list lhs_fseq, opt_to_list rhs_fseq)
        in
        [%test_eq: int list] (lhs_fseq' @ (m_fseq :: rhs_fseq')) (to_list dig) ;
        [%test_eq: int list] lhs_list lhs_fseq' ;
        [%test_eq: int] m_list m_fseq ;
        [%test_eq: int list] rhs_list rhs_fseq' ;
        [%test_eq: int] (List.length lhs_fseq') idx ;
        [%test_eq: int] (List.length rhs_fseq') (List.length as_list - idx - 1)
        )

  let%test _ =
    match split Fn.id 0 0 (One 1) with None, 1, None -> true | _ -> false

  let%test _ =
    match split Fn.id 5 0 (Three (0, 2, 4)) with
    | Some (Mk_any_ar (Two (0, 2))), 4, None ->
        true
    | _ ->
        false

  let%test _ =
    match split Fn.id 10 0 (Four (2, 3, 5, 1)) with
    | Some (Mk_any_ar (Three (2, 3, 5))), 1, None ->
        true
    | _ ->
        false

  let%test _ =
    match split Fn.id 7 0 (Four (2, 4, 3, 2)) with
    | Some (Mk_any_ar (Two (2, 4))), 3, Some (Mk_any_ar (One 2)) ->
        true
    | _ ->
        false
end

(** Nodes containing 2-3 elements, with a cached measurement. *)
module Node = struct
  (** This implementation doesn't actually use 2-nodes, but they're here for
      future use. The paper uses them in the append operation, which isn't
      implemented here.
  *)
  type 'e t = Two of int * 'e * 'e | Three of int * 'e * 'e * 'e
  [@@deriving sexp]

  (** Extract the cached measurement *)
  let measure : 'e t -> int =
   fun t -> match t with Two (m, _, _) -> m | Three (m, _, _, _) -> m

  let to_digit : 'e t -> (Digit.addable, Digit.removable, 'e) Digit.t =
    function
    | Two (_m, a, b) ->
        Digit.Two (a, b)
    | Three (_m, a, b, c) ->
        Digit.Three (a, b, c)

  (* smart constructors to maintain correct measures *)
  let _mk_2 : ('e -> int) -> 'e -> 'e -> 'e t =
   fun f a b -> Two (f a + f b, a, b)

  let mk_3 : ('e -> int) -> 'e -> 'e -> 'e -> 'e t =
   fun f a b c -> Three (f a + f b + f c, a, b, c)

  let split_to_digits :
         ('e -> int)
      -> int
      -> int
      -> 'e t
      -> 'e Digit.t_any_ar option * 'e * 'e Digit.t_any_ar option =
    fun measure' target acc t -> 
    Core.printf "split_to_digits target=%d acc=%d\n%!" target acc;
    to_digit t |> Digit.split measure' target acc
end

(** Finally, the actual finger tree type! *)
type 'e t =
  | Empty : 'e t  (** Empty tree *)
  | Single : 'e -> 'e t  (** Single element tree *)
  | Deep :
      ( int
      * ('aL, 'rL, 'e) Digit.t
      * 'e Node.t t Lazy.t
      * ('aR, 'rR, 'e) Digit.t )
      -> 'e t
      (** The recursive case. We have a cached measurement, prefix and suffix
          fingers, and a subtree. Note the subtree has a different type than its
          parent. The top level has 'es, the next level has 'e Node.ts, the next
          has 'e Node.t Node.ts and so on. As you go deeper, the breadth
          increases exponentially. *)
    module Untyped = struct
      module Digit = struct
        type 'e t =
          | One of 'e
          | Two of 'e * 'e
          | Three of 'e * 'e * 'e
          | Four of 'e * 'e * 'e * 'e
        [@@deriving sexp]
      end

      type 'e t =
        | Empty   (** Empty tree *)
        | Single of 'e  (** Single element tree *)
        | Deep of
              int
            * 'e Digit.t
            * 'e Node.t t
            * 'e Digit.t
        [@@deriving sexp]

        let digit_to_string f t= 
          let s, xs = 
            match t with
            | Digit.One x -> "One", [ x]
            | Two (x, y) -> "Two", [x; y]
            | Three (x, y, z) -> "Three", [x; y; z]
            | Four (x, y, z, w) -> "Four", [x; y; z; w]
          in
          let open Core in
          sprintf "%s (%s)"
            s (String.concat ~sep:"," (List.map ~f xs))


        let node_to_string f t= 
          let s, n, xs = 
            match t with
            | Node.Two (n, x, y) -> "Two", n, [x; y]
            | Three (n, x, y, z) -> "Three", n, [x; y; z]
          in
          let open Core in
          sprintf "%s (%s)"
            s (String.concat ~sep:"," (Int.to_string n :: List.map ~f xs))

      let rec to_string : type e. (e -> string) -> e t -> string = fun f -> function
        | Empty -> "Empty"
        | Single x -> sprintf "Single (%s)" (f x)
        | Deep (n, l, t, r) ->
          sprintf "Deep (%d, %s, %s, %s)"
            n
            (digit_to_string f l)
            (sprintf "lazy (%s)" (to_string (node_to_string f) t))
            (digit_to_string f r)
    end

    let untype_digit  (type a b) (d : (a, b, 'e) Digit.t) : 'e Untyped.Digit.t = 
      match d with
      | One x -> One x
      | Two (x, y) -> Two (x, y)
      | Three (x, y, z) -> Three (x, y, z)
      | Four (x, y, z, w) -> Four (x, y, z, w)

    let rec untype : type e. e t -> e Untyped.t =
      function
      | Empty -> Empty
      | Single x -> Single x
      | Deep (n, dl, nt_thunk, dr) ->
        Deep (n, untype_digit dl, untype (Lazy.force nt_thunk) , untype_digit dr)


(* About measurements: in the paper they define finger trees more generally than
   this implementation. Given a monoid m, a measurement function for elements
   e -> m, and "monotonic" predicates on m, if you cache the measure of subtrees
   you can index into and split finger trees at the transition point of the
   predicates in log time. In this implementation the monoid is natural numbers
   under summation, the measurement is 'Fn.const 1' and the predicates are
   (fun x -> x > idx). So the measure of a tree is how many elements are in it
   and the transition point is where there are idx elements to the left.

   You'll see many functions take a parameter measure' to compute measures of
   elements with. This is always either Node.measure or 'Fn.const 1' depending
   on if we're at the top level or not.

   Other measurement functions and monoids get you priority queues, search trees
   and interval trees.
*)
let measure : ('e -> int) -> 'e t -> int =
 fun measure' t ->
  match t with Empty -> 0 | Single a -> measure' a | Deep (m, _, _, _) -> m

(** Smart constructor for deep nodes that tracks measure. *)
let deep :
       ('e -> int)
    -> (_, _, 'e) Digit.t
    -> 'e Node.t t
    -> (_, _, 'e) Digit.t
    -> 'e t =
 fun measure' prefix middle suffix ->
  Deep
    ( Digit.measure measure' prefix
      + measure Node.measure middle
      + Digit.measure measure' suffix
    , prefix
    , lazy middle
    , suffix )

let empty : 'e t = Empty

(** Add a new element to the left end of the tree. *)
let rec cons' : 'e. ('e -> int) -> 'e -> 'e t -> 'e t =
 fun measure' v t ->
  match t with
  | Empty ->
      Single v
  | Single v' ->
      deep measure' (Digit.One v) Empty (Digit.One v')
  | Deep (_, prefix, middle, suffix) ->
      (* If there is space in the left finger, the finger is the only thing that
         needs to change. If not we need to make a recursive call. A recursive
         call frees up two finger slots and is needed every third cons
         operation, so the amortized cost is constant for a two layer tree.
         Because each level triples the number of elements in the fingers, we
         free up 2 * 3^level slots per recursive call and need to do so every
         2 * 3^level conses. So cons is amortized O(1) for arbitrary depth
         trees.
      *)
      Digit.addable_elim
        (fun prefix' ->
          let (Mk_any_a prefix'') = Digit.cons v prefix' in
          deep measure' prefix'' (Lazy.force middle) suffix )
        (fun (Four (a, b, c, d)) ->
          deep measure'
            (Digit.Two (v, a))
            (cons' Node.measure (Node.mk_3 measure' b c d) @@ Lazy.force middle)
            suffix )
        prefix

let cons : 'e -> 'e t -> 'e t = fun x xs -> cons' (Fn.const 1) x xs

(** Add a new element to the right end of the tree. This is a mirror of cons' *)
let rec snoc' : 'e. ('e -> int) -> 'e t -> 'e -> 'e t =
 fun measure' t v ->
  match t with
  | Empty ->
      Single v
  | Single v' ->
      deep measure' (Digit.One v') Empty (Digit.One v)
  | Deep (_, prefix, middle, suffix) ->
      Digit.addable_elim
        (fun digit ->
          let (Mk_any_a digit') = Digit.snoc digit v in
          deep measure' prefix (Lazy.force middle) digit' )
        (fun (Four (a, b, c, d)) ->
          deep measure' prefix
            (snoc' Node.measure (Lazy.force middle) @@ Node.mk_3 measure' a b c)
            (Digit.Two (d, v)) )
        suffix

let snoc : 'e t -> 'e -> 'e t = fun xs x -> snoc' (Fn.const 1) xs x

(** Create a finger tree from a digit *)
let tree_of_digit : ('e -> int) -> ('a, 'r, 'e) Digit.t -> 'e t =
 fun measure' dig -> Digit.foldr (cons' measure') Empty dig

(** If the input is non-empty, get the first element and the rest of the
    sequence. If it is empty, return None. *)
let rec uncons' : 'e. ('e -> int) -> 'e t -> ('e * 'e t) option =
 fun measure' t ->
  match t with
  | Empty ->
      None
  | Single e ->
      Some (e, empty)
  | Deep (_m, prefix, middle, suffix) ->
      Digit.removable_elim
        (fun prefix' ->
          let head, Mk_any_r prefix_rest = Digit.uncons prefix' in
          Some (head, deep measure' prefix_rest (force middle) suffix) )
        (fun (One e) ->
          match uncons' Node.measure (force middle) with
          | None ->
              Some (e, tree_of_digit measure' suffix)
          | Some (node, rest) ->
              Some (e, deep measure' (Node.to_digit node) rest suffix) )
        prefix

(** Uncons for the top level trees. *)
let uncons : 'e t -> ('e * 'e t) option = fun t -> uncons' (Fn.const 1) t

(** Mirror of uncons' for the last element. *)
let rec unsnoc' : 'e. ('e -> int) -> 'e t -> ('e t * 'e) option =
 fun measure' t ->
  match t with
  | Empty ->
      None
  | Single e ->
      Some (empty, e)
  | Deep (_m, prefix, middle, suffix) ->
      Digit.removable_elim
        (fun suffix' ->
          let Mk_any_r liat, deah = Digit.unsnoc suffix' in
          Some (deep measure' prefix (force middle) liat, deah) )
        (fun (One e) ->
          match unsnoc' Node.measure (force middle) with
          | None ->
              Some (tree_of_digit measure' prefix, e)
          | Some (rest, node) ->
              Some (deep measure' prefix rest (Node.to_digit node), e) )
        suffix

(** Mirror of uncons. *)
let unsnoc : 'e t -> ('e t * 'e) option = fun t -> unsnoc' (Fn.const 1) t

let head_exn : 'e t -> 'e = fun t -> Option.value_exn (uncons t) |> Tuple2.get1

let last_exn : 'e t -> 'e =
 fun t -> unsnoc t |> Option.value_exn |> Tuple2.get2

let rec foldl : ('a -> 'e -> 'a) -> 'a -> 'e t -> 'a =
 fun f acc t ->
  match uncons t with
  | None ->
      acc
  | Some (head, tail) ->
      foldl f (f acc head) tail

let rec foldr : ('e -> 'a -> 'a) -> 'a -> 'e t -> 'a =
 fun f acc t ->
  match uncons t with
  | None ->
      acc
  | Some (head, tail) ->
      f head (foldr f acc tail)

module C = Container.Make (struct
  type nonrec 'a t = 'a t

  let fold : 'a t -> init:'accum -> f:('accum -> 'a -> 'accum) -> 'accum =
   fun t ~init ~f -> foldl f init t

  let iter = `Define_using_fold

  let length = `Custom (fun t -> measure (Fn.const 1) t)
end)

let is_empty = C.is_empty

let length = C.length

let iter = C.iter

let to_seq : 'e t -> 'e Sequence.t = fun t -> Sequence.unfold ~init:t ~f:uncons

let sexp_of_t : ('e -> Sexp.t) -> 'e t -> Sexp.t =
 fun sexp_inner -> Fn.compose (Sequence.sexp_of_t sexp_inner) to_seq

let rec equal : ('e -> 'e -> bool) -> 'e t -> 'e t -> bool =
 fun eq_inner xs ys ->
  match (uncons xs, uncons ys) with
  | Some (x, xs_tail), Some (y, ys_tail) ->
      eq_inner x y && equal eq_inner xs_tail ys_tail
  | _ ->
      false

let to_list : 'e t -> 'e list = Fn.compose Sequence.to_list to_seq

let of_list : 'e list -> 'e t = List.fold_left ~init:empty ~f:snoc

    let digit_len : type l r e. (l, r, e) Digit.t -> (e -> int) -> int =
      fun t len ->
        let xs =
          match t with
          | One x -> [ x]
          | Two (x, y) -> [x; y]
          | Three (x, y, z) -> [x; y; z]
          | Four (x, y, z, w) -> [x; y; z; w]
        in
        List.sum (module Int) ~f:len xs

  let rec check_lengths : type e. e t -> (e -> int) -> int =
    fun t len ->
      let check_node_len : e Node.t -> int =
        fun n ->
          match n with
          | Two (expected, x, y) ->
            [%test_eq: int]
              expected ( len x + len y);
            expected
          | Three (expected, x, y, z) ->
            [%test_eq: int]
              expected (len x + len y + len z);
            expected
      in
      match t with
      | Empty -> 0
      | Single e -> len e
      | Deep (expected_len, dl, tn_thunk, dr) ->
        let len_l = digit_len dl len  in
        let len_tn = check_lengths (Lazy.force tn_thunk) check_node_len in
        let len_r = digit_len dr len  in
        [%test_eq: int] expected_len (len_l + len_tn + len_r);
        expected_len


(* Split a tree into the elements before a given index, the element at that
   index and the elements after it. The index must exist in the tree. *)
let rec split : 'e. ('e -> int) -> 'e t -> int -> int -> 'e t * 'e * 'e t =
 fun measure' t target acc ->
  Core.printf "%d %d %s\n%!"
    target acc (Untyped.to_string (fun _e -> Int.to_string 0) (untype t));
  match t with
  | Empty ->
      failwith "FSequence.split index out of bounds (1)"
  | Single x ->
      if acc + measure' x > target then (Empty, x, Empty)
      else failwith "FSequence.split index out of bounds (2)"
  | Deep (_m, prefix, middle, suffix) ->
      let acc_p = acc + Digit.measure measure' prefix in
      Core.printf "  deep: acc=%d prefix=%d acc_p=%d\n%!"
        acc (Digit.measure measure' prefix) acc_p;
      if acc_p > target then (
        (* split point is in left finger *)
        Core.printf "here\n%!";
        let dl, m, dr = Digit.split measure' target acc prefix in
        Core.printf "through\n%!";
        ( Digit.opt_to_list dl |> of_list (* left part of digit split *)
        , m (* middle of digit split *)
        , match dr with
          (* right part of digit split + subtree + suffix *)
          | None -> (
            match uncons' Node.measure @@ force middle with
            | None ->
                tree_of_digit measure' suffix
            | Some (head, tail) ->
                deep measure' (Node.to_digit head) tail suffix )
          | Some (Mk_any_ar dig) ->
              deep measure' dig (force middle) suffix )
      ) else (
        let acc_m = acc_p + measure Node.measure (force middle) in
        Core.printf " acc_m branch: acc=%d prefix=%d acc_p=%d acc_m=%d \n%!"
          acc (Digit.measure measure' prefix) acc_p acc_m;
        if acc_m > target then (
          (* split point is in subtree *)
          Core.printf "YO!\n%!";
          let lhs, m, rhs = split Node.measure (force middle) target acc_p in
          (* The subtree is made of nodes, so the midpoint we got from the
             recursive call is a node, so split that. *)
          let m_lhs, m_m, m_rhs =
            let arg  = measure Node.measure lhs + acc_p in
            Core.printf "calling split to digits: target=%d arg=%d\n%!" 
              target arg;
            Node.split_to_digits measure' target
              arg
              m
          in
          ( (* prefix + lhs of the split of the subtree + lhs of the split of
               them midpoint of the subtree *)
            ( match m_lhs with
            | None -> (
              match unsnoc' Node.measure lhs with
              | None ->
                  tree_of_digit measure' prefix
              | Some (liat, deah) ->
                  deep measure' prefix liat (Node.to_digit deah) )
            | Some (Mk_any_ar dig) ->
                deep measure' prefix lhs dig )
          , (* midpoint of the split of the subtree *)
            m_m
          , (* rhs of the split of the midpoint of the subtree + rhs of the
               split of the subtree + suffix *)
            match m_rhs with
            | None -> (
              match uncons' Node.measure rhs with
              | None ->
                  tree_of_digit measure' suffix
              | Some (head, tail) ->
                  deep measure' (Node.to_digit head) tail suffix )
            | Some (Mk_any_ar dig) ->
                deep measure' dig rhs suffix )
        ) else
          let acc_s = acc_m + Digit.measure measure' suffix in
          if acc_s > target then
            (* split point is in right finger *)
            let dl, m, dr = Digit.split measure' target acc_m suffix in
            ( (* prefix + subtree + left part of digit split *)
              ( match dl with
              | None -> (
                match unsnoc' Node.measure (force middle) with
                | None ->
                    tree_of_digit measure' prefix
                | Some (liat, deah) ->
                    deep measure' prefix liat (Node.to_digit deah) )
              | Some (Mk_any_ar dig) ->
                  deep measure' prefix (force middle) dig )
            , (* midpoint of digit split *)
              m
            , (* right part of digit split *)
              match dr with
              | None ->
                  Empty
              | Some (Mk_any_ar dig) ->
                  tree_of_digit measure' dig )
          else failwith "FSequence.split index out of bounds (3)"
      )

(* Split a tree into the elements before some index and the elements >= that
   index. split_at works when the index is out of range and returns a pair while
   split throws an exception if the index is out of range and returns a triple.
*)
let split_at : 'e t -> int -> 'e t * 'e t =
 fun t idx ->
  if measure (Fn.const 1) t > idx then
    match split (Fn.const 1) t idx 0 with lhs, m, rhs -> (lhs, cons m rhs)
  else (t, empty)

let singleton : 'e -> 'e t = fun v -> Single v

let%test_unit "list isomorphism - cons" =
  Quickcheck.test (Quickcheck.Generator.list Int.quickcheck_generator)
    ~f:(fun xs ->
      let xs_fseq = List.fold_right xs ~f:cons ~init:empty in
      [%test_eq: int list] xs (to_list xs_fseq) ;
      [%test_eq: int] (List.length xs) (length xs_fseq) )

let%test_unit "list isomorphism - snoc" =
  Quickcheck.test (Quickcheck.Generator.list Int.quickcheck_generator)
    ~f:(fun xs ->
      let xs_fseq = List.fold_left xs ~init:empty ~f:snoc in
      [%test_eq: int list] xs (to_list xs_fseq) ;
      [%test_eq: int] (List.length xs) (length xs_fseq) )

let%test_unit "alternating cons/snoc" =
  Quickcheck.test
    Quickcheck.Generator.(
      list @@ variant2 (Int.gen_incl 0 500) (Int.gen_incl 0 500))
    ~f:(fun cmds ->
      let rec go list fseq cmds_acc =
        match cmds_acc with
        | [] ->
            [%test_eq: int list] list (to_list fseq) ;
            [%test_eq: int] (List.length list) (length fseq)
        | `A x :: rest ->
            go (x :: list) (cons x fseq) rest
        | `B x :: rest ->
            go (list @ [x]) (snoc fseq x) rest
      in
      go [] empty cmds )

let%test_unit "split properties" =
  let gen =
    let open Quickcheck.Generator in
    let open Quickcheck.Generator.Let_syntax in
    let%bind xs = list (Int.gen_incl 0 500) in
    let%bind idx = Int.gen_incl 0 (max (List.length xs ) 0) in
    return (xs, idx)
  in
  let shrinker =
    Quickcheck.Shrinker.create (fun (xs, idx) ->
        Sequence.append
          ( if List.length xs - 1 > idx then
            Sequence.singleton (List.tl_exn xs, idx)
          else Sequence.empty )
          ( Sequence.range ~start:`inclusive ~stop:`inclusive 1 5
          |> Sequence.filter_map ~f:(fun offset ->
                 let res = idx - offset in
                 if res >= 0 then Some (xs, res) else None ) ) )
  in
  Quickcheck.test gen
    ~examples:[ ([0;1;2], 3) ]
    ~shrink_attempts:`Exhaustive
    ~sexp_of:[%sexp_of: int list * int] ~shrinker ~f:(fun (xs, idx) ->
      let len = List.length xs in
      let split_l_list = List.take xs idx in
      let split_r_list = List.drop xs idx in
      let xs_fseq = of_list xs in
      let split_l_fseq, split_r_fseq =
        split_at xs_fseq idx
      in
      let split_l_fseq', split_r_fseq' =
        (to_list split_l_fseq, to_list split_r_fseq)
      in
      [%test_eq: int] (List.length split_l_list + List.length split_r_list) len ;
      [%test_eq: int list] split_l_list split_l_fseq' ;
      [%test_eq: int list] split_r_list split_r_fseq' ;
      [%test_eq: int] (List.length split_l_fseq') (length split_l_fseq) ;
      [%test_eq: int] (List.length split_r_fseq') (length split_r_fseq) ;
      [%test_eq: int] (length split_l_fseq + length split_r_fseq) len )

let%test_module "split test" =
  (module (struct
    type elt = int
    [@@deriving sexp]

    let elt_gen = Int.quickcheck_generator

    module Op = struct
      type t = 
        | Cons of elt
        | Snoc of elt
        | Split of int
      [@@deriving sexp]

      let _t = Cons 3
      let _t = Snoc 3
      let _ = elt_gen

      let gen n =
        let open Quickcheck.Generator in 
        let open Let_syntax in
        let%map i = Int.gen_incl 0 (max 0 (n - 1)) in
        Split i
        (*
        match%map variant3 elt_gen elt_gen 
                    (Int.gen_incl 0 (max 0 (n - 1)))
        with
        | `A e -> Cons e
        | `B e -> Snoc e
        | `C i -> Split i *)

      let apply op t =
        match op with
        | Cons e -> [ cons e t ]
        | Snoc e -> [ snoc t e ]
        | Split i -> let a, b = split_at t i in [a; b]
    end

    let%test_unit "foo" =
      let _ = Op.gen in
      let _ = Op.apply in
      let ex =  Deep (75, Three (925,926,927), lazy (Deep (69, One (Three (3,928,929,930)), lazy (Deep (54, Three (Three (9,Three (3,931,932,933),Three (3,934,935,936),Three (3,937,938,939)),Three (9,Three (3,940,941,942),Three (3,943,944,945),Three (3,946,947,948)),Three (9,Three (3,949,950,951),Three (3,952,953,954),Three (3,955,956,957))), lazy (Empty), Three (Three (9,Three (3,958,959,960),Three (3,961,962,963),Three (3,964,965,966)),Three (9,Three (3,967,968,969),Three (3,970,971,972),Three (3,973,974,975)),Three (9,Three (3,976,977,978),Three (3,979,980,981),Three (3,982,983,984))))), Four (Three (3,985,986,987),Three (3,988,989,990),Three (3,991,992,993),Three (3,994,995,996)))), Three (997,998,999)) in
      let _ex : _ Node.t Node.t Untyped.t = 
        Deep
          (54, 
           Three
             (Three (9,Three (3,931,932,933),Three (3,934,935,936),Three (3,937,938,939)),
              Three (9,Three (3,940,941,942),Three (3,943,944,945),Three (3,946,947,948)),
              Three (9,Three (3,949,950,951),Three (3,952,953,954),Three (3,955,956,957))),
           (Empty),
           Three
             (Three (9,Three (3,958,959,960),Three (3,961,962,963),Three (3,964,965,966)),
              Three (9,Three (3,967,968,969),Three (3,970,971,972),Three (3,973,974,975)),
              Three (9,Three (3,976,977,978),Three (3,979,980,981),Three (3,982,983,984))))
      in
      check_lengths   
        ex
        (Fn.const 1) |> ignore;
      Core.printf "\n--------------------------\n%!";
      split_at ex 30 |> ignore

    (*
    let%test_unit "foo" =
      let ex = Untyped.Deep (75, Three (925,926,927),  (Deep (69, One (Three (3,928,929,930)),  (Deep (54, Three (Three (9,Three (3,931,932,933),Three (3,934,935,936),Three (3,937,938,939)),Three (9,Three (3,940,941,942),Three (3,943,944,945),Three (3,946,947,948)),Three (9,Three (3,949,950,951),Three (3,952,953,954),Three (3,955,956,957))),  (Empty), Three (Three (9,Three (3,958,959,960),Three (3,961,962,963),Three (3,964,965,966)),Three (9,Three (3,967,968,969),Three (3,970,971,972),Three (3,973,974,975)),Three (9,Three (3,976,977,978),Three (3,979,980,981),Three (3,982,983,984))))), Four (Three (3,985,986,987),Three (3,988,989,990),Three (3,991,992,993),Three (3,994,995,996)))), Three (997,998,999))
    let ex =
      Untyped.Deep 
        (75, Three (925,926,927),  (), Three (997,998,999))
    let _ =
      Deep (
        69,
        One (Three (3,928,929,930)),
        (Deep (54, Three (Three (9,Three (3,931,932,933),Three (3,934,935,936),Three (3,937,938,939)),Three (9,Three (3,940,941,942),Three (3,943,944,945),Three (3,946,947,948)),Three (9,Three (3,949,950,951),Three (3,952,953,954),Three (3,955,956,957))),  (Empty), Three (Three (9,Three (3,958,959,960),Three (3,961,962,963),Three (3,964,965,966)),Three (9,Three (3,967,968,969),Three (3,970,971,972),Three (3,973,974,975)),Three (9,Three (3,976,977,978),Three (3,979,980,981),Three (3,982,983,984))))),
        Four (Three (3,985,986,987),Three (3,988,989,990),Three (3,991,992,993),Three (3,994,995,996))
      )
    in
      let shrinker =
        Quickcheck.Shrinker.create (fun (t, i) ->
            match t with
            | Untyped.Empty -> (t, i)
            | Single _ -> (t, i)
            | Deep (_, l, m, r) ->
          )
      in
      shrinker *)

(*
   let%test_unit "gen_iter" =
      let open Quickcheck.Generator.Let_syntax in
      let rec go count universe =
        if count = 0
        then return ()
        else
          let n= List.length universe in
        let%bind i = Int.gen_incl 0 (n- 1) in
          Core.printf "univ %d\n%!" n;
        let t = List.nth_exn universe i in
        let%bind op = Op.gen (length t) in
        let universe =
          let new_ts =
            try
            Op.apply op t
            with _ ->
              Core.printf
              !"%s\n%!"
                (Untyped.to_string Int.to_string (untype t));
              failwithf !"bad op: %{sexp:Op.t} %{sexp:int list} %{sexp:int Untyped.t}"
                op (to_list t) (untype t) ()
          in
          List.iter new_ts ~f:(fun t -> check_lengths t (Fn.const 1) |> ignore);
          new_ts @ universe
        in
        let universe = 
          List.dedup_and_sort ~compare:(fun x y -> if equal Int.equal x y then 0 else 1)
            universe
        in
        go (count - 1) universe
      in
      Quickcheck.random_value
        (go 500 [ empty; of_list (List.range 0 1000) ])

*)
  end))
