(** A sequence type backed by [Core.Fdeque].

    The pool needs deque operations on a sender's queued transactions, plus the
    ability to drop everything after a given index when a transaction is
    replaced or revalidated away. [Fdeque] provides the ends; [split_at] is
    built from it and costs the index it is given, which is small in practice
    because every caller splits where a nonce scan just matched.

    Note the caveat [Fdeque] documents: its amortized bounds assume the deque
    is threaded sequentially through calls. Sender queues are used that way --
    each version derives from the previous one -- but a caller that repeatedly
    dequeued from the same retained version would see the worst case. *)
open Core

type 'e t = 'e Fdeque.t

(* Structural, over the elements in order: two deques holding the same sequence
   must compare equal whatever their internal split. *)
let compare cmp_e x y = List.compare cmp_e (Fdeque.to_list x) (Fdeque.to_list y)

let equal eq_e x y = List.equal eq_e (Fdeque.to_list x) (Fdeque.to_list y)

let sexp_of_t sexp_e t = List.sexp_of_t sexp_e (Fdeque.to_list t)

let is_empty = Fdeque.is_empty

let length = Fdeque.length

let head_exn = Fdeque.peek_front_exn

let last_exn = Fdeque.peek_back_exn

let uncons = Fdeque.dequeue_front

let unsnoc t =
  Fdeque.dequeue_back t |> Option.map ~f:(fun (last, rest) -> (rest, last))

let foldl f init t = Fdeque.fold t ~init ~f

let foldr f init t = List.fold_right (Fdeque.to_list t) ~init ~f

let findi t ~f =
  Fdeque.fold_until t ~init:0
    ~f:(fun i x -> if f x then Stop (Some i) else Continue (i + 1))
    ~finish:(fun _ -> None)

let iter t ~f = Fdeque.iter t ~f

let to_list = Fdeque.to_list

let to_seq t = Sequence.of_list (Fdeque.to_list t)

let empty = Fdeque.empty

let singleton = Fdeque.singleton

let cons e t = Fdeque.enqueue_front t e

let snoc t e = Fdeque.enqueue_back t e

let of_list = Fdeque.of_list

let split_at t i =
  let rec go i taken rest =
    if i <= 0 then (Fdeque.of_list (List.rev taken), rest)
    else
      match Fdeque.dequeue_front rest with
      | None ->
          (Fdeque.of_list (List.rev taken), rest)
      | Some (x, rest) ->
          go (i - 1) (x :: taken) rest
  in
  go i [] t

let find t ~f = Fdeque.find t ~f

let big_list : 'a Quickcheck.Generator.t -> 'a list Quickcheck.Generator.t =
 fun gen ->
  let open Quickcheck.Generator.Let_syntax in
  let%bind len = Int.gen_incl 0 1000 in
  Quickcheck.Generator.list_with_length len gen

let%test_unit "list isomorphism - cons" =
  Quickcheck.test (big_list Int.quickcheck_generator) ~f:(fun xs ->
      let xs_fseq = List.fold_right xs ~f:cons ~init:empty in
      [%test_eq: int list] xs (to_list xs_fseq) ;
      [%test_eq: int] (List.length xs) (length xs_fseq) )

let%test_unit "list isomorphism - snoc" =
  Quickcheck.test (big_list Int.quickcheck_generator) ~f:(fun xs ->
      let xs_fseq = List.fold_left xs ~init:empty ~f:snoc in
      [%test_eq: int list] xs (to_list xs_fseq) ;
      [%test_eq: int] (List.length xs) (length xs_fseq) )

let%test_unit "findi matches the list implementation" =
  Quickcheck.test
    Quickcheck.Generator.(
      tuple2 (big_list (Int.gen_incl 0 20)) (Int.gen_incl 0 20) )
    ~f:(fun (xs, target) ->
      let xs_fseq = List.fold_left xs ~init:empty ~f:snoc in
      (* Pins that the *first* match is returned, which is what the callers in
         indexed_pool rely on and what short-circuiting must not change. *)
      [%test_eq: int option]
        (List.findi xs ~f:(fun _ x -> x = target) |> Option.map ~f:fst)
        (findi xs_fseq ~f:(fun x -> x = target)) )

