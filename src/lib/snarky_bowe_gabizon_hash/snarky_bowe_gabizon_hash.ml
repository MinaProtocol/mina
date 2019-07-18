open Core_kernel
open Fold_lib
open Snarky

(* TODO: Have a compatibility layer so we only need the module M. *)
module Make
    (M : Snark_intf.Run with type prover_state = unit)
    (Impl : Snark_intf.S with type field = M.field)
    (Inputs : Inputs_intf.S
              with type field := M.field
               and type ('a, 'b) checked := ('a, 'b) Impl.Checked.t) =
struct
  open Inputs
  open M

  let bottom_bit y = List.hd_exn (Field.unpack_full y :> Boolean.var list)

  let choose_unpacking = Field.choose_preimage_var ~length:Field.size_in_bits

  let g1_to_bits (x, y) = bottom_bit y :: choose_unpacking x

  let g2_to_bits (x, y) =
    let y0 = List.hd_exn (Fqe.to_list y) in
    Field.Assert.non_zero y0 ;
    bottom_bit y0 :: List.concat_map (Fqe.to_list x) ~f:choose_unpacking

  module Blake2 = Snarky_blake2.Make (Impl)

  let random_oracle x =
    let open Impl in
    let open Let_syntax in
    Field.Checked.choose_preimage_var ~length:Field.size_in_bits x
    >>| Array.of_list >>= Blake2.blake2s >>| Array.to_list
    >>| Field.Var.project

  let make_checked f =
    M.make_checked f |> M.Internal_Basic.with_state (Impl.As_prover.return ())

  let group_map x =
    make_checked (fun () ->
        Snarky_group_map.Checked.to_group (module M) ~params x )

  let hash ?message ~a ~b ~c ~delta_prime =
    let open Impl in
    let open Let_syntax in
    make_checked (fun () ->
        g1_to_bits a @ g2_to_bits b @ g1_to_bits c @ g2_to_bits delta_prime
        @ Option.value_map message ~default:[] ~f:Array.to_list
        |> Fold.of_list
        |> Fold.group3 ~default:Boolean.false_ )
    >>= pedersen >>= random_oracle >>= group_map
end

