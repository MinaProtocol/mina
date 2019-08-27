open Core
module Tick = Snark_params.Tick
module Tock = Snark_params.Tock
module LTock = Lite_curve_choice.Tock

let field : Tick.Field.t -> LTock.Fq.t =
  Fn.compose LTock.Fq.of_string Tick.Field.to_string

let digest = field

let twist_field x : LTock.Fq3.t =
  let module V = Snark_params.Tick_backend.Field.Vector in
  let x = Snark_params.Tock_backend.Full.Fqe.to_vector x in
  let c i = field (V.get x i) in
  (c 0, c 1, c 2)

let target_field (x : Snark_params.Tock_backend.Full.Fqk.t) : LTock.Fq6.t =
  let x = Snark_params.Tock_backend.Full.Fqk.to_elts x in
  let module V = Snark_params.Tick_backend.Field.Vector in
  let c i = field (V.get x i) in
  ((c 0, c 1, c 2), (c 3, c 4, c 5))

let g1 (t : Tick.Inner_curve.t) : LTock.G1.t =
  let x, y = Tick.Inner_curve.to_affine_exn t in
  {x= field x; y= field y; z= LTock.Fq.one}

let g2 (t : Crypto_params.Cycle.Mnt6.G2.t) : LTock.G2.t =
  let x, y = Crypto_params.Tick_backend.Inner_twisted_curve.to_affine_exn t in
  {x= twist_field x; y= twist_field y; z= LTock.Fq3.one}

let g1_vector v =
  let module V = Snark_params.Tick.Inner_curve.Vector in
  Array.init (V.length v) ~f:(fun i -> g1 (V.get v i))