let%test_unit "alternating cons/snoc" =
  Quickcheck.test
    Quickcheck.Generator.(
      big_list @@ variant2 (Int.gen_incl 0 500) (Int.gen_incl 0 500) )
    ~f:(fun cmds ->
      let rec go list fseq cmds_acc =
        match cmds_acc with
        | [] ->
            [%test_eq: int list] list (to_list fseq) ;
            [%test_eq: int] (List.length list) (length fseq)
        | `A x :: rest ->
            go (x :: list) (cons x fseq) rest
        | `B x :: rest ->
            go (list @ [ x ]) (snoc fseq x) rest
      in
      go [] empty cmds )

let%test_unit "split properties" =
  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%bind xs = big_list (Int.gen_incl 0 500) in
    let%bind idx = Int.gen_incl 0 (List.length xs) in
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
  Quickcheck.test gen ~shrink_attempts:`Exhaustive
    ~sexp_of:[%sexp_of: int list * int] ~shrinker ~f:(fun (xs, idx) ->
      let len = List.length xs in
      let split_l_list = List.take xs idx in
      let split_r_list = List.drop xs idx in
      let xs_fseq = of_list xs in
      let split_l_fseq, split_r_fseq = split_at xs_fseq idx in
      let split_l_fseq', split_r_fseq' =
        (to_list split_l_fseq, to_list split_r_fseq)
      in
      [%test_eq: int] (List.length split_l_list + List.length split_r_list) len ;
      [%test_eq: int list] split_l_list split_l_fseq' ;
      [%test_eq: int list] split_r_list split_r_fseq' ;
      [%test_eq: int] (List.length split_l_fseq') (length split_l_fseq) ;
      [%test_eq: int] (List.length split_r_fseq') (length split_r_fseq) ;
      [%test_eq: int] (length split_l_fseq + length split_r_fseq) len )

(* Exercise all the functions that generate sequences, in random combinations. *)
let%test_module "random sequence generation, with splits" =
  ( module struct
    type action =
      [ `Cons of int
      | `Snoc of int
      | `Split_take_left of int
      | `Split_take_right of int ]
    [@@deriving sexp_of]

    let%test_unit _ =
      let rec gen_actions xs len n =
        let open Quickcheck.Generator in
        let open Quickcheck.Generator.Let_syntax in
        if n = 0 then return @@ List.rev xs
        else
          match%bind
            variant3 (Int.gen_incl 0 500) (Int.gen_incl 0 500)
              (Int.gen_uniform_incl 0 len)
          with
          | `A v ->
              gen_actions (`Cons v :: xs) (len + 1) (n - 1)
          | `B v ->
              gen_actions (`Snoc v :: xs) (len + 1) (n - 1)
          | `C idx -> (
              match%bind bool with
              | true ->
                  gen_actions (`Split_take_left idx :: xs) idx (n - 1)
              | false ->
                  gen_actions (`Split_take_right idx :: xs) (len - idx) (n - 1)
              )
      in
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%bind len = Int.gen_incl 0 50 in
        gen_actions [] 0 len
      in
      let shrinker =
        Quickcheck.Shrinker.create (function
          | [] ->
              Sequence.empty
          | _ :: _ as acts ->
              Sequence.of_list
                [ List.take acts (List.length acts / 2)
                ; List.take acts (List.length acts - 1)
                ; List.map acts ~f:(function `Snoc x -> `Cons x | x -> x)
                ; List.map acts ~f:(function `Cons x -> `Snoc x | x -> x)
                ] )
      in
      Quickcheck.test gen ~trials:100_000 ~shrinker
        ~sexp_of:(List.sexp_of_t sexp_of_action) ~f:(fun acts ->
          let rec go fseq = function
            | [] ->
                ()
            | `Cons x :: acts_rest ->
                go (cons x fseq) acts_rest
            | `Snoc x :: acts_rest ->
                go (snoc fseq x) acts_rest
            | `Split_take_left idx :: acts_rest ->
                go (Tuple2.get1 @@ split_at fseq idx) acts_rest
            | `Split_take_right idx :: acts_rest ->
                go (Tuple2.get2 @@ split_at fseq idx) acts_rest
          in
          go empty acts )
  end )
