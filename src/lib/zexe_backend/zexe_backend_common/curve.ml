open Intf
open Core_kernel

module type Input_intf = sig
  module BaseField : sig
    type t
  end

  module ScalarField : sig
    type t
  end

  module Affine : sig
    type t

    val x : t -> BaseField.t

    val y : t -> BaseField.t

    val is_zero : t -> bool

    val create : BaseField.t -> BaseField.t -> t

    val delete : t -> unit

    module Vector : sig
      include Snarky_intf.Vector.S with type elt = t

      val typ : t Ctypes.typ

      val delete : t -> unit
    end

    module Pair : Intf.Pair with type elt := t
  end

  type t

  val delete : t -> unit

  val to_affine_exn : t -> Affine.t

  val of_affine_coordinates : BaseField.t -> BaseField.t -> t

  val add : t -> t -> t

  val double : t -> t

  val scale : t -> ScalarField.t -> t

  val sub : t -> t -> t

  val negate : t -> t

  val random : unit -> t

  val one : unit -> t
end

module type Field_intf = sig
  module Stable : sig
    module Latest : sig
      type t [@@deriving bin_io, eq, sexp, compare, yojson, hash]
    end
  end

  include Type_with_delete with type t = Stable.Latest.t

  val ( + ) : t -> t -> t

  val ( * ) : t -> t -> t

  val one : t

  val square : t -> t

  val is_square : t -> bool

  val sqrt : t -> t
end

module Make
    (BaseField : Field_intf) (ScalarField : sig
        type t
    end) (Params : sig
      val a : BaseField.t

      val b : BaseField.t
    end)
    (C : Input_intf
         with module BaseField := BaseField
          and module ScalarField := ScalarField) =
struct
  module Affine = struct
    module Backend = C.Affine

    module Stable = struct
      module V1 = struct
        type t = BaseField.Stable.Latest.t * BaseField.Stable.Latest.t
        [@@deriving
          version {asserted}, eq, bin_io, sexp, compare, yojson, hash]
      end

      module Latest = V1
    end

    include Stable.Latest

    let to_backend (x, y) =
      let t = C.Affine.create x y in
      Caml.Gc.finalise C.Affine.delete t ;
      t

    let of_backend t =
      let x = C.Affine.x t in
      Caml.Gc.finalise BaseField.delete x ;
      let y = C.Affine.y t in
      Caml.Gc.finalise BaseField.delete y ;
      (x, y)
  end

  let op1 f x =
    let r = f x in
    Caml.Gc.finalise C.delete r ;
    r

  let op2 f x y =
    let r = f x y in
    Caml.Gc.finalise C.delete r ;
    r

  let to_affine_exn t =
    let r = C.to_affine_exn t in
    if C.Affine.is_zero r then (
      C.Affine.delete r ;
      failwith "to_affine_exn: Got identity" )
    else
      let r' = Affine.of_backend r in
      C.Affine.delete r ; r'

  let of_affine (x, y) = op2 C.of_affine_coordinates x y

  type t = C.t

  include Binable.Of_binable
            (Affine)
            (struct
              type nonrec t = t

              let to_binable = to_affine_exn

              let of_binable = of_affine
            end)

  open C

  let add = op2 add

  let scale = op2 scale

  let sub = op2 sub

  let double = op1 double

  let negate = op1 negate

  let random = op1 random

  let one = one ()

  let zero = sub one one

  let ( + ) = add

  let ( * ) s t = scale t s

  let find_y x =
    let open BaseField in
    let y2 = (x * square x) + (Params.a * x) + Params.b in
    if is_square y2 then Some (sqrt y2) else None

  let point_near_x (x : BaseField.t) =
    let rec go x = function
      | Some y ->
          of_affine (x, y)
      | None ->
          let x' = BaseField.(one + x) in
          go x' (find_y x')
    in
    go x (find_y x)
end
