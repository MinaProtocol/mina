open Core_kernel

[%%versioned
module Stable = struct
  module V2 = struct
    type 'a t =
      { n0 : 'a
      ; n8 : 'a
      ; a0 : 'a
      ; b0 : 'a
      ; a8 : 'a
      ; b8 : 'a
      ; x0 : 'a
      ; x1 : 'a
      ; x2 : 'a
      ; x3 : 'a
      ; x4 : 'a
      ; x5 : 'a
      ; x6 : 'a
      ; x7 : 'a
      }
    [@@deriving sexp, fields, hlist]
  end
end]

let map { n0; n8; a0; b0; a8; b8; x0; x1; x2; x3; x4; x5; x6; x7 } ~f =
  { n0 = f n0
  ; n8 = f n8
  ; a0 = f a0
  ; b0 = f b0
  ; a8 = f a8
  ; b8 = f b8
  ; x0 = f x0
  ; x1 = f x1
  ; x2 = f x2
  ; x3 = f x3
  ; x4 = f x4
  ; x5 = f x5
  ; x6 = f x6
  ; x7 = f x7
  }

let map2 t1 t2 ~f =
  { n0 = f t1.n0 t2.n0
  ; n8 = f t1.n8 t2.n8
  ; a0 = f t1.a0 t2.a0
  ; b0 = f t1.b0 t2.b0
  ; a8 = f t1.a8 t2.a8
  ; b8 = f t1.b8 t2.b8
  ; x0 = f t1.x0 t2.x0
  ; x1 = f t1.x1 t2.x1
  ; x2 = f t1.x2 t2.x2
  ; x3 = f t1.x3 t2.x3
  ; x4 = f t1.x4 t2.x4
  ; x5 = f t1.x5 t2.x5
  ; x6 = f t1.x6 t2.x6
  ; x7 = f t1.x7 t2.x7
  }
