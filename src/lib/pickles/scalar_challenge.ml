open Core_kernel
open Import
module SC = Pickles_types.Scalar_challenge

(* Implementation of the algorithm described on page 29 of the Halo paper
   https://eprint.iacr.org/2019/1021.pdf
*)

let num_bits = 128

(* Has the side effect of checking that [scalar] fits in 128 bits. *)
let to_field_checked (type f)
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = f) ~zero
    ~two ~endo (SC.Scalar_challenge (scalar : Impl.Field.t)) =
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
  let a = ref two in
  let b = ref two in
  let n = ref zero in
  let mk f = exists Field.typ ~compute:f in
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
    n := n8 ;
    a := a8 ;
    b := b8 ;
    ()
  done ;
  Field.Assert.equal !n scalar ;
  Field.(scale !a endo + !b)

(*
let to_field_checked (type f)
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = f) ~endo
    (SC.Scalar_challenge bits) =
  let bits = Array.of_list bits in
  let module F = Impl.Field in
  let two =
    (* Hack for plonk constraints *)
    let x = Impl.exists F.typ ~compute:(fun () -> F.Constant.of_int 2) in
    F.Assert.equal x (F.of_int 2) ;
    x
  in
  let a = ref two in
  let b = ref two in
  let one = F.Constant.one in
  let neg_one = F.Constant.(negate one) in
  let zero = F.Constant.zero in
  for i = (128 / 2) - 1 downto 0 do
    (* s = -1 + 2 * r_2i
       a_next =
        if r_2i1
        then 2 a_prev + s
        else 2 a_prev
       =
       2 a_prev + r_2i1 * s
       =
       2 a_prev + r_2i1 * (-1 + 2 r_2i)
       <->
       0 = 2 a_prev + r_2i1 * (-1 + 2 r_2i) - a_next
       <->
       0 = 2 a_prev - r_2i1 + 2 r_2i1 r_2i - a_next
       <->
       two_a_prev_minus_a_next = 2 a_prev - a_next
       &&
       0 = - r_2i1 + 2 r_2i1 r_2i + two_a_prev_minus_a_next

       b_next =
        if r_2i1
        then 2 b_prev
        else 2 b_prev + s
       =
       2 b_prev + (1 - r_2i1) * s
       =
       2 b_prev + (1 - r_2i1) * (2 * r_2i - 1)
       =
       2 b_prev - 1 + 2 r_2i + r_2i1 - 2 r_2i1 r_2i
       <->
       0 = 2 b_prev - 1 + 2 r_2i + r_2i1 - 2 r_2i1 r_2i - b_next
       <->
       0 = (2 b_prev - b_next) - 1 + 2 r_2i + r_2i1 - 2 r_2i1 r_2i
       <->
       two_b_prev_minus_b_next = 2 b_prev - b_next
       &&
       0
       = two_b_prev_minus_b_next - 1 + 2 r_2i + r_2i1 - 2 r_2i1 r_2i
       = 2 r_2i + r_2i1 - 2 r_2i1 r_2i + two_b_prev_minus_b_next + -1
    *)
    let open Impl in
    let a_next =
      exists Field.typ
        ~compute:
          As_prover.(
            fun () ->
              let s : F.Constant.t =
                if read Boolean.typ bits.(Int.(2 * i)) then F.Constant.one
                else F.Constant.(negate one)
              in
              let a_prev = read_var !a in
              let two_a_prev = F.Constant.(a_prev + a_prev) in
              if read Boolean.typ bits.(Int.((2 * i) + 1)) then
                F.Constant.(two_a_prev + s)
              else two_a_prev)
    in
    let b_next =
      exists Field.typ
        ~compute:
          As_prover.(
            fun () ->
              let s : F.Constant.t =
                if read Boolean.typ bits.(Int.(2 * i)) then F.Constant.one
                else F.Constant.(negate one)
              in
              let b_prev = read_var !b in
              let two_b_prev = F.Constant.(b_prev + b_prev) in
              if read Boolean.typ bits.(Int.((2 * i) + 1)) then two_b_prev
              else F.Constant.(two_b_prev + s))
    in
    let two_a_prev_minus_a_next =
      exists Field.typ
        ~compute:As_prover.(fun () -> read_var F.(!a + !a - a_next))
    in
    let two_b_prev_minus_b_next =
      exists Field.typ
        ~compute:As_prover.(fun () -> read_var F.(!b + !b - b_next))
    in
    let open Zexe_backend_common.Plonk_constraint_system.Plonk_constraint in
    let p l r o m c =
      [ { Snarky_backendless.Constraint.annotation = None
        ; basic = T (Basic { l; r; o; m; c })
        }
      ]
    in
    let two = F.Constant.of_int 2 in
    let r_2i = (bits.(2 * i) :> F.t) in
    let r_2i1 = (bits.((2 * i) + 1) :> F.t) in
    List.iter ~f:assert_
      [ (* 0 = 2 a_prev - a_next - two_a_prev_minus_a_next  *)
        p (two, !a) (neg_one, a_next)
          (neg_one, two_a_prev_minus_a_next)
          zero zero
      ; (* 0 = 2 b_prev - b_next - two_b_prev_minus_b_next  *)
        p (two, !b) (neg_one, b_next)
          (neg_one, two_b_prev_minus_b_next)
          zero zero
        (* 0 = - r_2i1 + 2 r_2i1 r_2i + two_a_prev_minus_a_next *)
      ; p (neg_one, r_2i1) (zero, r_2i) (one, two_a_prev_minus_a_next) two zero
        (* 2 r_2i + r_2i1 - 2 r_2i1 r_2i + two_b_prev_minus_b_next + -1  *)
      ; p (two, r_2i) (one, r_2i1)
          (one, two_b_prev_minus_b_next)
          (F.Constant.negate two) neg_one
      ] ;
    a := a_next ;
    b := b_next
  done ;
  F.(scale !a endo + !b)
   *)

