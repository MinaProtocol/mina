module Impl = Impls.Step

let high_entropy_bits = 128

let sponge_params_constant =
  Sponge.Params.(map pasta_p_kimchi ~f:Impl.Field.Constant.of_string)

let tick_field_random_oracle ?(length = Backend.Tick.Field.size_in_bits - 1) s =
  Backend.Tick.Field.of_bits (Ro.bits_random_oracle ~length s)

let unrelated_g =
  let group_map =
    unstage
      (Common.group_map
         (module Backend.Tick.Field)
         ~a:Backend.Tick.Inner_curve.Params.a
         ~b:Backend.Tick.Inner_curve.Params.b )
  and str = Fn.compose Common.bits_to_bytes Backend.Tick.Field.to_bits in
  fun (x, y) -> group_map (tick_field_random_oracle (str x ^ str y))

let sponge_params =
  Sponge.Params.(map sponge_params_constant ~f:Impl.Field.constant)

module Other_field = struct
  type t = Backend.Tock.Field.t [@@deriving sexp]

  include (
    Backend.Tock.Field : module type of Backend.Tock.Field with type t := t )

  let size = Impls.Wrap.Bigint.to_bignum_bigint size
end

(* module Unsafe = struct
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
   end *)

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

  let absorb t input =
    match input with
    | `Field x ->
        absorb t x
    | `Bits bs ->
        absorb t (Impl.Field.pack bs)
end

let%test_unit "sponge" =
  let module T = Make_sponge.Test (Impl) (Tick_field_sponge.Field) (Sponge.S) in
  T.test Tick_field_sponge.params

module Input_domain = struct
  let domain = Import.Domain.Pow_2_roots_of_unity 6

  let lagrange_commitments =
    lazy
      (let domain_size = Import.Domain.size domain in
       Common.time "lagrange" (fun () ->
           Array.init domain_size ~f:(fun i ->
               let v =
                 (Kimchi_bindings.Protocol.SRS.Fq.lagrange_commitment
                    (Backend.Tock.Keypair.load_urs ())
                    domain_size i )
                   .unshifted
               in
               assert (Array.length v = 1) ;
               v.(0) |> Common.finite_exn ) ) )
end

module Inner_curve = struct
  module C = Kimchi_pasta.Pasta.Pallas

  module Inputs = struct
    module Impl = Impls.Step.Impl

    module Params = struct
      include C.Params

      let one = C.to_affine_exn C.one

      let group_size_in_bits = Impl.Field.size_in_bits
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
      module Scalar = Impls.Wrap.Field.Constant

      let scale (t : t) x : t = C.(to_affine_exn (scale (of_affine t) x))

      let random () = C.(to_affine_exn (random ()))

      let zero = Impl.Field.Constant.(zero, zero)

      let ( + ) t1 t2 =
        let is_zero (x, _) = Impl.Field.Constant.(equal zero x) in
        if is_zero t1 then t2
        else if is_zero t2 then t1
        else
          let r = C.(of_affine t1 + of_affine t2) in
          try C.to_affine_exn r with _ -> zero

      let negate x = C.(to_affine_exn (negate (of_affine x)))

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
    Impl.with_label __LOC__ (fun () ->
        T.scale t (Bitstring_lib.Bitstring.Lsb_first.of_list bs) )

  let to_field_elements (x, y) = [ x; y ]

  let assert_equal (x1, y1) (x2, y2) =
    let open Impl.Field.Assert in
    equal x1 x2 ; equal y1 y2

  let scale_inv t bs =
    let res =
      Impl.(
        exists typ
          ~compute:
            As_prover.(
              fun () ->
                C.scale
                  (C.of_affine (read typ t))
                  (Backend.Tock.Field.inv
                     (Backend.Tock.Field.of_bits
                        (List.map ~f:(read Boolean.typ) bs) ) )
                |> C.to_affine_exn))
    in
    assert_equal t (scale res bs) ;
    res

  let negate = T.negate

  let one = T.one

  let if_ = T.if_
end

module Ops = Plonk_curve_ops.Make (Impl) (Inner_curve)

let%test_unit "scale fast 2'" =
  let open Impl in
  let module T = Internal_Basic in
  let module G = Inner_curve in
  let n = Field.size_in_bits in
  let module F = struct
    type t = Field.t

    let typ = Field.typ

    module Constant = struct
      include Field.Constant

      let to_bigint = Impl.Bigint.of_field
    end
  end in
  Quickcheck.test ~trials:5 Field.Constant.gen ~f:(fun s ->
      T.Test.test_equal ~equal:G.Constant.equal ~sexp_of_t:G.Constant.sexp_of_t
        (Typ.tuple2 G.typ Field.typ)
        G.typ
        (fun (g, s) ->
          make_checked (fun () -> Ops.scale_fast2' ~num_bits:n (module F) g s)
          )
        (fun (g, _) ->
          let x =
            let chunks_needed = Ops.chunks_needed ~num_bits:(n - 1) in
            let actual_bits_used = chunks_needed * Ops.bits_per_chunk in
            Pickles_types.Pcs_batch.pow ~one:G.Constant.Scalar.one
              ~mul:G.Constant.Scalar.( * )
              G.Constant.Scalar.(of_int 2)
              actual_bits_used
            |> G.Constant.Scalar.( + )
                 (G.Constant.Scalar.project (Field.Constant.unpack s))
          in
          G.Constant.scale g x )
        (G.Constant.random (), s) )

let%test_unit "scale fast 2 small" =
  let open Impl in
  let module T = Internal_Basic in
  let module G = Inner_curve in
  let n = 8 in
  let module F = struct
    type t = Field.t

    let typ = Field.typ

    module Constant = struct
      include Field.Constant

      let to_bigint = Impl.Bigint.of_field
    end
  end in
  Quickcheck.test ~trials:5 Field.Constant.gen ~f:(fun s ->
      let s =
        Field.Constant.unpack s |> Fn.flip List.take n |> Field.Constant.project
      in
      T.Test.test_equal ~equal:G.Constant.equal ~sexp_of_t:G.Constant.sexp_of_t
        (Typ.tuple2 G.typ Field.typ)
        G.typ
        (fun (g, s) ->
          make_checked (fun () -> Ops.scale_fast2' ~num_bits:n (module F) g s)
          )
        (fun (g, _) ->
          let x =
            let chunks_needed = Ops.chunks_needed ~num_bits:(n - 1) in
            let actual_bits_used = chunks_needed * Ops.bits_per_chunk in
            Pickles_types.Pcs_batch.pow ~one:G.Constant.Scalar.one
              ~mul:G.Constant.Scalar.( * )
              G.Constant.Scalar.(of_int 2)
              actual_bits_used
            |> G.Constant.Scalar.( + )
                 (G.Constant.Scalar.project (Field.Constant.unpack s))
          in
          G.Constant.scale g x )
        (G.Constant.random (), s) )

module Generators = struct
  let h =
    lazy
      ( Kimchi_bindings.Protocol.SRS.Fq.urs_h (Backend.Tock.Keypair.load_urs ())
      |> Common.finite_exn )
end
