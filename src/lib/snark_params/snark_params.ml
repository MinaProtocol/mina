open Core_kernel
open Bitstring_lib
open Snark_bits

module Make_snarkable (Impl : Snarky_backendless.Snark_intf.S) = struct
  open Impl

  module type S = sig
    type var

    type value

    val typ : (var, value) Typ.t
  end

  module Bits = struct
    module type Lossy =
      Bits_intf.Snarkable.Lossy
        with type ('a, 'b) typ := ('a, 'b) Typ.t
         and type ('a, 'b) checked := ('a, 'b) Checked.t
         and type boolean_var := Boolean.var

    module type Faithful =
      Bits_intf.Snarkable.Faithful
        with type ('a, 'b) typ := ('a, 'b) Typ.t
         and type ('a, 'b) checked := ('a, 'b) Checked.t
         and type boolean_var := Boolean.var

    module type Small =
      Bits_intf.Snarkable.Small
        with type ('a, 'b) typ := ('a, 'b) Typ.t
         and type ('a, 'b) checked := ('a, 'b) Checked.t
         and type boolean_var := Boolean.var
         and type comparison_result := Field.Checked.comparison_result
         and type field_var := Field.Var.t
  end
end

module Tock0 = struct
  include Crypto_params.Tock
  module Snarkable = Make_snarkable (Crypto_params.Tock)
end

module Tick0 = struct
  include Crypto_params.Tick
  module Snarkable = Make_snarkable (Crypto_params.Tick)
end

let%test_unit "group-map test" =
  let params = Crypto_params.Tock.group_map_params () in
  let module M = Crypto_params.Tick.Run in
  Quickcheck.test ~trials:3 Tick0.Field.gen ~f:(fun t ->
      let (), checked_output =
        M.run_and_check
          (fun () ->
            let x, y =
              Snarky_group_map.Checked.to_group
                (module M)
                ~params (M.Field.constant t)
            in
            fun () -> M.As_prover.(read_var x, read_var y))
          ()
        |> Or_error.ok_exn
      in
      let ((x, y) as actual) =
        Group_map.to_group (module Tick0.Field) ~params t
      in
      [%test_eq: Tick0.Field.t]
        Tick0.Field.(
          (x * x * x)
          + (Tick0.Inner_curve.Params.a * x)
          + Tick0.Inner_curve.Params.b)
        Tick0.Field.(y * y) ;
      [%test_eq: Tick0.Field.t * Tick0.Field.t] checked_output actual)

module Make_inner_curve_scalar (Impl : Snark_intf.S) (Other_impl : Snark_intf.S) =
struct
  module T = Other_impl.Field

  include (
    T :
      module type of T with module Var := T.Var and module Checked := T.Checked )

  let of_bits = Other_impl.Field.project

  let length_in_bits = size_in_bits

  open Impl

  type var = Boolean.var Bitstring.Lsb_first.t

  let typ : (var, t) Typ.t =
    Typ.transport_var
      (Typ.transport
         (Typ.list ~length:size_in_bits Boolean.typ)
         ~there:unpack ~back:project)
      ~there:Bitstring.Lsb_first.to_list ~back:Bitstring.Lsb_first.of_list

  let gen : t Quickcheck.Generator.t =
    Quickcheck.Generator.map
      (Bignum_bigint.gen_incl Bignum_bigint.one
         Bignum_bigint.(Other_impl.Field.size - one))
      ~f:(fun x -> Other_impl.Bigint.(to_field (of_bignum_bigint x)))

  let test_bit x i = Other_impl.Bigint.(test_bit (of_field x) i)

  module Checked = struct
    let equal a b =
      Bitstring_checked.equal
        (Bitstring.Lsb_first.to_list a)
        (Bitstring.Lsb_first.to_list b)

    let to_bits = Fn.id

    module Assert = struct
      let equal : var -> var -> (unit, _) Checked.t =
       fun a b ->
        Bitstring_checked.Assert.equal
          (Bitstring.Lsb_first.to_list a)
          (Bitstring.Lsb_first.to_list b)
    end
  end
end

