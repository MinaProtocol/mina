open Core

type ('a, 's) fold = init:'s -> f:('s -> 'a -> 's) -> 's

type 'a t = { fold : 's. ('a, 's) fold }

let to_list (t : 'a t) : 'a list =
  List.rev (t.fold ~init:[] ~f:(Fn.flip List.cons))

let of_list (xs : 'a list) : 'a t =
  { fold = fun ~init ~f -> List.fold xs ~init ~f }

let sexp_of_t f t = List.sexp_of_t f (to_list t)

let compose (t1 : 'a t) (t2 : 'a t) : 'a t =
  { fold = fun ~init ~f ->
      t2.fold ~init:(t1.fold ~init ~f) ~f
  }

let (+>) = compose

let group3 ~default (t : 'a t) : ('a * 'a * 'a) t =
  { fold =
    fun ~init ~f ->
      let (pt, bs) =
        t.fold ~init:(init, []) ~f:(fun (pt, bs) b ->
          match bs with 
          | [b2; b1; b0] ->
          let pt' = f pt (b0, b1, b2) in 
          (pt', [])
          | _ ->
            (pt, b :: bs))
      in 
      match bs with
      | [b2; b1; b0] -> f pt (b0, b1, b2)
      | [b1; b0] ->  f pt (b0, b1, default)
      | [b0] -> f pt (b0, default, default)
      | [] | _::_::_::_ -> pt
  }
;;