let%test_module "test" =
  ( module struct
    open Tuple_lib
    module C = Backends.Mnt4
    module D = Backends.Mnt6
    module B = C.Default
    module Impl = Snark.Make (B)
    module Dimpl = Snark.Make (D.Default)
    module Run = Snark.Run.Make (B) (Unit)

    module Fqe = struct
      open Run

      type t = Field.t Triple.t

      let to_list (x, y, z) = [x; y; z]
    end

    let curve_gen scale_one =
      let open Quickcheck.Generator in
      filter Dimpl.Field.gen ~f:Dimpl.Field.(Fn.compose not (equal zero))
      >>| scale_one

    module Curve = struct
      include D.G1

      type var = Run.Field.t * Run.Field.t

      module Checked = struct
        include Snarky_curves.Make_weierstrass_checked
                  (Snarky_field_extensions.Field_extensions.F
                     (Impl))
                     (struct
                       include D.Bigint.R

                       let of_int = Fn.compose of_field D.Field.of_int
                     end)
                  (D.G1)
                  (D.G1.Coefficients)

        let add_known_unsafe t x = add_unsafe t (constant x)
      end

      let gen = curve_gen (scale_field one)
    end

    let pedersen_params =
      let len = 10 * Impl.Field.size_in_bits in
      let chunk = Impl.Field.size_in_bits / 4 in
      let arr = Array.create ~len Curve.(zero, zero, zero, zero) in
      let rec go acc i =
        let times4 x =
          let open Curve in
          x |> double |> double
        in
        if i < len then (
          let x2 = Curve.double acc in
          let x3 = Curve.add x2 acc in
          let x4 = Curve.double x2 in
          arr.(i) <- (acc, x2, x3, x4) ;
          let i = i + 1 in
          let acc = if i mod chunk = 0 then Curve.random () else times4 x4 in
          go acc i )
      in
      go (Curve.random ()) 0 ;
      arr

    module Pedersen =
      Snarky.Pedersen.Make (Impl) (Curve)
        (struct
          let params =
            Array.map ~f:(Quadruple.map ~f:Curve.to_affine_exn) pedersen_params
        end)

    module Inputs_checked = struct
      module Fqe = Fqe

      let pedersen f =
        let open Impl.Checked in
        Pedersen.hash ~init:(0, `Value Curve.zero) (Fold.to_list f)
        >>| Pedersen.digest

      let params =
        Group_map.Params.create
          (module Impl.Field)
          ~a:Curve.Coefficients.a ~b:Curve.Coefficients.b
    end

    module Inputs = struct
      open Impl
      module Bigint = Bigint

      module Field = struct
        include Field

        let to_bits = Field.unpack

        let of_bits = Field.project

        let fold_bits = Fn.compose Fold.of_list to_bits

        let fold = Fn.compose (Fold.group3 ~default:false) fold_bits
      end

      module Fqe = struct
        type t = Field.t Triple.t

        let to_list = Inputs_checked.Fqe.to_list
      end

      module G1 = struct
        type t = Curve.t sexp_opaque [@@deriving sexp]

        include (Curve : module type of Curve with type t := t)
      end

      module G2 = struct
        include D.G2

        let to_affine_exn t =
          let f v =
            let v = D.Fqe.to_vector v in
            C.Field.Vector.(get v 0, get v 1, get v 2)
          in
          let x, y = D.G2.to_affine_exn t in
          (f x, f y)

        let of_affine (x, y) =
          let f a =
            let open C.Field.Vector in
            let t = C.Field.Vector.create () in
            List.iter (Fqe.to_list a) ~f:(emplace_back t) ;
            D.Fqe.of_vector t
          in
          of_affine (f x, f y)

        let typ =
          let fqe = Typ.tuple3 Field.typ Field.typ Field.typ in
          Typ.tuple2 fqe fqe
          |> Typ.transport ~there:to_affine_exn ~back:of_affine

        let gen = curve_gen (scale_field one)
      end

      let params = Inputs_checked.params

      module Pedersen = Pedersen_lib.Pedersen.Make (Field) (G1)

      let pedersen_params =
        Array.map pedersen_params ~f:(fun (x, _, _, _) -> x)

      let pedersen t =
        Pedersen.digest_fold (Pedersen.State.create pedersen_params) t
    end

    module H = Bowe_gabizon_hash.Make (Inputs)
    module H_checked = Make (Run) (Impl) (Inputs_checked)

    let%test_unit "checked-unchecked equivalence" =
      let open Quickcheck.Generator.Let_syntax in
      let message =
        let%bind len = Int.gen_incl 0 100 in
        let%map xs = List.gen_with_length len Bool.quickcheck_generator in
        Array.of_list xs
      in
      let input =
        let%map message = message
        and a = Curve.gen
        and b = Inputs.G2.gen
        and c = Curve.gen
        and delta_prime = Inputs.G2.gen in
        (Array.length message, (message, a, b, c, delta_prime))
      in
      let k f (message, a, b, c, delta_prime) =
        f ?message:(Some message) ~a ~b ~c ~delta_prime
      in
      Quickcheck.test ~trials:3 input ~f:(fun (message_length, inp) ->
          let typ =
            let open Impl.Typ in
            of_hlistable
              [ array ~length:message_length Impl.Boolean.typ
              ; Curve.Checked.typ
              ; Inputs.G2.typ
              ; Curve.Checked.typ
              ; Inputs.G2.typ ]
              ~var_to_hlist:(fun (a, b, c, d, e) -> [a; b; c; d; e])
              ~var_of_hlist:(fun [a; b; c; d; e] -> (a, b, c, d, e))
              ~value_to_hlist:(fun (a, b, c, d, e) -> [a; b; c; d; e])
              ~value_of_hlist:(fun [a; b; c; d; e] -> (a, b, c, d, e))
          in
          Impl.Test.test_equal ~equal:Curve.equal typ Curve.Checked.typ
            (k H_checked.hash) (k H.hash) inp )
  end )
