open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

module Make_add (Impl : Kimchi_pasta_snarky_backend.Snark_intf) = struct
  module Utils = Util.Make (Impl)

  let seal = Tuple_lib.Double.map ~f:Utils.seal

  let add_fast ?(check_finite = true) ((x1, y1) as p1) ((x2, y2) as p2) :
      Impl.Field.t * Impl.Field.t =
    let p1 = seal p1 in
    let p2 = seal p2 in
    let open Impl in
    let open Field.Constant in
    let bool b = if b then one else zero in
    let eq a b = As_prover.(equal (read_var a) (read_var b)) in
    let same_x_bool = lazy (eq x1 x2) in
    let ( ! ) = Lazy.force in
    let ( !! ) = As_prover.read_var in
    let mk f = exists Field.typ ~compute:f in
    let same_x = mk (fun () -> bool !same_x_bool) in
    let inf =
      if check_finite then Field.zero
      else mk (fun () -> bool (!same_x_bool && not (eq y1 y2)))
    in
    let inf_z =
      mk (fun () ->
          if eq y1 y2 then zero
          else if !same_x_bool then inv (!!y2 - !!y1)
          else zero )
    in
    let x21_inv =
      mk (fun () -> if !same_x_bool then zero else inv (!!x2 - !!x1))
    in
    let s =
      mk (fun () ->
          if !same_x_bool then
            let x1_squared = square !!x1 in
            let y1 = !!y1 in
            (x1_squared + x1_squared + x1_squared) / (y1 + y1)
          else (!!y2 - !!y1) / (!!x2 - !!x1) )
    in
    let x3 = mk (fun () -> square !!s - (!!x1 + !!x2)) in
    let y3 = mk (fun () -> (!!s * (!!x1 - !!x3)) - !!y1) in
    let p3 = (x3, y3) in
    with_label "add_fast" (fun () ->
        assert_
          (EC_add_complete
             { p1; p2; p3; inf; same_x; slope = s; inf_z; x21_inv } ) ;
        p3 )
end

module Make
    (Impl : Kimchi_pasta_snarky_backend.Snark_intf)
    (G : Intf.Group(Impl).S with type t = Impl.Field.t * Impl.Field.t) =
