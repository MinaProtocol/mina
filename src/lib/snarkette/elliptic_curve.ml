open Core_kernel

let ( = ) = `Don't_use_polymorphic_compare

module type Fq_intf = sig
  type t

  val is_square : t -> bool

  val sqrt : t -> t

  val square : t -> t

  val ( + ) : t -> t -> t

  val ( * ) : t -> t -> t
end

let find_y (type t) (module Fq : Fq_intf with type t = t) ~a ~b x =
  let open Fq in
  let y2 = (x * square x) + (a * x) + b in
  if Fq.is_square y2 then Some (Fq.sqrt y2) else None

let decompress ~find_y ~parity ~negate (x, is_odd) =
  Option.map (find_y x) ~f:(fun y ->
      let y_parity = parity y in
      let y = if Bool.(is_odd = y_parity) then y else negate y in
      (x, y) )

module Make (N : sig
  type t

  val test_bit : t -> int -> bool

  val num_bits : t -> int
end) (Fq : sig
  include Fq_intf

  include Fields.Intf with type t := t

  val parity : t -> bool
end) (Coefficients : sig
  val a : Fq.t

  val b : Fq.t
end) =
struct
  type t = {x: Fq.t; y: Fq.t; z: Fq.t} [@@deriving bin_io, sexp]

  let zero = {x= Fq.zero; y= Fq.one; z= Fq.zero}

  module Coefficients = Coefficients

  module Affine = struct
    type t = Fq.t * Fq.t
  end

  let of_affine (x, y) = {x; y; z= Fq.one}

  let is_zero t = Fq.(equal zero t.x) && Fq.(equal zero t.z)

  let to_affine_exn {x; y; z} =
    let z_inv = Fq.inv z in
    Fq.(x * z_inv, y * z_inv)

  let to_affine t = if is_zero t then None else Some (to_affine_exn t)

  let find_y = find_y (module Fq) ~a:Coefficients.a ~b:Coefficients.b

  let decompress x =
    let open Fq in
    decompress ~find_y ~parity ~negate x |> Option.map ~f:of_affine

  let is_well_formed ({x; y; z} as t) =
    if is_zero t then true
    else
      let open Fq in
      let x2 = square x in
      let y2 = square y in
      let z2 = square z in
      equal
        (z * (y2 - (Coefficients.b * z2)))
        (x * (x2 + (Coefficients.a * z2)))

  let ( + ) t1 t2 =
    if is_zero t1 then t2
    else if is_zero t2 then t1
    else
      let open Fq in
      let x1z2 = t1.x * t2.z in
      let x2z1 = t1.z * t2.x in
      let y1z2 = t1.y * t2.z in
      let y2z1 = t1.z * t2.y in
      if equal x1z2 x2z1 && equal y1z2 y2z1 then
        (* Double case *)
        let xx = square t1.x in
        let zz = square t1.z in
        let w = (Coefficients.a * zz) + (xx + xx + xx) in
        let y1z1 = t1.y * t1.z in
        let s = y1z1 + y1z1 in
        let ss = square s in
        let sss = s * ss in
        let r = t1.y * s in
        let rr = square r in
        let b = square (t1.x + r) - xx - rr in
        let h = square w - (b + b) in
        let x3 = h * s in
        let y3 = (w * (b - h)) - (rr + rr) in
        let z3 = sss in
        {x= x3; y= y3; z= z3}
      else
        (* Generic case *)
        let z1z2 = t1.z * t2.z in
        let u = y2z1 - y1z2 in
        let uu = square u in
        let v = x2z1 - x1z2 in
        let vv = square v in
        let vvv = v * vv in
        let r = vv * x1z2 in
        let a = (uu * z1z2) - (vvv + r + r) in
        let x3 = v * a in
        let y3 = (u * (r - a)) - (vvv * y1z2) in
        let z3 = vvv * z1z2 in
        {x= x3; y= y3; z= z3}

  let scale base s =
    let rec go found_one acc i =
      if i < 0 then acc
      else
        let acc = if found_one then acc + acc else acc in
        if N.test_bit s i then go true (acc + base) (i - 1)
        else go found_one acc (i - 1)
    in
    go false zero (N.num_bits s - 1)

  let ( * ) s g = scale g s

  let negate {x; y; z} = {x; y= Fq.negate y; z}

  let ( - ) t1 t2 = t1 + negate t2
end
