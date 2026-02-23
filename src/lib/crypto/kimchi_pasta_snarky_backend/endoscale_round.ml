open Core_kernel
module H_list = Snarky_backendless.H_list

[%%versioned
module Stable = struct
  module V2 = struct
    type 'a t =
      { xt : 'a
      ; yt : 'a
      ; xp : 'a
      ; yp : 'a
      ; n_acc : 'a
      ; xr : 'a
      ; yr : 'a
      ; s1 : 'a
      ; s3 : 'a
      ; b1 : 'a
      ; b2 : 'a
      ; b3 : 'a
      ; b4 : 'a
      }
    [@@deriving sexp, fields, hlist]
  end
end]

let map { xt; yt; xp; yp; n_acc; xr; yr; s1; s3; b1; b2; b3; b4 } ~f =
  { xt = f xt
  ; yt = f yt
  ; xp = f xp
  ; yp = f yp
  ; n_acc = f n_acc
  ; xr = f xr
  ; yr = f yr
  ; s1 = f s1
  ; s3 = f s3
  ; b1 = f b1
  ; b2 = f b2
  ; b3 = f b3
  ; b4 = f b4
  }

let map2 t1 t2 ~f =
  { xt = f t1.xt t2.xt
  ; yt = f t1.yt t2.yt
  ; xp = f t1.xp t2.xp
  ; yp = f t1.yp t2.yp
  ; n_acc = f t1.n_acc t2.n_acc
  ; xr = f t1.xr t2.xr
  ; yr = f t1.yr t2.yr
  ; s1 = f t1.s1 t2.s1
  ; s3 = f t1.s3 t2.s3
  ; b1 = f t1.b1 t2.b1
  ; b2 = f t1.b2 t2.b2
  ; b3 = f t1.b3 t2.b3
  ; b4 = f t1.b4 t2.b4
  }
