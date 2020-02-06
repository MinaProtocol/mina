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

    val create : BaseField.t -> BaseField.t -> t

    val delete : t -> unit
  end

  type t

  val delete : t -> unit

  val to_affine_exn : t -> Affine.t

  val of_affine_coordinates : BaseField.t -> BaseField.t -> t

  val add : t -> t -> t

  val scale : t -> ScalarField.t -> t

  val sub : t -> t -> t

  val negate : t -> t

  val random : unit -> t

  val one : unit -> t
end

module type Field_intf = sig
  include Type_with_delete

  include Binable.S with type t := t
end

module Make
    (BaseField : Field_intf)
    (ScalarField : Field_intf)
    (C : Input_intf
         with module BaseField := BaseField
          and module ScalarField := ScalarField) =
struct
  module Affine = struct
    type t = BaseField.t * BaseField.t [@@deriving bin_io]

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

  let negate = op1 negate

  let random = op1 random

  let one = one ()

  let ( + ) = add

  let ( * ) s t = scale t s
end
