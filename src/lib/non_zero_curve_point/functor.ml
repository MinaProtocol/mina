open Core_kernel
open Intf

module Make (Tick : Tick_S) = struct
  open Tick

  let parity y = Bigint.(test_bit (of_field y) 0)

  let gen_uncompressed =
    Quickcheck.Generator.filter_map Field.gen_uniform ~f:(fun x ->
        let open Option.Let_syntax in
        let%map y = Inner_curve.find_y x in
        (x, y) )

  module Compressed = struct
    open Compressed_poly

    let compress (x, y) = {Poly.x; is_odd= parity y}

    (* sexp operations written manually, don't derive them *)
    type t = (Field.t, bool) Poly.t [@@deriving eq, compare, hash]

    let empty = Poly.{x= Field.zero; is_odd= false}

    type var = (Field.Var.t, Boolean.var) Poly.t

    let to_hlist Poly.Stable.Latest.{x; is_odd} = Snarky.H_list.[x; is_odd]

    let of_hlist : (unit, 'a -> 'b -> unit) Snarky.H_list.t -> ('a, 'b) Poly.t
        =
      Snarky.H_list.(fun [x; is_odd] -> {x; is_odd})

    let typ : (var, t) Typ.t =
      Typ.of_hlistable [Field.typ; Boolean.typ] ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let var_of_t ({x; is_odd} : t) : var =
      {x= Field.Var.constant x; is_odd= Boolean.var_of_value is_odd}

    let assert_equal (t1 : var) (t2 : var) =
      let%map () = Field.Checked.Assert.equal t1.x t2.x
      and () = Boolean.Assert.(t1.is_odd = t2.is_odd) in
      ()

    let to_input {Poly.x; is_odd} =
      {Random_oracle.Input.field_elements= [|x|]; bitstrings= [|[is_odd]|]}

    module Checked = struct
      let equal t1 t2 =
        let%bind x_eq = Field.Checked.equal t1.Poly.x t2.Poly.x in
        let%bind odd_eq = Boolean.equal t1.is_odd t2.is_odd in
        Boolean.(x_eq && odd_eq)

      let to_input = to_input

      let if_ cond ~then_:t1 ~else_:t2 =
        let%map x = Field.Checked.if_ cond ~then_:t1.Poly.x ~else_:t2.Poly.x
        and is_odd = Boolean.if_ cond ~then_:t1.is_odd ~else_:t2.is_odd in
        Poly.{x; is_odd}

      module Assert = struct
        let equal t1 t2 =
          let%map () = Field.Checked.Assert.equal t1.Poly.x t2.Poly.x
          and () = Boolean.Assert.(t1.is_odd = t2.is_odd) in
          ()
      end
    end
  end

  module Uncompressed = struct
    let decompress ({x; is_odd} : Compressed.t) =
      Option.map (Inner_curve.find_y x) ~f:(fun y ->
          let y_parity = parity y in
          let y = if Bool.(is_odd = y_parity) then y else Field.negate y in
          (x, y) )

    let compress = Compressed.compress

    let decompress_exn t = Option.value_exn (decompress t)

    type t =
      Field.t * Field.t
      (* sexp operations written manually, don't derive them *)
    [@@deriving eq, compare, hash]

    let gen : t Quickcheck.Generator.t = gen_uncompressed

    type var = Field.Var.t * Field.Var.t

    let assert_equal var1 var2 =
      let open Field.Checked.Assert in
      let v1_f1, v1_f2 = var1 in
      let v2_f1, v2_f2 = var2 in
      let%bind () = equal v1_f1 v2_f1 in
      let%map () = equal v1_f2 v2_f2 in
      ()

    let var_of_t (x, y) = (Field.Var.constant x, Field.Var.constant y)

    let typ : (var, t) Typ.t = Typ.(field * field)

    let ( = ) = equal

    let of_inner_curve_exn = Inner_curve.to_affine_exn

    let to_inner_curve = Inner_curve.of_affine

    let parity_var y =
      let%map bs = Field.Checked.unpack_full y in
      List.hd_exn (Bitstring_lib.Bitstring.Lsb_first.to_list bs)

    let decompress_var ({x; is_odd} as c : Compressed.var) =
      let open Let_syntax in
      let%bind y =
        exists Typ.field
          ~compute:
            As_prover.(
              map (read Compressed.typ c) ~f:(fun c -> snd (decompress_exn c)))
      in
      let%map () = Inner_curve.Checked.Assert.on_curve (x, y)
      and () = parity_var y >>= Boolean.Assert.(( = ) is_odd) in
      (x, y)

    let%snarkydef compress_var ((x, y) : var) : (Compressed.var, _) Checked.t =
      let open Compressed_poly in
      let%map is_odd = parity_var y in
      {Poly.x; is_odd}
  end
end
