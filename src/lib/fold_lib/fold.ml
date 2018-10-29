open Core_kernel

type ('a, 's) fold = init:'s -> f:('s -> 'a -> 's) -> 's

type 'a t = {fold: 's. ('a, 's) fold}

let map (t : 'a t) ~(f : 'a -> 'b) : 'b t =
  { fold=
      (fun ~init ~f:update -> t.fold ~init ~f:(fun acc x -> update acc (f x)))
  }

let concat (t : 'a t t) : 'a t =
  { fold=
      (fun ~init ~f ->
        t.fold ~init ~f:(fun acc inner -> inner.fold ~init:acc ~f) ) }

let concat_map (t : 'a t) ~(f : 'a -> 'b t) : 'b t =
  { fold=
      (fun ~init ~f:update ->
        t.fold ~init ~f:(fun acc x -> (f x).fold ~init:acc ~f:update) ) }

include Monad.Make (struct
  type nonrec 'a t = 'a t

  let map = `Custom map

  let return x = {fold= (fun ~init ~f -> f init x)}

  let bind = concat_map
end)

let to_list (t : 'a t) : 'a list =
  List.rev (t.fold ~init:[] ~f:(Fn.flip List.cons))

let of_list (xs : 'a list) : 'a t =
  {fold= (fun ~init ~f -> List.fold xs ~init ~f)}

let%test_unit "fold-to-list" =
  Quickcheck.test (Quickcheck.Generator.list Int.gen) ~f:(fun xs ->
      assert (xs = to_list (of_list xs)) )

let sexp_of_t f t = List.sexp_of_t f (to_list t)

let compose (t1 : 'a t) (t2 : 'a t) : 'a t =
  {fold= (fun ~init ~f -> t2.fold ~init:(t1.fold ~init ~f) ~f)}

let ( +> ) = compose

let group3 ~default (t : 'a t) : ('a * 'a * 'a) t =
  { fold=
      (fun ~init ~f ->
        let pt, bs =
          t.fold ~init:(init, []) ~f:(fun (pt, bs) b ->
              match bs with
              | [b2; b1; b0] ->
                  let pt' = f pt (b0, b1, b2) in
                  (pt', [b])
              | _ -> (pt, b :: bs) )
        in
        match bs with
        | [b2; b1; b0] -> f pt (b0, b1, b2)
        | [b1; b0] -> f pt (b0, b1, default)
        | [b0] -> f pt (b0, default, default)
        | [] -> pt
        | _x1 :: _x2 :: _x3 :: _x4 :: _ -> assert false ) }

let%test_unit "group3" =
  Quickcheck.test (Quickcheck.Generator.list Int.gen) ~f:(fun xs ->
      let default = 0 in
      let n = List.length xs in
      let tuples = to_list (group3 ~default (of_list xs)) in
      let k = List.length tuples in
      let r = n mod 3 in
      (let padded =
         xs @ if r = 0 then [] else List.init (3 - r) ~f:(fun _ -> default)
       in
       let concated =
         List.concat_map ~f:(fun (b1, b2, b3) -> [b1; b2; b3]) tuples
       in
       [%test_eq: int list] padded concated) ;
      assert ((n + 2) / 3 = k) )

let string_bits s =
  let ith_bit_int n i = (n lsr i) land 1 = 1 in
  { fold=
      (fun ~init ~f ->
        String.fold s ~init ~f:(fun acc c ->
            let c = Char.to_int c in
            let update i acc = f acc (ith_bit_int c i) in
            update 0 acc |> update 1 |> update 2 |> update 3 |> update 4
            |> update 5 |> update 6 |> update 7 ) ) }

let bool_t_to_string =
  let module State = struct
    type t = {curr: int; acc: char list; i: int}
  end in
  let open State in
  fun t ->
    let {curr; i; acc} =
      t.fold ~init:{curr= 0; acc= []; i= 0} ~f:(fun {curr; acc; i} b ->
          let curr = if b then curr lor (1 lsl i) else curr in
          if i = 7 then {i= 0; acc= Char.of_int_exn curr :: acc; curr= 0}
          else {i= i + 1; acc; curr} )
    in
    let cs = if i = 0 then acc else Char.of_int_exn curr :: acc in
    String.of_char_list cs

let string_triples s = group3 ~default:false (string_bits s)
