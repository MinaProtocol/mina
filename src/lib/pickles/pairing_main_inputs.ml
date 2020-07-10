open Core_kernel
open Common
open Zexe_backend
module Impl = Impls.Pairing_based
open Import

let high_entropy_bits = 256

let sponge_params_constant =
  Sponge.Params.(map bn382_p ~f:Impl.Field.Constant.of_string)

let fp_random_oracle ?(length = high_entropy_bits) s =
  Fp.of_bits (bits_random_oracle ~length s)

let unrelated_g =
  let group_map = unstage (group_map (module Fp) ~a:G.Params.a ~b:G.Params.b)
  and str = Fn.compose bits_to_bytes Fp.to_bits in
  fun (x, y) -> group_map (fp_random_oracle (str x ^ str y))

let crs_max_degree = 1 lsl 22

open Impl

module Fq = struct
  type t = Impls.Dlog_based.Field.Constant.t [@@deriving sexp]

  open Zexe_backend.Fq

  let of_bits = of_bits

  let to_bits = to_bits

  let is_square = is_square

  let inv = inv

  let print = print

  let of_int = of_int
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

              let high_entropy_bits = high_entropy_bits
            end)
            (Impl.Field)
            (S)

  let absorb t input =
    match input with
    | `Field x ->
        absorb t x
    | `Bits bs ->
        absorb t (Field.pack bs)
end

module Input_domain = struct
  let self = Domain.Pow_2_roots_of_unity 6

  let domain = Domain.Pow_2_roots_of_unity 5

  let lagrange_commitments =
    lazy
      (let domain_size = Domain.size domain in
       let u = Unsigned.Size_t.of_int in
       time "lagrange" (fun () ->
           Array.init domain_size ~f:(fun i ->
               let v =
                 Snarky_bn382.Fq_urs.lagrange_commitment
                   (Zexe_backend.Dlog_based.Keypair.load_urs ())
                   (u domain_size) (u i)
                 |> Snarky_bn382.Fq_poly_comm.unshifted
               in
               assert (G.Affine.Vector.length v = 1) ;
               G.Affine.Vector.get v 0 |> Zexe_backend.G.Affine.of_backend ) ))
end

module G = struct
  module Inputs = struct
    module Impl = Impl

    module Params = struct
      open Impl.Field.Constant
      include G.Params

      let one = G.to_affine_exn G.one

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
      include G.Affine
      module Scalar = Impls.Dlog_based.Field.Constant

      let scale (t : t) x : t = G.(to_affine_exn (scale (of_affine t) x))

      let random () = G.(to_affine_exn (random ()))

      let zero = Impl.Field.Constant.(zero, zero)

      let ( + ) t1 t2 =
        let is_zero (x, _) = Impl.Field.Constant.(equal zero x) in
        if is_zero t1 then t2
        else if is_zero t2 then t1
        else
          let r = G.(of_affine t1 + of_affine t2) in
          try G.to_affine_exn r with _ -> zero

      let negate x = G.(to_affine_exn (negate (of_affine x)))

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
              G.scale
                (G.of_affine (read typ t))
                (Fq.inv (Fq.of_bits (List.map ~f:(read Boolean.typ) bs)))
              |> G.to_affine_exn)
    in
    assert_equal t (scale res bs) ;
    res

  (* g -> 7 * g *)
  let scale_by_quadratic_nonresidue t =
    let t2 = T.double t in
    let t4 = T.double t2 in
    t + t2 + t4

  let one_seventh = Fq.(inv (of_int 7))

  let scale_by_quadratic_nonresidue_inv t =
    let res =
      exists typ
        ~compute:
          As_prover.(
            fun () ->
              G.to_affine_exn (G.scale (G.of_affine (read typ t)) one_seventh))
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
      ( Snarky_bn382.Fq_urs.h (Zexe_backend.Dlog_based.Keypair.load_urs ())
      |> Zexe_backend.G.Affine.of_backend )
end