module Make_inner_curve_aux (Impl : Snark_intf.S) (Other_impl : Snark_intf.S) =
struct
  open Impl

  type var = Field.Var.t * Field.Var.t

  module Scalar = Make_inner_curve_scalar (Impl) (Other_impl)
end

module Tock = struct
  include (
    Tock0 : module type of Tock0 with module Inner_curve := Tock0.Inner_curve )

  module Fq = Snarky_field_extensions.Field_extensions.F (Tock0)

  module Inner_curve = struct
    include Tock0.Inner_curve

    include Sexpable.Of_sexpable
              (struct
                type t = Field.t * Field.t [@@deriving sexp]
              end)
              (struct
                type nonrec t = t

                let to_sexpable = to_affine_exn

                let of_sexpable = of_affine
              end)

    include Make_inner_curve_aux (Tock0) (Tick0)

    module Checked = struct
      include Snarky_curves.Make_weierstrass_checked (Fq) (Scalar)
                (struct
                  include Tock0.Inner_curve
                end)
                (Params)
                (struct
                  let add = None
                end)

      let add_known_unsafe t x = add_unsafe t (constant x)
    end

    let typ = Checked.typ
  end
end

module Tick = struct
  include (
    Tick0 :
      module type of Tick0
        with module Field := Tick0.Field
         and module Inner_curve := Tick0.Inner_curve )

  module Field = struct
    include Tick0.Field
    include Hashable.Make (Tick0.Field)
    module Bits = Bits.Make_field (Tick0.Field) (Tick0.Bigint)

    let size_in_triples = Int.((size_in_bits + 2) / 3)
  end

  module Fq = Snarky_field_extensions.Field_extensions.F (Tick0)

  module Inner_curve = struct
    include Crypto_params.Tick.Inner_curve

    include Sexpable.Of_sexpable
              (struct
                type t = Field.t * Field.t [@@deriving sexp]
              end)
              (struct
                type nonrec t = t

                let to_sexpable = to_affine_exn

                let of_sexpable = of_affine
              end)

    module Scalar = struct
      include Tock.Field

      module Checked = struct
        type t =
          | Arbitrary of (Field.Var.t * Boolean.var)
          (* A random scalar field element (Fq element) fits in an
             Fp element. *)
          | Random of Field.Var.t
      end

      let typ =
        Typ.transport_var Pickles.Impls.Step.Other_field.typ
          ~back:(fun x -> Checked.Arbitrary x)
          ~there:(function
            | Checked.Arbitrary x -> x | Random _ -> assert false)
    end

    type var = Field.Var.t * Field.Var.t

    module Checked = struct
      let typ = Pickles.Step_main_inputs.Inner_curve.typ

      module Assert = struct
        let equal (t1 : var) (t2 : var) =
          Run.make_checked (fun () ->
              Pickles.Step_main_inputs.Inner_curve.assert_equal t1 t2)
          |> Tick0.with_state (As_prover.return ())

        let on_curve (t : var) =
          Run.make_checked (fun () ->
              Pickles.Step_main_inputs.Inner_curve.assert_on_curve t)
          |> Tick0.with_state (As_prover.return ())
      end

      let ( + ) p1 p2 =
        Run.make_checked (fun () -> Pickles.Step_main_inputs.Ops.add_fast p1 p2)
        |> Tick0.with_state (As_prover.return ())

      (*
         Let G be a group over Fp with scalar field Fq.

         Using the fast constraints, in the Fp circuit, we can compute

         scale_fast g s = Fq(2^n + s) * g

         What we would like to do is compute s * g.

         Given a random `s : Fq`, represented as an Fp element,
         we can do this by simply subtracting off 2^n. Let's show that this
         will give the same result whether we do it in Fq or Fp (with high probability).

         Let r = 2*q - 2^n. We have r in [0, q), and r = -2^n in Fq.

         Now, we claim that for a random s in [0, p), s + r < p. This would imply
         that we can compute this sum in Fp, and get the same result as the result
         in Fq. So let's show it.

         s + r < p
         iff
         s is in the range [0, p - r)

         The probability of this is (p - r) / p. So, the probability of this NOT happening is
         1 - (p - r) / p = (p - (p - r)) / = r / p.

         Now, with
         q = 28948022309329048855892746252171976963363056481941647379679742748393362948097
         n = 255,
         we have
         r = 2*q - 2^n = 91120631063012739630693492830161076226

         which is a 127 bit number. p on the other hand is a 255 bit number.
         So, the quotient r / p is less than 1 / 2^128, and thus the probability that
         the addition is incorrect is less than 1 / 2^128, and can be discounted.

         So, if we have s which is the output of a random oracle, we can compute

         s * g

         as

         scale_fast g (s +_{Fp} 91120631063012739630693492830161076226)
         = Fq(2^n + (s - 2^n)) g = s * g
      *)

      module F = struct
        module Impl = Pickles.Impls.Step

        type t = Impl.Field.t

        let typ = Impl.Field.typ

        module Constant = struct
          include Field

          let to_bigint : t -> Impl.Bigint.t = Impl.Bigint.of_field
        end
      end

      let scale_random (g : var) (s : Scalar.Checked.t) : (var, _) Checked.t =
        let neg_two_to_n =
          Field.Var.constant
            (Field.of_string "91120631063012739630693492830161076226")
        in
        Run.make_checked (fun () ->
            let s' =
              let s =
                match s with
                | Arbitrary (high, low) ->
                    Field.Var.scale high (Field.of_int 2)
                    |> Field.Checked.( + ) (low :> Field.Var.t)
                | Random s ->
                    s
              in
              Field.Checked.( + ) s neg_two_to_n
            in
            Pickles.Step_main_inputs.Ops.scale_fast2'
              (module F)
              ~num_bits:Field.size_in_bits g s')
        |> Tick0.with_state (As_prover.return ())

      let shift =
        Pickles_types.Shifted_value.Type2.Shift.create (module Tock.Field)

      let scale_known (g0 : t) (s : Scalar.Checked.t) : (var, _) Checked.t =
        let const =
          Fn.compose Pickles.Step_main_inputs.Inner_curve.constant to_affine_exn
        in
        let g = const g0 in
        match s with
        | Arbitrary s ->
            let correction =
              const
                (negate
                   (scale g0 (Pickles.Common.Shifts.tock2 :> Tock.Field.t)))
            in
            let c =
              Run.make_checked (fun () ->
                  Pickles.Step_main_inputs.Ops.scale_fast2 g
                    ~num_bits:Field.size_in_bits (Shifted_value s)
                  |> Pickles.Step_main_inputs.Ops.add_fast correction)
            in
            Tick0.with_state (As_prover.return ()) c
        | Random _ ->
            scale_random g s

      let negate = Pickles.Step_main_inputs.Inner_curve.negate

      type t = var
    end

    let typ : (var, t) Typ.t =
      Typ.transport Checked.typ
        ~there:Crypto_params.Tick.Inner_curve.to_affine_exn
        ~back:Crypto_params.Tick.Inner_curve.of_affine
  end

  module Util = Snark_util.Make (Tick0)

  let m : Run.field Snarky_backendless.Snark.m = (module Run)

  let make_checked c = with_state (As_prover.return ()) (Run.make_checked c)
end

(* Let n = Tick.Field.size_in_bits.
   Let k = n - 3.
   The reason k = n - 3 is as follows. Inside [meets_target], we compare
   a value against 2^k. 2^k requires k + 1 bits. The comparison then unpacks
   a (k + 1) + 1 bit number. This number cannot overflow so it is important that
   k + 1 + 1 < n. Thus k < n - 2.

   However, instead of using `Field.size_in_bits - 3` we choose `Field.size_in_bits - 8`
   to clamp the easiness. To something not-to-quick on a personal laptop from mid 2010s.
*)
let target_bit_length = Tick.Field.size_in_bits - 8

module type Snark_intf = Snark_intf.S

module Group_map = struct
  let to_group x =
    Group_map.to_group (module Tick.Field) ~params:(Tock.group_map_params ()) x

  module Checked = struct
    let to_group x =
      Snarky_group_map.Checked.to_group
        (module Tick.Run)
        ~params:(Tock.group_map_params ()) x
  end
end
