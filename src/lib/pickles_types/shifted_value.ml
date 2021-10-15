open Core_kernel

(* Our custom constraints let us efficiently compute

   f = fun (g, t) -> (2 * t + 1 + 2^len(t)) g

   We want to compute

   f' = fun (g, s) -> s * g

   Let n be the field size in bits.

   For a scalar s, let t = (s - 2^n - 1)/2.
   t can be represented with an n bit string.

   Then

   f (g, t)
   = (2 t + 2^n + 1) * g
   = (2 (s - 2^n - 1)/2 + 2^n + 1) * g
   = (s - 2^n - 1 + 2^n + 1) * g
   = s * g
   = f' (g, s)

   as desired.
*)

[%%versioned
module Stable = struct
  module V1 = struct
    type 'f t = Shifted_value of 'f
    [@@deriving sexp, compare, equal, yojson, hash]
  end
end]

let typ f =
  let there (Shifted_value x) = x in
  let back x = Shifted_value x in
  Snarky_backendless.Typ.(transport_var (transport f ~there ~back) ~there ~back)

let map (Shifted_value x) ~f = Shifted_value (f x)

module type Field_intf = sig
  type t

  val size_in_bits : int

  val ( - ) : t -> t -> t

  val ( + ) : t -> t -> t

  val ( * ) : t -> t -> t

  val inv : t -> t

  val one : t

  val of_int : int -> t
end

module Shift : sig
  type 'f t = private { c : 'f; scale : 'f }

  val create : (module Field_intf with type t = 'f) -> 'f t

  val map : 'a t -> f:('a -> 'b) -> 'b t
end = struct
  type 'f t = { c : 'f; scale : 'f }

  let map t ~f = { c = f t.c; scale = f t.scale }

  (* 2^{field size in bits} + 1 *)
  let create (type f) (module F : Field_intf with type t = f) : f t =
    let rec two_to_the n =
      if n = 0 then F.one
      else
        let r = two_to_the (n - 1) in
        F.(r + r)
    in
    { c = F.(two_to_the size_in_bits + one); scale = F.(inv (of_int 2)) }
end

let of_field (type f) (module F : Field_intf with type t = f)
    ~(shift : f Shift.t) (s : f) : f t =
  Shifted_value F.((s - shift.c) * shift.scale)

let to_field (type f) (module F : Field_intf with type t = f)
    ~(shift : f Shift.t) (Shifted_value t : f t) : f =
  F.(t + t + shift.c)

let equal equal (Shifted_value t1) (Shifted_value t2) = equal t1 t2
