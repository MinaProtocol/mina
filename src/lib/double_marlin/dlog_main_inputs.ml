open Core_kernel
open Common

module type S = Intf.Dlog_main_inputs.S

open Snarky_bn382_backend
module Impl = Impls.Dlog_based

let crs_max_degree = (1 lsl 20)

let fq_random_oracle ?length s = Fq.of_bits (bits_random_oracle ?length s)

let group_map = unstage (group_map (module Fq) ~a:Fq.zero ~b:(Fq.of_int 14))

let unrelated_g (x, y) =
  let str = Fn.compose bits_to_bytes Fq.to_bits in
  group_map (fq_random_oracle (str x ^ str y))

module Input_domain = struct
  let domain = Domain.Pow_2_roots_of_unity 6

  let self = Domain.Pow_2_roots_of_unity 5

  let lagrange_commitments =
    let x = 64 in
    let u = Unsigned.Size_t.of_int in
    time "lagrange" (fun () ->
        Array.init (Domain.size domain) ~f:(fun i ->
            Snarky_bn382_backend.G1.Affine.of_backend
              (Snarky_bn382.Fp_urs.lagrange_commitment
                 (Lazy.force Snarky_bn382_backend.Pairing_based.Keypair.urs)
                 (u x) (u i)) ) )
end

let group_map_fq =
  let params =
    Group_map.Params.create (module Fq) ~a:Fq.zero ~b:(Fq.of_int 14)
  in
  fun x -> Group_map.to_group (module Fq) ~params x

open Impl

module G1 = struct
  module Inputs = struct
    module Impl = Impl

    module Params = struct
      open Impl.Field.Constant

      let a = zero

      let b = of_int 14

      let one = G1.to_affine_exn G1.one

      let group_size_in_bits = 382
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

      let random () = G1.(to_affine_exn (random ()))

      let ( + ) x y = G1.(to_affine_exn (of_affine x + of_affine y))

      let negate x = G1.(to_affine_exn (negate (of_affine x)))

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

  module Scaling_precomputation = struct
    include T.Scaling_precomputation

    let create t = create ~unrelated_base:(unrelated_g t) t
  end

  let ( + ) = add_exn

  (* TODO: Make real *)
  let scale t bs =
    let res =
      exists typ
        ~compute:
          As_prover.(
            fun () ->
              G1.scale
                (G1.of_affine (read typ t))
                (Snarky_bn382_backend.Fp.of_bits
                   (List.map bs ~f:(read Boolean.typ)))
              |> G1.to_affine_exn)
    in
    let x, y = t in
    let constraints_per_bit =
      if Option.is_some (Field.to_constant x) then 2 else 6
    in
    let x = exists Field.typ ~compute:(fun () -> As_prover.read_var x)
    and x2 =
      exists Field.typ ~compute:(fun () ->
          Field.Constant.square (As_prover.read_var x) )
    in
    ksprintf Impl.with_label "scale %s" __LOC__ (fun () ->
        (* Dummy constraints *)
        let num_bits = List.length bs in
        for _ = 1 to constraints_per_bit * num_bits do
          assert_r1cs x x x2
        done ;
        res )

  (*         T.scale t (Bitstring_lib.Bitstring.Lsb_first.of_list bs) *)
  let to_field_elements (x, y) = [x; y]

  let assert_equal (x1, y1) (x2, y2) =
    Field.Assert.equal x1 x2 ; Field.Assert.equal y1 y2

  let scale_inv t bs =
    let res =
      exists typ
        ~compute:
          As_prover.(
            fun () ->
              G1.scale
                (G1.of_affine (read typ t))
                (Fp.inv (Fp.of_bits (List.map ~f:(read Boolean.typ) bs)))
              |> G1.to_affine_exn)
    in
    ignore (scale res bs) ;
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
    ignore (scale_by_quadratic_nonresidue res) ;
    res

  let if_ = T.if_
end

module Generators = struct
  let g = G1.one
end

let sponge_params_constant =
  Sponge.Params.(map bn382_q ~f:Impl.Field.Constant.of_string)

module Fp = struct
  type t = Fp.t

  let order =
    Impl.Bigint.to_bignum_bigint Snarky_bn382_backend.Pairing_based.field_size

  let size_in_bits = Fp.size_in_bits

  let to_bigint = Fp.to_bigint

  let of_bigint = Fp.of_bigint
end

let domain_k = Domain.Pow_2_roots_of_unity 18

let domain_h = Domain.Pow_2_roots_of_unity 17

let sponge_params =
  Sponge.Params.(map sponge_params_constant ~f:Impl.Field.constant)

module Sponge = struct
  module S = Sponge.Make_sponge (Sponge.Poseidon (Sponge_inputs.Make (Impl)))

  include Sponge.Make_bit_sponge (struct
              type t = Impl.Boolean.var
            end)
            (struct
              include Impl.Field

              let to_bits t =
                Bitstring_lib.Bitstring.Lsb_first.to_list
                  (Impl.Field.unpack_full t)
            end)
            (S)
end
