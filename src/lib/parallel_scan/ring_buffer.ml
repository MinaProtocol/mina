open Core_kernel
open Async_kernel

type 'a t = {data: 'a Array.t; mutable position: int} [@@deriving sexp, bin_io]

let filter_map t = Array.filter_map t.data

let mod_ x y =
  let r = x mod y in
  if r >= 0 then r else y + r

let create ~len ~default = {data= Array.create ~len default; position= 0}

let length b = Array.length b.data

let copy {data; position} = {data= Array.copy data; position}

let direct_update t i ~f =
  let open Or_error.Let_syntax in
  let x : 'a = t.data.(i) in
  let%bind v = f x in
  return @@ (t.data.(i) <- v)

let update t ~f = direct_update t t.position ~f:(fun x -> f t.position x)

(*Read element from the ith positon*)
let read_i t i = t.data.(i)

let next_i t i = mod_ (i + 1) (Array.length t.data)

let swap t i j =
  let temp = read_i t i in
  t.data.(i) <- t.data.(j) ;
  t.data.(j) <- temp

let iter t ~f =
  let n = Array.length t.data in
  for i = 0 to n - 1 do
    f t.data.((t.position + i) mod n)
  done

let read t = t.data.(t.position)

let filter t ~f =
  let curr_position_neg_one = mod_ (t.position - 1) (Array.length t.data) in
  Sequence.unfold ~init:(`More t.position) ~f:(fun pos ->
      match pos with
      | `Stop -> None
      | `More pos ->
          if pos = curr_position_neg_one then
            if not (f pos) then Some (None, `Stop)
            else Some (Some t.data.(pos), `Stop)
          else if not (f pos) then
            Some (None, `More (mod_ (pos + 1) (Array.length t.data)))
          else
            Some
              (Some t.data.(pos), `More (mod_ (pos + 1) (Array.length t.data)))
  )
  |> Sequence.to_list |> List.filter_map ~f:ident

let read_all t =
  let curr_position_neg_one = mod_ (t.position - 1) (Array.length t.data) in
  Sequence.unfold ~init:(`More t.position) ~f:(fun pos ->
      match pos with
      | `Stop -> None
      | `More pos ->
          if pos = curr_position_neg_one then Some (t.data.(pos), `Stop)
          else Some (t.data.(pos), `More (mod_ (pos + 1) (Array.length t.data)))
  )
  |> Sequence.to_list

(*read k elements from the current position*)
let read_k t k = List.take (read_all t) k

let forwards ~n t = t.position <- mod_ (t.position + n) (Array.length t.data)

let read_then_forwards t =
  let x = read t in
  forwards ~n:1 t ; x

let back ~n t = t.position <- mod_ (t.position - n) (Array.length t.data)

let add t a =
  t.position <- mod_ (t.position + 1) (Array.length t.data) ;
  t.data.(t.position) <- a

let add_many t xs = List.fold xs ~init:() ~f:(fun () x -> add t x)

let gen gen_elem =
  let open Quickcheck.Generator.Let_syntax in
  let%bind len = Quickcheck.Generator.small_positive_int in
  let%map elems = Quickcheck.Generator.list_with_length len gen_elem in
  {data= Array.of_list elems; position= 0}

let%test_unit "buffer wraps around" =
  let b = create ~len:3 ~default:0 in
  back ~n:1 b ;
  assert (b.data = [|0; 0; 0|]) ;
  add b 1 ;
  add b 2 ;
  add b 3 ;
  assert (b.data = [|1; 2; 3|]) ;
  add b 4 ;
  assert (b.data = [|4; 2; 3|])

let%test_unit "b = let s = read_all b; back1;add_many s;forwards1" =
  Quickcheck.test ~sexp_of:[%sexp_of: int t] (gen Int.gen) ~f:(fun b ->
      let old = copy b in
      let stuff = read_all b in
      back ~n:1 b ;
      add_many b stuff ;
      forwards ~n:1 b ;
      assert (old.data = b.data && old.position = b.position) )