struct
  open Impl
  include Make_add (Impl)

  let bits_per_chunk = 5

  (* Number of chunks needed to cover the given number of bits. *)
  let chunks_needed ~num_bits =
    (num_bits + (bits_per_chunk - 1)) / bits_per_chunk

  let scale_fast_msb_bits base
      (Pickles_types.Shifted_value.Type1.Shifted_value
        (bits_msb : Boolean.var array) ) : Field.t * Field.t =
    let ((x_base, y_base) as base) = seal base in
    let ( !! ) = As_prover.read_var in
    let mk f = exists Field.typ ~compute:f in
    (* MSB bits *)
    let num_bits = Array.length bits_msb in
    let chunks = num_bits / bits_per_chunk in
    [%test_eq: int] (num_bits mod bits_per_chunk) 0 ;
    let acc = ref (add_fast base base) in
    let n_acc = ref Field.zero in
    let rounds_rev = ref [] in
    for chunk = 0 to chunks - 1 do
      let open Field.Constant in
      let double x = x + x in
      let bs =
        Array.init bits_per_chunk ~f:(fun i ->
            (bits_msb.(Int.((chunk * bits_per_chunk) + i)) :> Field.t) )
      in
      let n_acc_prev = !n_acc in
      n_acc :=
        mk (fun () ->
            Array.fold bs ~init:!!n_acc_prev ~f:(fun acc b -> double acc + !!b) ) ;
      let accs, slopes =
        Array.fold_map bs ~init:!acc ~f:(fun (x_acc, y_acc) b ->
            let s1 =
              mk (fun () ->
                  (!!y_acc - (!!y_base * (double !!b - one)))
                  / (!!x_acc - !!x_base) )
            in
            let s1_squared = mk (fun () -> square !!s1) in
            let s2 =
              mk (fun () ->
                  (double !!y_acc / (double !!x_acc + !!x_base - !!s1_squared))
                  - !!s1 )
            in
            let x_res = mk (fun () -> !!x_base + square !!s2 - !!s1_squared) in
            let y_res = mk (fun () -> ((!!x_acc - !!x_res) * !!s2) - !!y_acc) in
            let acc' = (x_res, y_res) in
            (acc', (acc', s1)) )
        |> snd |> Array.unzip
      in
      let accs = Array.append [| !acc |] accs in
      acc := Array.last accs ;
      rounds_rev :=
        { Kimchi_backend_common.Scale_round.accs
        ; bits = bs
        ; ss = slopes
        ; n_prev = n_acc_prev
        ; n_next = !n_acc
        ; base
        }
        :: !rounds_rev
    done ;
    assert_ (EC_scale { state = Array.of_list_rev !rounds_rev }) ;
    (* TODO: Return n_acc ? *)
    !acc

  (*
     Computes

     fun (g, t) -> (2 * t + 1 + 2^len(t)) g *)
  let scale_fast_unpack base
      (Pickles_types.Shifted_value.Type1.Shifted_value (scalar : Field.t))
      ~num_bits : (Field.t * Field.t) * Boolean.var array =
    let ((x_base, y_base) as base) = seal base in
    let ( !! ) = As_prover.read_var in
    let mk f = exists Field.typ ~compute:f in
    (* MSB bits *)
    (*
    let num_bits = Field.size_in_bits in *)
    let chunks = num_bits / bits_per_chunk in
    [%test_eq: int] (num_bits mod bits_per_chunk) 0 ;
    let bits_msb =
      exists (Typ.array ~length:num_bits Field.typ) ~compute:(fun () ->
          let open Field.Constant in
          unpack !!scalar |> Fn.flip List.take num_bits
          |> Array.of_list_rev_map ~f:(fun b -> if b then one else zero) )
    in
    let acc = ref (add_fast base base) in
    let n_acc = ref Field.zero in
    let rounds_rev = ref [] in
    for chunk = 0 to chunks - 1 do
      let open Field.Constant in
      let double x = x + x in
      let bs =
        Array.init bits_per_chunk ~f:(fun i ->
            bits_msb.(Int.((chunk * bits_per_chunk) + i)) )
      in
      let n_acc_prev = !n_acc in
      n_acc :=
        mk (fun () ->
            Array.fold bs ~init:!!n_acc_prev ~f:(fun acc b -> double acc + !!b) ) ;
      let accs, slopes =
        Array.fold_map bs ~init:!acc ~f:(fun (x_acc, y_acc) b ->
            let s1 =
              mk (fun () ->
                  (!!y_acc - (!!y_base * (double !!b - one)))
                  / (!!x_acc - !!x_base) )
            in
            let s1_squared = mk (fun () -> square !!s1) in
            let s2 =
              mk (fun () ->
                  (double !!y_acc / (double !!x_acc + !!x_base - !!s1_squared))
                  - !!s1 )
            in
            let x_res = mk (fun () -> !!x_base + square !!s2 - !!s1_squared) in
            let y_res = mk (fun () -> ((!!x_acc - !!x_res) * !!s2) - !!y_acc) in
            let acc' = (x_res, y_res) in
            (acc', (acc', s1)) )
        |> snd |> Array.unzip
      in
      let accs = Array.append [| !acc |] accs in
      acc := Array.last accs ;
      rounds_rev :=
        { Kimchi_backend_common.Scale_round.accs
        ; bits = bs
        ; ss = slopes
        ; n_prev = n_acc_prev
        ; n_next = !n_acc
        ; base
        }
        :: !rounds_rev
    done ;
    assert_ (EC_scale { state = Array.of_list_rev !rounds_rev }) ;
    Field.Assert.equal !n_acc scalar ;
    let bits_lsb =
      let bs = Array.map bits_msb ~f:Boolean.Unsafe.of_cvar in
      Array.rev_inplace bs ; bs
    in
    (!acc, bits_lsb)

  let scale_fast_unpack base scalar ~num_bits :
      (Field.t * Field.t) * Boolean.var array =
    with_label "scale_fast_unpack" (fun () ->
        scale_fast_unpack base scalar ~num_bits )

  let scale_fast base s ~num_bits =
    let r, _bits = scale_fast_unpack base s ~num_bits in
    r

  module type Scalar_field_intf = sig
    module Constant : sig
      include Plonk_checks.Field_intf

      val to_bigint : t -> Impl.Bigint.t
    end

    type t = Field.t

    val typ : (t, Constant.t) Typ.t
  end

  (* Computes

     (g, s) -> (s + 2^{len(s) - 1})

     as

     let h = scale_fast g (s >> 1) in
     if s is odd then h else h - g
     ==
     let h = [ 2 * (s >> 1) + 1 + 2^{len(s) - 1} ] * g in
     if s is odd then h else h - g

     since if s is odd, then s = 2 * (s >> 1) + 1, and otherwise,
     s = 2 * (s >> 1) + 1 - 1.
  *)
  let scale_fast2 (g : G.t)
      (Pickles_types.Shifted_value.Type2.Shifted_value
        ((s_div_2 : Field.t), (s_odd : Boolean.var)) ) ~(num_bits : int) : G.t =
    let s_div_2_bits = num_bits - 1 in
    (* The number of chunks need for scaling by s_div_2. *)
    let chunks_needed = chunks_needed ~num_bits:s_div_2_bits in
    let actual_bits_used = chunks_needed * bits_per_chunk in
    let h, bits_lsb =
      scale_fast_unpack g (Shifted_value s_div_2) ~num_bits:actual_bits_used
    in
    (* Constrain the top bits of s_div_2 to be 0. *)
    with_label __LOC__ (fun () ->
        for i = s_div_2_bits to Array.length bits_lsb - 1 do
          Field.Assert.equal Field.zero (bits_lsb.(i) :> Field.t)
        done ) ;
    with_label __LOC__ (fun () ->
        G.if_ s_odd ~then_:h ~else_:(add_fast h (G.negate g)) )

  let scale_fast2' (type scalar_field)
      (module Scalar_field : Scalar_field_intf
        with type Constant.t = scalar_field ) g (s : Scalar_field.t) ~num_bits =
    let ((s_div_2, s_odd) as s_parts) =
      with_label __LOC__ (fun () ->
          exists
            Typ.(Scalar_field.typ * Boolean.typ)
            ~compute:
              As_prover.(
                fun () ->
                  let s = read Scalar_field.typ s in
                  let open Scalar_field.Constant in
                  let s_odd = Bigint.test_bit (to_bigint s) 0 in
                  ((if s_odd then s - one else s) / of_int 2, s_odd)) )
    in

    (* In this case, it's safe to use this field to compute

       2 s_div_2 + b

       in the other field. *)
    with_label __LOC__ (fun () ->
        Field.Assert.equal Field.((of_int 2 * s_div_2) + (s_odd :> Field.t)) s ) ;
    scale_fast2 g (Pickles_types.Shifted_value.Type2.Shifted_value s_parts)
      ~num_bits

  let scale_fast a b = with_label __LOC__ (fun () -> scale_fast a b)
end
