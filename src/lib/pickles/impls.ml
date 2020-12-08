open Pickles_types
open Core_kernel
open Import
open Backend
module Wrap_impl = Snarky_backendless.Snark.Run.Make (Tock) (Unit)

let test_bit x i = B.(shift_right x i land one = one)

module Step = struct
  module Impl = Snarky_backendless.Snark.Run.Make (Tick) (Unit)
  include Impl

  module Other_field = struct
    (* Tick.Field.t = p < q = Tock.Field.t *)
    let size_in_bits = Tock.Field.size_in_bits

    module Constant = Tock.Field

    type t = (* Low bits, high bit *)
      Field.t * Boolean.var

    let forbidden_shifted_values =
      let neg_two_to_n =
        B.(
          neg (pow (of_int 2) (of_int Constant.size_in_bits))
          % Wrap_impl.Bigint.to_bignum_bigint Constant.size)
      in
      List.map
        ~f:(fun x ->
          let hi = test_bit x (Field.size_in_bits - 1) in
          let lo = B.shift_right x 1 in
          (Impl.Bigint.(to_field (of_bignum_bigint lo)), hi) )
        [neg_two_to_n; B.(neg_two_to_n - one)]

    let (typ_unchecked : (t, Constant.t) Typ.t), check =
      let t0 =
        Typ.transport
          (Typ.tuple2 Field.typ Boolean.typ)
          ~there:(fun x ->
            let low, high = Util.split_last (Tock.Field.to_bits x) in
            (Field.Constant.project low, high) )
          ~back:(fun (low, high) ->
            let low, _ = Util.split_last (Field.Constant.unpack low) in
            Tock.Field.of_bits (low @ [high]) )
      in
      let check t =
        let open Internal_Basic in
        let open Let_syntax in
        let equal (x1, b1) (x2, b2) =
          let%bind x_eq = Field.Checked.equal x1 (Field.Var.constant x2) in
          let b_eq = match b2 with true -> b1 | false -> Boolean.not b1 in
          Boolean.( && ) x_eq b_eq
        in
        let%bind () = t0.check t in
        Checked.List.map forbidden_shifted_values ~f:(equal t)
        >>= Boolean.any >>| Boolean.not >>= Boolean.Assert.is_true
      in
      (t0, check)

    let typ = {typ_unchecked with check}

    let to_bits (x, b) = Field.unpack x ~length:(Field.size_in_bits - 1) @ [b]
  end

  module Digest = Digest.Make (Impl)
  module Challenge = Challenge.Make (Impl)

  let input ~branching ~wrap_rounds =
    let open Types.Pairing_based.Statement in
    let spec = spec branching wrap_rounds in
    let (T (typ, f)) =
      Spec.packed_typ
        (module Impl)
        (T
           ( Shifted_value.typ Other_field.typ_unchecked
           , fun (Shifted_value x as t) ->
               Impl.run_checked (Other_field.check x) ;
               t ))
        spec
    in
    let typ = Typ.transport typ ~there:to_data ~back:of_data in
    Spec.ETyp.T (typ, fun x -> of_data (f x))
end

module Wrap = struct
  module Impl = Wrap_impl
  include Impl
  module Challenge = Challenge.Make (Impl)
  module Digest = Digest.Make (Impl)
  module Wrap_field = Tock.Field
  module Step_field = Tick.Field

  module Other_field = struct
    module Constant = Tick.Field
    open Impl

    type t = Field.t

    let forbidden_shifted_values =
      let neg_two_to_n =
        B.(
          neg (pow (of_int 2) (of_int Constant.size_in_bits))
          % Step.Impl.Bigint.to_bignum_bigint Constant.size)
      in
      List.map
        ~f:(fun x -> Impl.Bigint.(to_field (of_bignum_bigint x)))
        [neg_two_to_n; B.(neg_two_to_n - one)]

    let typ_unchecked, check =
      let t0 =
        Typ.transport Field.typ
          ~there:(Fn.compose Tock.Field.of_bits Tick.Field.to_bits)
          ~back:(Fn.compose Tick.Field.of_bits Tock.Field.to_bits)
      in
      let check t =
        let open Internal_Basic in
        let open Let_syntax in
        let equal x1 x2 = Field.Checked.equal x1 (Field.Var.constant x2) in
        let%bind () = t0.check t in
        Checked.List.map forbidden_shifted_values ~f:(equal t)
        >>= Boolean.any >>| Boolean.not >>= Boolean.Assert.is_true
      in
      (t0, check)

    let typ = {typ_unchecked with check}

    let to_bits x = Field.unpack x ~length:Field.size_in_bits
  end

  let input () =
    let fp : ('a, Other_field.Constant.t) Typ.t = Other_field.typ_unchecked in
    let open Types.Dlog_based.Statement in
    let (T (typ, f)) =
      Spec.packed_typ
        (module Impl)
        (T
           ( Shifted_value.typ fp
           , fun (Shifted_value x as t) ->
               Impl.run_checked (Other_field.check x) ;
               t ))
        In_circuit.spec
    in
    let typ =
      Typ.transport typ ~there:In_circuit.to_data ~back:In_circuit.of_data
    in
    Spec.ETyp.T (typ, fun x -> In_circuit.of_data (f x))
end
