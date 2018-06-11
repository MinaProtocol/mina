open Core_kernel
open Graphics

let f2i x = Int.of_float x
;;

let i2f x = Float.of_int x
;;

module Make (M : sig val w : float val h : float end) = struct 
  open M

  let vec_w r = f2i (w *. r)
  let vec_h r = f2i (h *. r)

  let fill_rect x y w h =
    fill_rect (vec_w x) (vec_h y) (vec_w w) (vec_h h)
end

