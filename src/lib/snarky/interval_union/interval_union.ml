open Core_kernel

module Interval = struct
  (* Semantically (a, b) : t is the closed interval [a, b] *)
  type t = int * int [@@deriving eq, sexp]

  let before (_, b1) (a2, _) = b1 <= a2

  let gen_from start =
    let open Quickcheck.Generator.Let_syntax in
    let%bind x = Int.gen_incl start Int.max_value_30_bits in
    let%map y = Int.gen_incl x Int.max_value_30_bits in
    (x, y)

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%bind x = Int.gen_incl Int.min_value Int.max_value_30_bits in
    let%map y = Int.gen_incl x Int.max_value_30_bits in
    (x, y)

  let%test_unit "gen is correct" =
    Quickcheck.test gen ~f:(fun (x, y) -> assert (x <= y))
end

(* Simplest possible implementation. Should be an increasing list of
   disjoint intervals. 
   Semantically is the set of ints corresponding to the union of these 
   ntervals. *)
type t = Interval.t list [@@deriving eq, sexp]

let empty : t = []

let union_intervals_exn (a1, b1) (a2, b2) =
  let ( = ) = Int.( = ) in
  if b1 = a2 then `Combine (a1, b2)
  else if b2 = a1 then `Combine (a2, b1)
  else if b1 < a2 then `Disjoint_ordered
  else if b2 < a1 then `Disjoint_inverted
  else failwithf "Intervals not disjoint: (%d, %d) and (%d, %d)" a1 b1 a2 b2 ()

let of_interval i = [i]

let rec canonicalize = function
  | [] -> []
  | [i1] -> [i1]
  | (a1, a2) :: (a3, a4) :: t ->
      if a2 = a3 then canonicalize ((a1, a4) :: t)
      else (a1, a2) :: canonicalize ((a3, a4) :: t)

let rec disjoint_union_exn t1 t2 =
  match (t1, t2) with
  | t, [] | [], t -> t
  | i1 :: t1', i2 :: t2' -> (
    match union_intervals_exn i1 i2 with
    | `Combine (a, b) -> (a, b) :: disjoint_union_exn t1' t2'
    | `Disjoint_ordered -> i1 :: disjoint_union_exn t1' t2
    | `Disjoint_inverted -> i2 :: disjoint_union_exn t1 t2' )

let disjoint_union_exn t1 t2 = canonicalize (disjoint_union_exn t1 t2)

let rec disjoint t1 t2 =
  match (t1, t2) with
  | _, [] | [], _ -> true
  | i1 :: t1', i2 :: t2' ->
      if Interval.before i1 i2 then disjoint t1' t2
      else if Interval.before i2 i1 then disjoint t1 t2'
      else false

(* Someday: inefficient *)
let of_intervals_exn is =
  match is with
  | [] -> []
  | i :: is ->
      List.fold is ~init:(of_interval i) ~f:(fun acc x ->
          disjoint_union_exn (of_interval x) acc )

let to_interval = function
  | [i] -> Ok i
  | ([] | _ :: _ :: _) as xs ->
      Or_error.error_string
        (Printf.sprintf
           !"Interval_union.to_interval: was not an interval %{sexp: \
             Interval.t list}\n"
           xs)

let invariant t =
  let rec go = function
    | [(a, b)] -> assert (a <= b)
    | [] -> ()
    | (a1, b1) :: ((a2, _) :: _ as t) ->
        assert (a1 <= b1) ;
        assert (b1 < a2) ;
        go t
  in
  go t

let gen_from ?(min_size = 0) start =
  let open Quickcheck.Generator.Let_syntax in
  let rec go acc size start =
    if size = 0 then return (of_intervals_exn (List.rev acc))
    else
      let%bind ((_, y) as i) = Interval.gen_from start in
      go (i :: acc) (size - 1) y
  in
  let%bind size = Quickcheck.Generator.small_positive_int in
  go [] (min_size + size) start

let gen = gen_from Int.min_value

let%test_unit "check invariant" = Quickcheck.test gen ~f:invariant

let gen_disjoint_pair =
  let open Quickcheck.Generator.Let_syntax in
  let%bind t1 = gen in
  let y = List.last_exn t1 |> snd in
  let%map t2 = gen_from y in
  (t1, t2)

let%test_unit "canonicalize" = assert (canonicalize [(1, 2); (2, 3)] = [(1, 3)])

let%test_unit "disjoint union doesn't care about order" =
  Quickcheck.test gen_disjoint_pair ~f:(fun (a, b) ->
      assert (disjoint_union_exn a b = disjoint_union_exn b a) )

let%test_unit "check invariant on disjoint union" =
  Quickcheck.test gen_disjoint_pair ~f:(fun (a, b) ->
      invariant (disjoint_union_exn a b) )

let%test_unit "disjoint_union works with holes" =
  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let s = 1000000 in
    let%bind y0 = Int.gen_incl 0 s in
    let%bind y1 = Int.gen_incl (y0 + 1) (y0 + s) in
    let%bind y2 = Int.gen_incl (y1 + 1) (y1 + s) in
    let%bind y3 = Int.gen_incl (y2 + 1) (y2 + s) in
    return (of_interval (y1, y2), of_intervals_exn [(y0, y1); (y2, y3)])
  in
  Quickcheck.test gen ~f:(fun (x, y) -> invariant (disjoint_union_exn x y))