let to_field_constant (type f) ~endo
    (module F : Plonk_checks.Field_intf with type t = f) (SC.Scalar_challenge c)
    =
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
    (module Impl : Snarky_backendless.Snark_intf.Run
      with type prover_state = unit
       and type field = f) ~(endo : f) =
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
                  ~zero:Field.zero ~two:(Field.of_int 2) ~endo
                  (SC.Scalar_challenge (Impl.Field.pack s))))
          (fun s ->
            to_field_constant
              (module Field.Constant)
              ~endo
              (Scalar_challenge (Challenge.Constant.of_bits s)))
          xs
      with e ->
        Core.eprintf !"Input %{sexp: bool list}\n%!" xs ;
        raise e)

module Make
    (Impl : Snarky_backendless.Snark_intf.Run with type prover_state = unit)
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

  let zero =
    lazy
      (let x = exists Field.typ ~compute:(fun () -> Field.Constant.zero) in
       Field.Assert.equal Field.zero x ;
       x)

  let num_bits = 128

  let seal = Util.seal (module Impl)

  let endo t (SC.Scalar_challenge (scalar : Field.t)) =
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
      let p = G.( + ) t (seal (Field.scale xt Endo.base), yt) in
      ref G.(p + p)
    in
    let n_acc = ref (Lazy.force zero) in
    let mk f = exists Field.typ ~compute:f in
    for i = 0 to rows - 1 do
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
            !!(!n_acc) |> double |> ( + ) !!b1 |> double |> ( + ) !!b2 |> double
            |> ( + ) !!b3 |> double |> ( + ) !!b4) ;
      ()
    done ;
    Field.Assert.equal !n_acc scalar ;
    !acc

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
              make_checked (fun () ->
                  endo g (SC.Scalar_challenge (Field.pack s))))
            (fun (g, s) ->
              let x =
                Constant.to_field
                  (Scalar_challenge (Challenge.Constant.of_bits s))
              in
              G.Constant.scale g x)
            (random_point, xs)
        with e ->
          Core.eprintf !"Input %{sexp: bool list}\n%!" xs ;
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
