open Core_kernel
open Common
open Backend
open Pickles_types
module Impl = Impls.Step
open Import

let high_entropy_bits = 128

let sponge_params_constant =
  Sponge.Params.(map tweedle_q ~f:Impl.Field.Constant.of_string)

let tick_field_random_oracle ?(length = Tick.Field.size_in_bits - 1) s =
  Tick.Field.of_bits (bits_random_oracle ~length s)

let unrelated_g =
  let group_map =
    unstage
      (group_map
         (module Tick.Field)
         ~a:Tick.Inner_curve.Params.a ~b:Tick.Inner_curve.Params.b)
  and str = Fn.compose bits_to_bytes Tick.Field.to_bits in
  fun (x, y) -> group_map (tick_field_random_oracle (str x ^ str y))

open Impl

module Other_field = struct
  type t = Tock.Field.t [@@deriving sexp]

  include (Tock.Field : module type of Tock.Field with type t := t)

  let size = Impls.Wrap.Bigint.to_bignum_bigint size
end

let sponge_params =
  Sponge.Params.(map sponge_params_constant ~f:Impl.Field.constant)

module Unsafe = struct
  let unpack_unboolean ?(length = Field.size_in_bits) x =
    let res =
      exists
        (Typ.list Boolean.typ_unchecked ~length)
        ~compute:
          As_prover.(
            fun () -> List.take (Field.Constant.unpack (read_var x)) length)
    in
    Field.Assert.equal x (Field.project res) ;
    res
end

module Sponge = struct
  module Permutation =
    Sponge_inputs.Make
      (Impl)
      (struct
        include Tick_field_sponge.Inputs

        let params = Tick_field_sponge.params
      end)

  module S = Sponge.Make_sponge (Permutation)
  include S

  let squeeze_field = squeeze

  let squeeze =
    Util.squeeze_with_packed (module Impl) ~squeeze ~high_entropy_bits

  let absorb t input =
    match input with
    | `Field x ->
        absorb t x
    | `Bits bs ->
        absorb t (Field.pack bs)
end

let%test_unit "sponge" =
  let module T = Make_sponge.Test (Impl) (Tick_field_sponge.Field) (Sponge.S)
  in
  T.test Tick_field_sponge.params

module Input_domain = struct
  let domain = Domain.Pow_2_roots_of_unity 6

  let lagrange_commitments =
    lazy
      (let domain_size = Domain.size domain in
       let u = Unsigned.Size_t.of_int in
       time "lagrange" (fun () ->
           Array.init domain_size ~f:(fun i ->
               let v =
                 Snarky_bn382.Tweedle.Dee.Field_urs.lagrange_commitment
                   (Backend.Tock.Keypair.load_urs ())
                   (u domain_size) (u i)
                 |> Snarky_bn382.Tweedle.Dee.Field_poly_comm.unshifted
               in
               assert (Tick.Inner_curve.Affine.Backend.Vector.length v = 1) ;
               Tick.Inner_curve.Affine.Backend.Vector.get v 0
               |> Tick.Inner_curve.Affine.of_backend |> Or_infinity.finite_exn
           ) ))
end

module Inner_curve = struct
  module Inputs = struct
    module Impl = Impl

    module Params = struct
      open Impl.Field.Constant
      include Tweedle.Dee.Params

      let one = Tweedle.Dee.to_affine_exn Tweedle.Dee.one

      let group_size_in_bits = Field.size_in_bits
    end

    module F = struct
      include struct
        open Impl.Field

        type nonrec t = t

        let ( * ), ( + ), ( - ), inv_exn, square, scale, if_, typ, constant =
          (( * ), ( + ), ( - ), inv, square, scale, if_, typ, constant)

        let negate x = scale x Constant.(negate one)
      end

      module Constant = struct
        open Impl.Field.Constant

        type nonrec t = t

        let ( * ), ( + ), ( - ), inv_exn, square, negate =
          (( * ), ( + ), ( - ), inv, square, negate)
      end

      let assert_square x y = Impl.assert_square x y

      let assert_r1cs x y z = Impl.assert_r1cs x y z
    end

    module Constant = struct
      include Tweedle.Dee.Affine
      module Scalar = Impls.Wrap.Field.Constant

      let scale (t : t) x : t =
        Tweedle.Dee.(to_affine_exn (scale (of_affine t) x))

      let random () = Tweedle.Dee.(to_affine_exn (random ()))

      let zero = Impl.Field.Constant.(zero, zero)

      let ( + ) t1 t2 =
        let is_zero (x, _) = Impl.Field.Constant.(equal zero x) in
        if is_zero t1 then t2
        else if is_zero t2 then t1
        else
          let r = Tweedle.Dee.(of_affine t1 + of_affine t2) in
          try Tweedle.Dee.to_affine_exn r with _ -> zero

      let negate x = Tweedle.Dee.(to_affine_exn (negate (of_affine x)))

      let to_affine_exn = Fn.id

      let of_affine = Fn.id
    end
  end

  module Params = Inputs.Params
  module Constant = Inputs.Constant
  module T = Snarky_curve.For_native_base_field (Inputs)

  include (
    T :
      module type of T
      with module Scaling_precomputation := T.Scaling_precomputation )

  module Scaling_precomputation = T.Scaling_precomputation

  let ( + ) = T.add_exn

  let scale t bs =
    with_label __LOC__ (fun () ->
        T.scale t (Bitstring_lib.Bitstring.Lsb_first.of_list bs) )

  let to_field_elements (x, y) = [x; y]

  let assert_equal (x1, y1) (x2, y2) =
    Field.Assert.equal x1 x2 ; Field.Assert.equal y1 y2

  let scale_inv t bs =
    let res =
      exists typ
        ~compute:
          As_prover.(
            fun () ->
              Tweedle.Dee.scale
                (Tweedle.Dee.of_affine (read typ t))
                (Tock.Field.inv
                   (Tock.Field.of_bits (List.map ~f:(read Boolean.typ) bs)))
              |> Tweedle.Dee.to_affine_exn)
    in
    assert_equal t (scale res bs) ;
    res

  let negate = T.negate

  let one = T.one

  let if_ = T.if_
end

module Ops = Plonk_curve_ops.Make (Impl) (Inner_curve)

module Generators = struct
  let h =
    lazy
      ( Snarky_bn382.Tweedle.Dee.Plonk.Field_urs.h
          (Backend.Tock.Keypair.load_urs ())
      |> Zexe_backend.Tweedle.Dee.Affine.of_backend |> Or_infinity.finite_exn
      )
end
