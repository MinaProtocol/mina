open Core_kernel
open Import
module SC = Scalar_challenge

(* Implementation of the algorithm described on page 29 of the Halo paper
   https://eprint.iacr.org/2019/1021.pdf
*)

let num_bits = 128

(* Has the side effect of checking that [scalar] fits in 128 bits. *)
let to_field_checked' (type f) ?(num_bits = num_bits)
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
    { SC.inner = (scalar : Impl.Field.t) } =
  let open Impl in
  let neg_one = Field.Constant.(negate one) in
  let a_func = function
    | 0 ->
        Field.Constant.zero
    | 1 ->
        Field.Constant.zero
    | 2 ->
        neg_one
    | 3 ->
        Field.Constant.one
    | _ ->
        raise (Invalid_argument "a_func")
  in
  let b_func = function
    | 0 ->
        neg_one
    | 1 ->
        Field.Constant.one
    | 2 ->
        Field.Constant.zero
    | 3 ->
        Field.Constant.zero
    | _ ->
        raise (Invalid_argument "a_func")
  in
  let ( !! ) = As_prover.read_var in
  (* MSB bits *)
  let bits_msb =
    lazy
      (let open Field.Constant in
      unpack !!scalar |> Fn.flip List.take num_bits |> Array.of_list_rev
      (*
    |> Array.of_list_rev_map ~f:(fun b -> if b then one else zero) *))
  in
  let nybbles_per_row = 8 in
  let bits_per_row = 2 * nybbles_per_row in
  [%test_eq: int] (num_bits mod bits_per_row) 0 ;
  let rows = num_bits / bits_per_row in
  let nybbles_by_row =
    lazy
      (Array.init rows ~f:(fun i ->
           Array.init nybbles_per_row ~f:(fun j ->
               let bit = (bits_per_row * i) + (2 * j) in
               let b0 = (Lazy.force bits_msb).(bit + 1) in
               let b1 = (Lazy.force bits_msb).(bit) in
               Bool.to_int b0 + (2 * Bool.to_int b1))))
  in
  let two = Field.of_int 2 in
  let a = ref two in
  let b = ref two in
  let n = ref Field.zero in
  let mk f = exists Field.typ ~compute:f in
  let state = ref [] in
  for i = 0 to rows - 1 do
    let n0 = !n in
    let a0 = !a in
    let b0 = !b in
    let xs =
      Array.init nybbles_per_row ~f:(fun j ->
          mk (fun () ->
              Field.Constant.of_int (Lazy.force nybbles_by_row).(i).(j)))
    in
    let open Field.Constant in
    let double x = x + x in
    let n8 =
      mk (fun () ->
          Array.fold xs ~init:!!n0 ~f:(fun acc x ->
              (acc |> double |> double) + !!x))
    in
    let a8 =
      mk (fun () ->
          Array.fold
            (Lazy.force nybbles_by_row).(i)
            ~init:!!a0
            ~f:(fun acc x -> (acc |> double) + a_func x))
    in
    let b8 =
      mk (fun () ->
          Array.fold
            (Lazy.force nybbles_by_row).(i)
            ~init:!!b0
            ~f:(fun acc x -> (acc |> double) + b_func x))
    in
    state :=
      { Kimchi_backend_common.Endoscale_scalar_round.a0
      ; a8
      ; b0
      ; b8
      ; n0
      ; n8
      ; x0 = xs.(0)
      ; x1 = xs.(1)
      ; x2 = xs.(2)
      ; x3 = xs.(3)
      ; x4 = xs.(4)
      ; x5 = xs.(5)
      ; x6 = xs.(6)
      ; x7 = xs.(7)
      }
      :: !state ;
    n := n8 ;
    a := a8 ;
    b := b8 ;
    ()
  done ;
  with_label __LOC__ (fun () ->
      assert_
        [ { annotation = Some __LOC__
          ; basic =
              Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.(
                T (EC_endoscalar { state = Array.of_list_rev !state }))
          }
        ]) ;
  (!a, !b, !n)

