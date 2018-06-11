open Core_kernel
open Graphics

let pi = 4. *. Float.atan 1.
;;

let f2i = Vect.f2i
;;

let i2f = Vect.i2f
;;

let pause () = ignore In_channel.(input_line_exn stdin)
;;

let spiral () =
  for i = 12 downto 1 do
    let radius = i * 20 in
    set_color (if i mod 2 = 0 then red else yellow);
    fill_circle 320 240 radius
  done
;;

let iterate_tree r x_init n =
  let f x = r *. x *. (1. -. x) in
  (* Computes f (f ... (f x_init)) *)
  let rec go acc i =
    if i <= 1
    then acc
    else go (f acc) (i - 1)
  in
  go x_init n
;;

let tree () =
  for x = 0 to 639 do
    let r = 4. *. Float.of_int x /. 640. in
    for i = 0 to 39 do
      let x_init = Random.float 1. in
      let x_final = iterate_tree r x_init 500 in
      let y = Int.of_float (x_final *. 480.) in
      Graphics.plot x y
    done
  done
;;

let benin w h =
  let module Vect = Vect.Make (struct let w = w let h = h end) in
  let divl = 0.3 in
  set_color green;
  Vect.fill_rect 0.0 0.0 divl 1.0;
  set_color yellow;
  Vect.fill_rect divl 0.5 (1. -. divl) 0.5;
  set_color red;
  Vect.fill_rect divl 0.0 (1. -. divl) 0.5;
;;

let interleave xs ys =
  let rec go acc xs ys =
    match xs, ys with
    | [], [] -> acc
    | [], ys ->  go acc ys []
    | x::xs, ys -> go (x :: acc) ys xs
  in
  go [] xs ys
;;

let eu w h =
  let f2i x = Int.of_float x in
  let i2f x = Float.of_int x in
  let module Vect = Vect.Make (struct let w = w let h = h end) in
  let points = 5 in
  let fill_star x y outer_r inner_r =
    let offset = pi /. 2. in
    let get_angles offset =
      List.map (List.range 0 points) ~f:(fun p ->
        i2f p /. i2f points *. 2. *. pi -. (pi /. i2f points) +. offset)
    in
    let inner_angles = get_angles offset in
    let outer_angles = get_angles ((pi /. i2f points) +. offset) in
    let get_xy angles r =
      List.map angles ~f:(fun angle -> 
        i2f r *. Float.cos angle, i2f r *. Float.sin angle)
    in
    let inner_xy = get_xy inner_angles inner_r in
    let outer_xy = get_xy outer_angles outer_r in
    let points = interleave inner_xy outer_xy in
    let points = 
      List.map points ~f:(fun (sx, sy) ->
        (f2i (sx +. (i2f x)), f2i (sy +. (i2f y)))) 
    in
    fill_poly (Array.of_list points)
  in
  let fill_star_float x y outer_r inner_r = 
    fill_star (f2i x) (f2i y) (f2i outer_r) (f2i inner_r) 
  in
  let stars = 12 in
  set_color blue;
  Vect.fill_rect 0.0 0.0 1.0 1.0;
  set_color yellow;
  for x = 0 to stars do
    let angle = i2f x /. i2f stars *. 2. *. pi in
    let x = 0.5 *. Float.cos angle in
    let y = 0.5 *. Float.sin angle in
    let circle_r = h *. 0.75 in
    let star_outer_r = h *. 0.06 in
    let star_inner_r = star_outer_r /. i2f points *. 2. in
    fill_star_float 
      (0.5 *. w +. x *. circle_r) (0.5 *. h +. y *. circle_r) star_outer_r star_inner_r
  done
;;

let reset () =
  Random.self_init ();
  Graphics.open_graph "640x480";
  set_color black
;;

let init () =
  set_window_title "floatme";
  open_graph " 640x480";
  reset ()
;;

let () =
  init ();

  benin 640. 480.;
  pause ();

  eu 640. 480.;
  pause ();

  reset ();
  spiral ();
  pause ();

  reset ();
  tree ();
  pause ();
;;
