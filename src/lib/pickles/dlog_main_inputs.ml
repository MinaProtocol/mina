open Core_kernel
open Common

module type S = Intf.Dlog_main_inputs.S

open Zexe_backend
module Impl = Impls.Dlog_based
open Import

let fq_random_oracle ?length s = Fq.of_bits (bits_random_oracle ?length s)

let unrelated_g =
  let group_map = unstage (group_map (module Fq) ~a:G1.Params.a ~b:G1.Params.b)
  and str = Fn.compose bits_to_bytes Fq.to_bits in
  fun (x, y) -> group_map (fq_random_oracle (str x ^ str y))

module Input_domain = struct
  let lagrange_commitments domain =
    let domain_size = Domain.size domain in
    let u = Unsigned.Size_t.of_int in
    time "lagrange" (fun () ->
        Array.init domain_size ~f:(fun i ->
            Snarky_bn382.Fp_urs.lagrange_commitment
              (Zexe_backend.Pairing_based.Keypair.load_urs ())
              (u domain_size) (u i)
            |> Zexe_backend.G1.Affine.of_backend ) )

  let domain = Domain.Pow_2_roots_of_unity 6

  let self = Domain.Pow_2_roots_of_unity 5
end

open Impl

module G1 = struct
  module Inputs = struct
    module Impl = Impl

    module Params = struct
      include G1.Params

      let one = G1.to_affine_exn G1.one

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
      include G1.Affine
      module Scalar = Impls.Pairing_based.Field.Constant

      let scale (t : t) x : t = G1.(to_affine_exn (scale (of_affine t) x))

      let random () = G1.(to_affine_exn (random ()))

      let negate x = G1.(to_affine_exn (negate (of_affine x)))

      let zero = Impl.Field.Constant.(zero, zero)

      let ( + ) t1 t2 =
        let is_zero (x, _) = Impl.Field.Constant.(equal zero x) in
        if is_zero t1 then t2
        else if is_zero t2 then t1
        else
          let r = G1.(of_affine t1 + of_affine t2) in
          try G1.to_affine_exn r with _ -> zero

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

  let ( + ) = add_exn

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
              G1.(
                to_affine_exn
                  (scale
                     (of_affine (read typ t))
                     (Fp.inv (Fp.of_bits (List.map ~f:(read Boolean.typ) bs))))))
    in
    assert_equal t (scale res bs) ;
    res

  (* g -> 7 * g *)
  let scale_by_quadratic_nonresidue t =
    let t2 = T.double t in
    let t4 = T.double t2 in
    t + t2 + t4

  let one_seventh = Fp.(inv (of_int 7))

  let scale_by_quadratic_nonresidue_inv t =
    let res =
      exists typ
        ~compute:
          As_prover.(
            fun () ->
              G1.(to_affine_exn (scale (of_affine (read typ t)) one_seventh)))
    in
    assert_equal t (scale_by_quadratic_nonresidue res) ;
    res

  let if_ = T.if_
end

module Generators = struct
  let g = G1.Params.one
end

let sponge_params_constant =
  Sponge.Params.(map bn382_q ~f:Impl.Field.Constant.of_string)

module Fp = struct
  type t = Fp.t

  let order =
    Impl.Bigint.to_bignum_bigint Zexe_backend.Pairing_based.field_size

  let size_in_bits = Fp.size_in_bits

  let to_bigint = Fp.to_bigint

  let of_bigint = Fp.of_bigint
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