let to_field_checked (type f) ?num_bits
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = f) ~endo
    ({ SC.inner = (scalar : Impl.Field.t) } as s) =
  let open Impl in
  let a, b, n = to_field_checked' ?num_bits (module Impl) s in
  Field.Assert.equal n scalar ;
  Field.(scale a endo + b)

let to_field_constant (type f) ~endo
    (module F : Plonk_checks.Field_intf with type t = f) { SC.inner = c } =
  let bits = Array.of_list (Challenge.Constant.to_bits c) in
  let a = ref (F.of_int 2) in
  let b = ref (F.of_int 2) in
  let one = F.of_int 1 in
  let neg_one = F.(of_int 0 - one) in
  for i = (128 / 2) - 1 downto 0 do
    let s = if bits.(2 * i) then one else neg_one in
    (a := F.(!a + !a)) ;
    (b := F.(!b + !b)) ;
    let r_2i1 = bits.((2 * i) + 1) in
    if r_2i1 then a := F.(!a + s) else b := F.(!b + s)
  done ;
  F.((!a * endo) + !b)

let test (type f)
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
    ~(endo : f) =
  let open Impl in
  let module T = Internal_Basic in
  let n = 128 in
  Quickcheck.test ~trials:10
    (Quickcheck.Generator.list_with_length n Bool.quickcheck_generator)
    ~f:(fun xs ->
      try
        T.Test.test_equal ~equal:Field.Constant.equal
          ~sexp_of_t:Field.Constant.sexp_of_t
          (Typ.list ~length:n Boolean.typ)
          Field.typ
          (fun s ->
            make_checked (fun () ->
                to_field_checked
                  (module Impl)
                  ~endo
                  (SC.create (Impl.Field.pack s))))
          (fun s ->
            to_field_constant
              (module Field.Constant)
              ~endo
              (SC.create (Challenge.Constant.of_bits s)))
          xs
      with e ->
        eprintf !"Input %{sexp: bool list}\n%!" xs ;
        raise e)

module Make
    (Impl : Snarky_backendless.Snark_intf.Run)
    (G : Intf.Group(Impl).S with type t = Impl.Field.t * Impl.Field.t)
    (Challenge : Challenge.S with module Impl := Impl) (Endo : sig
      val base : Impl.Field.Constant.t

      val scalar : G.Constant.Scalar.t
    end) =
