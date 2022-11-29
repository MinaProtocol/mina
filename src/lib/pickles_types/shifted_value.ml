open Core_kernel

module type Field_intf = sig
  type t

  val size_in_bits : int

  val negate : t -> t

  val ( - ) : t -> t -> t

  val ( + ) : t -> t -> t

  val ( * ) : t -> t -> t

  val ( / ) : t -> t -> t

  val inv : t -> t

  val one : t

  val of_int : int -> t
end

let two_to_the (type f) (module F : Field_intf with type t = f) =
  let rec two_to_the n =
    if n = 0 then F.one
    else
      let r = two_to_the (n - 1) in
      F.(r + r)
  in
  two_to_the

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

module type S = sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type 'f t [@@deriving sexp, compare, equal, yojson, hash]
    end
  end]

  val typ :
       ('a, 'b, 'f) Snarky_backendless.Typ.t
    -> ('a t, 'b t, 'f) Snarky_backendless.Typ.t

  val map : 'a t -> f:('a -> 'b) -> 'b t

  module Shift : sig
    type _ t

    val create : (module Field_intf with type t = 'f) -> 'f t

    val map : 'a t -> f:('a -> 'b) -> 'b t
  end

  val of_field :
    (module Field_intf with type t = 'f) -> shift:'f Shift.t -> 'f -> 'f t

  val to_field :
    (module Field_intf with type t = 'f) -> shift:'f Shift.t -> 'f t -> 'f

  val equal : ('f, 'res) Sigs.rel2 -> ('f t, 'res) Sigs.rel2
end

[@@@warning "-4"]

module Type1 = struct
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
    Snarky_backendless.Typ.(
      transport_var (transport f ~there ~back) ~there ~back)

  let map (Shifted_value x) ~f = Shifted_value (f x)

  module Shift : sig
    type 'f t = private { c : 'f; scale : 'f }

    val create : (module Field_intf with type t = 'f) -> 'f t

    val map : 'a t -> f:('a -> 'b) -> 'b t
  end = struct
    type 'f t = { c : 'f; scale : 'f }

    let map t ~f = { c = f t.c; scale = f t.scale }

    (* 2^{field size in bits} + 1 *)
    let create (type f) (module F : Field_intf with type t = f) : f t =
      { c = F.(two_to_the (module F) size_in_bits + one)
      ; scale = F.(inv (of_int 2))
      }
  end

  let of_field (type f) (module F : Field_intf with type t = f)
      ~(shift : f Shift.t) (s : f) : f t =
    Shifted_value F.((s - shift.c) * shift.scale)

  let to_field (type f) (module F : Field_intf with type t = f)
      ~(shift : f Shift.t) (Shifted_value t : f t) : f =
    F.(t + t + shift.c)

  let equal equal (Shifted_value t1) (Shifted_value t2) = equal t1 t2
end

(* When the scalar field is larger than the inner field of the circuit,
   we need to encode a scalar [s] as a pair ((s >> 1), s & 1). In other
   words, the high bits, and then the low bit separately.

   We can then efficiently compute the function

   f = fun (g, s) -> (2 * (s >> 1) + (s & 1) + 2^(5 * ceil(len(s >> 1) / 5))) g
     = fun (g, s) -> (s + 2^field_size_in_bits) g

   This is a different notion of shifted value, so we have a separate type for it.
*)

module Type2 = struct
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
    Snarky_backendless.Typ.(
      transport_var (transport f ~there ~back) ~there ~back)

  let map (Shifted_value x) ~f = Shifted_value (f x)

  module Shift : sig
    type 'f t = private 'f

    val create : (module Field_intf with type t = 'f) -> 'f t

    val map : 'a t -> f:('a -> 'b) -> 'b t
  end = struct
    type 'f t = 'f

    let map t ~f = f t

    (* 2^{field size in bits} *)
    let create (type f) (module F : Field_intf with type t = f) : f t =
      two_to_the (module F) F.size_in_bits
  end

  let of_field (type f) (module F : Field_intf with type t = f)
      ~(shift : f Shift.t) (s : f) : f t =
    Shifted_value F.(s - (shift :> t))

  let to_field (type f) (module F : Field_intf with type t = f)
      ~(shift : f Shift.t) (Shifted_value t : f t) : f =
    F.(t + (shift :> t))

  let equal equal (Shifted_value t1) (Shifted_value t2) = equal t1 t2
end
