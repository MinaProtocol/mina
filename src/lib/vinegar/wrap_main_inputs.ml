open Core_kernel
open Backend
module Me = Tock
module Other = Tick
module Impl = Impls.Wrap

let _high_entropy_bits = 128

let sponge_params_constant = Kimchi_pasta_basic.poseidon_params_fq

let field_random_oracle ?(length = Me.Field.size_in_bits - 1) s =
  Me.Field.of_bits (Ro.bits_random_oracle ~length s)

let _unrelated_g =
  let open Common in
  let group_map =
    unstage
      (group_map
         (module Me.Field)
         ~a:Me.Inner_curve.Params.a ~b:Me.Inner_curve.Params.b )
  and str = Fn.compose bits_to_bytes Me.Field.to_bits in
  fun (x, y) -> group_map (field_random_oracle (str x ^ str y))

open Impl

(* Debug helper to convert wrap circuit field element to a hex string *)
let read_wrap_circuit_field_element_as_hex fe =
  let prover_fe = As_prover.read Field.typ fe in
  Kimchi_backend.Pasta.Pallas_based_plonk.(
    Bigint.to_hex (Field.to_bigint prover_fe))

module Other_field = struct
  type t = Impls.Step.Field.Constant.t [@@deriving sexp]

  include (Tick.Field : module type of Tick.Field with type t := t)

  let size = Impls.Step.Bigint.to_bignum_bigint size
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
        include Tock_field_sponge.Inputs

        let params = Tock_field_sponge.params
      end)

  module S = Sponge.Make_debug_sponge (struct
    include Permutation
    module Circuit = Impls.Wrap

    (* Optional sponge name used in debug mode *)
    let sponge_name = "wrap"

    (* To enable debug mode, set environment variable [sponge_name] to "t", "1" or "true". *)
    let debug_helper_fn = read_wrap_circuit_field_element_as_hex
  end)

  include S

  let squeeze_field = squeeze

  let squeeze = squeeze
end

let%test_unit "sponge" =
  let module T = Make_sponge.Test (Impl) (Tock_field_sponge.Field) (Sponge.S) in
  T.test Tock_field_sponge.params

(* module Input_domain = struct
     let _lagrange_commitments domain : Backend.Tock.Inner_curve.Affine.t array =
       let domain_size = Import.Domain.size domain in
       Common.time "lagrange" (fun () ->
           Array.init domain_size ~f:(fun i ->
               (Kimchi_bindings.Protocol.SRS.Fp.lagrange_commitment
                  (Backend.Tick.Keypair.load_urs ())
                  domain_size i )
                 .unshifted.(0)
               |> Common.finite_exn ) )

     let _domain = Import.Domain.Pow_2_roots_of_unity 7
   end *)

module Inner_curve = struct
  module C = Kimchi_pasta.Pasta.Vesta

  module Inputs = struct
    module Impl = Impl

    module Params = struct
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

  let ( + ) t1 t2 = Plonk_curve_ops.add_fast (module Impl) t1 t2

  let double t = t + t

  let scale t bs =
    with_label __LOC__ (fun () ->
        T.scale t (Bitstring_lib.Bitstring.Lsb_first.of_list bs) )

  let to_field_elements (x, y) = [ x; y ]

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
                   (Other.Field.of_bits (List.map ~f:(read Boolean.typ) bs)) )
              |> C.to_affine_exn)
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
      ( Kimchi_bindings.Protocol.SRS.Fp.urs_h (Backend.Tick.Keypair.load_urs ())
      |> Common.finite_exn )
end