struct
  open Impl
  module Scalar = G.Constant.Scalar

  type t = Challenge.t SC.t

  module Constant = struct
    type t = Challenge.Constant.t SC.t

    let to_field = to_field_constant ~endo:Endo.scalar (module Scalar)
  end

  let typ : (t, Constant.t) Typ.t = SC.typ Challenge.typ

  let num_bits = 128

  let seal = Util.seal (module Impl)

  let endo ?(num_bits = num_bits) t { SC.inner = (scalar : Field.t) } =
    let ( !! ) = As_prover.read_var in
    (* MSB bits *)
    let bits =
      lazy
        (let open Field.Constant in
        unpack !!scalar |> Fn.flip List.take num_bits
        |> Array.of_list_rev_map ~f:(fun b -> if b then one else zero))
    in
    let bits () = Lazy.force bits in
    let xt, yt = Tuple_lib.Double.map t ~f:seal in
    let bits_per_row = 4 in
    let rows = num_bits / bits_per_row in
    let acc =
      with_label __LOC__ (fun () ->
          let p = G.( + ) t (seal (Field.scale xt Endo.base), yt) in
          ref G.(p + p))
    in
    let n_acc = ref Field.zero in
    let mk f = exists Field.typ ~compute:f in
    let rounds_rev = ref [] in
    for i = 0 to rows - 1 do
      let n_acc_prev = !n_acc in
      let b1 = mk (fun () -> (bits ()).(i * bits_per_row)) in
      let b2 = mk (fun () -> (bits ()).((i * bits_per_row) + 1)) in
      let b3 = mk (fun () -> (bits ()).((i * bits_per_row) + 2)) in
      let b4 = mk (fun () -> (bits ()).((i * bits_per_row) + 3)) in
      let open Field.Constant in
      let double x = x + x in
      let xp, yp = !acc in
      let xq1 = mk (fun () -> (one + ((Endo.base - one) * !!b1)) * !!xt) in
      let yq1 = mk (fun () -> (double !!b2 - one) * !!yt) in

      let s1 = mk (fun () -> (!!yq1 - !!yp) / (!!xq1 - !!xp)) in
      let s1_squared = mk (fun () -> square !!s1) in
      let s2 =
        mk (fun () ->
            (double !!yp / (double !!xp + !!xq1 - !!s1_squared)) - !!s1)
      in

      let xr = mk (fun () -> !!xq1 + square !!s2 - !!s1_squared) in
      let yr = mk (fun () -> ((!!xp - !!xr) * !!s2) - !!yp) in

      let xq2 = mk (fun () -> (one + ((Endo.base - one) * !!b3)) * !!xt) in
      let yq2 = mk (fun () -> (double !!b4 - one) * !!yt) in
      let s3 = mk (fun () -> (!!yq2 - !!yr) / (!!xq2 - !!xr)) in
      let s3_squared = mk (fun () -> square !!s3) in
      let s4 =
        mk (fun () ->
            (double !!yr / (double !!xr + !!xq2 - !!s3_squared)) - !!s3)
      in

      let xs = mk (fun () -> !!xq2 + square !!s4 - !!s3_squared) in
      let ys = mk (fun () -> ((!!xr - !!xs) * !!s4) - !!yr) in
      acc := (xs, ys) ;
      n_acc :=
        mk (fun () ->
            !!n_acc_prev |> double |> ( + ) !!b1 |> double |> ( + ) !!b2
            |> double |> ( + ) !!b3 |> double |> ( + ) !!b4) ;
      rounds_rev :=
        { Kimchi_backend_common.Endoscale_round.xt
        ; yt
        ; xp
        ; yp
        ; n_acc = n_acc_prev
        ; xr
        ; yr
        ; s1
        ; s3
        ; b1
        ; b2
        ; b3
        ; b4
        }
        :: !rounds_rev
    done ;
    let xs, ys = !acc in
    with_label __LOC__ (fun () ->
        assert_
          [ { annotation = Some __LOC__
            ; basic =
                Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.(
                  T
                    (EC_endoscale
                       { xs
                       ; ys
                       ; n_acc = !n_acc
                       ; state = Array.of_list_rev !rounds_rev
                       }))
            }
          ]) ;
    with_label __LOC__ (fun () -> Field.Assert.equal !n_acc scalar) ;
    !acc

  let endo ?num_bits t s = with_label "endo" (fun () -> endo ?num_bits t s)

  let%test_unit "endo" =
    let module T = Internal_Basic in
    let random_point =
      let rec pt x =
        let y2 = G.Params.(T.Field.(b + (x * (a + (x * x))))) in
        if T.Field.is_square y2 then (x, T.Field.sqrt y2)
        else pt T.Field.(x + one)
      in
      G.Constant.of_affine (pt (T.Field.random ()))
    in
    let n = 128 in
    Quickcheck.test ~trials:10
      (Quickcheck.Generator.list_with_length n Bool.quickcheck_generator)
      ~f:(fun xs ->
        try
          T.Test.test_equal ~equal:G.Constant.equal
            ~sexp_of_t:G.Constant.sexp_of_t
            (Typ.tuple2 G.typ (Typ.list ~length:n Boolean.typ))
            G.typ
            (fun (g, s) ->
              make_checked (fun () -> endo g (SC.create (Field.pack s))))
            (fun (g, s) ->
              let x =
                Constant.to_field (SC.create (Challenge.Constant.of_bits s))
              in
              G.Constant.scale g x)
            (random_point, xs)
        with e ->
          eprintf !"Input %{sexp: bool list}\n%!" xs ;
          raise e)

  let endo_inv ((gx, gy) as g) chal =
    let res =
      exists G.typ
        ~compute:
          As_prover.(
            fun () ->
              let x = Constant.to_field (read typ chal) in
              G.Constant.scale (read G.typ g) Scalar.(one / x))
    in
    let x, y = endo res chal in
    Field.Assert.(equal gx x ; equal gy y) ;
    res
end
