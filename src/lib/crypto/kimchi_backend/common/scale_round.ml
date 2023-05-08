open Core_kernel

[%%versioned
module Stable = struct
  module V2 = struct
    type 'a t =
      { accs : ('a * 'a) array
      ; bits : 'a array
      ; ss : 'a array
      ; base : 'a * 'a
      ; n_prev : 'a
      ; n_next : 'a
      }
    [@@deriving sexp, fields, hlist]
  end
end]

let map { accs; bits; ss; base; n_prev; n_next } ~f =
  { accs = Array.map accs ~f:(fun (x, y) -> (f x, f y))
  ; bits = Array.map bits ~f
  ; ss = Array.map ss ~f
  ; base = (f (fst base), f (snd base))
  ; n_prev = f n_prev
  ; n_next = f n_next
  }

let map2 t1 t2 ~f =
  { accs =
      Array.map (Array.zip_exn t1.accs t2.accs) ~f:(fun ((x1, y1), (x2, y2)) ->
          (f x1 x2, f y1 y2) )
  ; bits =
      Array.map (Array.zip_exn t1.bits t2.bits) ~f:(fun (x1, x2) -> f x1 x2)
  ; ss = Array.map (Array.zip_exn t1.ss t2.ss) ~f:(fun (x1, x2) -> f x1 x2)
  ; base = (f (fst t1.base) (fst t2.base), f (snd t1.base) (snd t2.base))
  ; n_prev = f t1.n_prev t2.n_prev
  ; n_next = f t1.n_next t2.n_next
  }

let fold { accs; bits; ss; base; n_prev; n_next } ~f ~init =
  let t = Array.fold accs ~init ~f:(fun acc (x, y) -> f [ x; y ] acc) in
  let t = Array.fold bits ~init:t ~f:(fun acc x -> f [ x ] acc) in
  let t = Array.fold ss ~init:t ~f:(fun acc x -> f [ x ] acc) in
  let t = f [ fst base; snd base ] t in
  let t = f [ n_prev ] t in
  let t = f [ n_next ] t in
  t
