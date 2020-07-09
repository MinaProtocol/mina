open Core_kernel
open Common
open Backend
module Me = Tock
module Other = Tick
module Impl = Impls.Wrap
open Import

let sponge_params_constant =
  Sponge.Params.(map tweedle_p ~f:Impl.Field.Constant.of_string)

let field_random_oracle ?length s =
  Me.Field.of_bits (bits_random_oracle ?length s)

let unrelated_g =
  let group_map =
    unstage
      (group_map
         (module Me.Field)
         ~a:Me.Inner_curve.Params.a ~b:Me.Inner_curve.Params.b)
  and str = Fn.compose bits_to_bytes Me.Field.to_bits in
  fun (x, y) -> group_map (field_random_oracle (str x ^ str y))

open Impl

module Other_field = struct
  type t = Impls.Step.Field.Constant.t [@@deriving sexp]

  include (Tick.Field : module type of Tick.Field with type t := t)

  let size = Impls.Step.Bigint.to_bignum_bigint size
end

let sponge_params =
  Sponge.Params.(map sponge_params_constant ~f:Impl.Field.constant)

module Sponge = struct
  module S = Sponge.Make_sponge (Sponge.Poseidon (Sponge_inputs.Make (Impl)))

  include Sponge.Bit_sponge.Make (struct
              type t = Impl.Boolean.var
            end)
            (struct
              include Impl.Field

              let to_bits t =
                Bitstring_lib.Bitstring.Lsb_first.to_list
                  (Impl.Field.unpack_full t)
            end)
            (Impl.Field)
            (S)
end

module Input_domain = struct
  let domain = Domain.Pow_2_roots_of_unity 7

  let lagrange_commitments domain : Me.Inner_curve.Affine.t array =
    let domain_size = Domain.size domain in
    let u = Unsigned.Size_t.of_int in
    time "lagrange" (fun () ->
        Array.init domain_size ~f:(fun i ->
            Snarky_bn382.Tweedle.Dum.Field_urs.lagrange_commitment
              (Tick.Keypair.load_urs ()) (u domain_size) (u i)
            |> Snarky_bn382.Tweedle.Dum.Field_poly_comm.unshifted
            |> Fn.flip Me.Inner_curve.Affine.Backend.Vector.get 0
            |> Me.Inner_curve.Affine.of_backend ) )
end

module Inner_curve = struct
  module C = Tweedle.Dum

  module Inputs = struct
    module Impl = Impl

    module Params = struct
      open Impl.Field.Constant
      include C.Params

      let one = C.to_affine_exn C.one

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
      include C.Affine
      module Scalar = Impls.Step.Field.Constant

      let scale (t : t) (x : Scalar.t) : t =
        C.(to_affine_exn (scale (of_affine t) x))

      let random () : t = C.(to_affine_exn (random ()))

      let zero = Impl.Field.Constant.(zero, zero)

      let ( + ) t1 t2 : t =
        let is_zero (x, _) = Impl.Field.Constant.(equal zero x) in
        if is_zero t1 then t2
        else if is_zero t2 then t1
        else
          let r = C.(of_affine t1 + of_affine t2) in
          try C.to_affine_exn r with _ -> zero

      let negate x : t = C.(to_affine_exn (negate (of_affine x)))

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

  let scale t bs = T.scale t (Bitstring_lib.Bitstring.Lsb_first.of_list bs)

  let to_field_elements (x, y) = [x; y]

  let assert_equal (x1, y1) (x2, y2) =
    Field.Assert.equal x1 x2 ; Field.Assert.equal y1 y2

  let scale_inv t bs =
    let res =
      exists typ
        ~compute:
          As_prover.(
            fun () ->
              C.scale
                (C.of_affine (read typ t))
                (Other.Field.inv
                   (Other.Field.of_bits (List.map ~f:(read Boolean.typ) bs)))
              |> C.to_affine_exn)
    in
    assert_equal t (scale res bs) ;
    res

  (* g -> 5 * g *)
  let scale_by_quadratic_nonresidue t =
    let t2 = T.double t in
    let t4 = T.double t2 in
    t + t4

  let quadratic_nonresidue_inv = Other.Field.(inv (of_int 5))

  let scale_by_quadratic_nonresidue_inv t =
    let res =
      exists typ
        ~compute:
          As_prover.(
            fun () ->
              C.to_affine_exn
                (C.scale (C.of_affine (read typ t)) quadratic_nonresidue_inv))
    in
    ignore (scale_by_quadratic_nonresidue res) ;
    res

  let negate = T.negate

  let one = T.one

  let if_ = T.if_
end

module Generators = struct
  let h =
    lazy
      ( Snarky_bn382.Tweedle.Dum.Field_urs.h
          (Zexe_backend.Tweedle.Dum_based.Keypair.load_urs ())
      |> Zexe_backend.Tweedle.Dum.Affine.of_backend )
end
