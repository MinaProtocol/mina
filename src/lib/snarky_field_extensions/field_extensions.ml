open Core_kernel

module Make_test (F : Intf.Basic) = struct
  let test arg_typ gen_arg sexp_of_arg label unchecked checked =
    let open F.Impl in
    let converted x =
      let (), r =
        run_and_check
          (let open Checked.Let_syntax in
          let%bind x = exists arg_typ ~compute:(As_prover.return x) in
          checked x >>| As_prover.read F.typ)
          ()
        |> Or_error.ok_exn
      in
      r
    in
    let open Quickcheck in
    test ~trials:50 gen_arg ~f:(fun x ->
        let r1 = unchecked x in
        let r2 = converted x in
        if not (F.Unchecked.equal r1 r2) then
          failwithf
            !"%s test failure: %{sexp:arg} -> %{sexp:F.Unchecked.t} vs \
              %{sexp:F.Unchecked.t}"
            label x r1 r2 ()
        else () )

  let test1 l f g = test F.typ F.Unchecked.gen F.Unchecked.sexp_of_t l f g

  let test2 l f g =
    let open F in
    test (Impl.Typ.( * ) typ typ)
      (Quickcheck.Generator.tuple2 Unchecked.gen Unchecked.gen)
      [%sexp_of: Unchecked.t * Unchecked.t] l (Tuple2.uncurry f)
      (Tuple2.uncurry g)
end

module Make (F : Intf.Basic) = struct
  open F.Impl
  open Let_syntax
  open F

  let typ = F.typ

  let constant = F.constant

  let scale = F.scale

  let assert_r1cs = F.assert_r1cs

  let equal x y =
    Checked.all
      (List.map2_exn (F.to_list x) (F.to_list y) ~f:Field.Checked.equal)
    >>= Boolean.all

  let assert_equal x y =
    assert_all
      (List.map2_exn
         ~f:(fun x y -> Constraint.equal x y)
         (F.to_list x) (F.to_list y))

  let ( + ) = F.( + )

  let%test_unit "add" =
    let module M = Make_test (F) in
    M.test2 "add" Unchecked.( + ) (fun x y -> return (x + y))

  let ( - ) = F.( - )

  let negate = F.negate

  let zero = constant Unchecked.zero

  let one = constant Unchecked.one

  let div_unsafe x y =
    match (to_constant x, to_constant y) with
    | Some x, Some y ->
        return (constant Unchecked.(x / y))
    | _, _ ->
        let%bind x_over_y =
          exists typ
            ~compute:
              As_prover.(map2 (read typ x) (read typ y) ~f:Unchecked.( / ))
        in
        let%map () = assert_r1cs y x_over_y x in
        x_over_y

  let assert_square =
    match assert_square with
    | `Custom f ->
        f
    | `Define ->
        fun a a2 -> assert_r1cs a a a2

  let ( * ) =
    match ( * ) with
    | `Custom f ->
        f
    | `Define -> (
        fun x y ->
          match (to_constant x, to_constant y) with
          | Some x, Some y ->
              return (constant Unchecked.(x * y))
          | _, _ ->
              let%bind res =
                exists typ
                  ~compute:
                    As_prover.(
                      map2 (read typ x) (read typ y) ~f:Unchecked.( * ))
              in
              let%map () = assert_r1cs x y res in
              res )

  let%test_unit "mul" =
    let module M = Make_test (F) in
    M.test2 "mul" Unchecked.( * ) ( * )

  let square =
    match square with
    | `Custom f ->
        f
    | `Define -> (
        fun x ->
          match to_constant x with
          | Some x ->
              return (constant (Unchecked.square x))
          | None ->
              let%bind res =
                exists typ
                  ~compute:As_prover.(map (read typ x) ~f:Unchecked.square)
              in
              let%map () = assert_square x res in
              res )

  let%test_unit "square" =
    let module M = Make_test (F) in
    M.test1 "square" Unchecked.square square

  let inv_exn =
    match inv_exn with
    | `Custom f ->
        f
    | `Define -> (
        fun t ->
          match to_constant t with
          | Some x ->
              return (constant (Unchecked.inv x))
          | None ->
              let%bind res =
                exists typ
                  ~compute:As_prover.(map (read typ t) ~f:Unchecked.inv)
              in
              let%map () = assert_r1cs t res one in
              res )
end

module Make_applicative
    (F : Intf.S)
    (A : Intf.Traversable_applicative with module Impl := F.Impl) =
struct
  type t = F.t A.t

  type 'a t_ = 'a F.t_ A.t

  let constant = A.map ~f:F.constant

  let to_constant =
    let exception None_exn in
    fun t ->
      try
        Some
          (A.map t ~f:(fun x ->
               match F.to_constant x with
               | Some x ->
                   x
               | None ->
                   raise None_exn ))
      with None_exn -> None

  let if_ b ~then_ ~else_ =
    A.sequence (A.map2 then_ else_ ~f:(fun t e -> F.if_ b ~then_:t ~else_:e))

  let scale t x = A.map t ~f:(fun a -> F.scale a x)

  let scale' t x = A.map t ~f:(fun a -> F.scale x a)

  let negate t = A.map t ~f:F.negate

  let ( + ) = A.map2 ~f:F.( + )

  let ( - ) = A.map2 ~f:F.( - )

  let map_ t ~f = A.map t ~f:(F.map_ ~f)

  let map2_ t1 t2 ~f = A.map2 t1 t2 ~f:(fun x1 x2 -> F.map2_ x1 x2 ~f)
end

module F (Impl : Snarky_backendless.Snark_intf.S) :
  Intf.S with type 'a Base.t_ = 'a and type 'a A.t = 'a and module Impl = Impl =
struct
  module T = struct
    module Unchecked = struct
      include Impl.Field
      module Nat = Snarkette.Nat

      let order = Snarkette.Nat.of_string (Bigint.to_string Impl.Field.size)

      let to_yojson x = `String (to_string x)

      let of_yojson = function
        | `String s ->
            Ok (of_string s)
        | _ ->
            Error "Field.of_yojson: expected string"
    end

    module Impl = Impl
    open Impl

    let map_ t ~f = f t

    let map2_ t1 t2 ~f = f t1 t2

    module Base = struct
      type 'a t_ = 'a

      module Unchecked = struct
        type t = Field.t t_

        let to_yojson x = `String (Field.to_string x)

        let of_yojson = function
          | `String s ->
              Ok (Field.of_string s)
          | _ ->
              Error "Field.of_yojson: expected string"
      end

      type t = Field.Var.t t_

      let map_ = map_
    end

    module A = struct
      type 'a t = 'a

      let map = map_

      let map2 = map2_

      let sequence = Fn.id
    end

    type 'a t_ = 'a

    let to_list x = [x]

    type t = Field.Var.t

    let if_ = Field.Checked.if_

    let typ = Field.typ

    let constant = Field.Var.constant

    let to_constant = Field.Var.to_constant

    let scale = Field.Var.scale

    let mul_field = Field.Checked.mul

    let assert_r1cs a b c = assert_r1cs a b c

    let ( + ) = Field.Checked.( + )

    let ( - ) = Field.Checked.( - )

    let negate t = Field.Var.scale t Unchecked.(negate one)

    let assert_square = `Custom (fun a c -> assert_square a c)

    let ( * ) = `Custom Field.Checked.mul

    let square = `Custom Field.Checked.square

    let inv_exn = `Custom Field.Checked.inv

    let real_part = Fn.id
  end

  include T
  include Make (T)
end

(* Given a field F and s : F (called [non_residue] below)
   such that x^2 - s does not have a root in F, construct
   the field F(sqrt(s)) = F[x] / (x^2 - s) *)
module E2
    (F : Intf.S) (Params : sig
        val non_residue : F.Unchecked.t

        val mul_by_non_residue : F.t -> F.t
    end) : sig
  include
    Intf.S_with_primitive_element
    with module Impl = F.Impl
     and module Base = F
     and type 'a A.t = 'a * 'a

  val unitary_inverse : t -> t
end = struct
  open Params

  module T = struct
    module Base = F
    module Impl = F.Impl
    open Impl
    module Unchecked = Snarkette.Fields.Make_fp2 (F.Unchecked) (Params)

    module A = struct
      type 'a t = 'a * 'a

      let map (x, y) ~f = (f x, f y)

      let map2 (x1, y1) (x2, y2) ~f = (f x1 x2, f y1 y2)

      let sequence (x, y) =
        let%map x = x and y = y in
        (x, y)
    end

    let to_list (x, y) = F.to_list x @ F.to_list y

    (* A value [(a, b) : t] should be thought of as the field element
   a + b sqrt(s). Then all operations are just what follow algebraically. *)

    include Make_applicative (Base) (A)

    let mul_field (a, b) x =
      let%map a = Base.mul_field a x and b = Base.mul_field b x in
      (a, b)

    let typ = Typ.tuple2 F.typ F.typ

    (*
       (a + b sqrt(s))^2
       = a^2 + b^2 s + 2 a b sqrt(s)

       So it is clear that the second coordinate of the below definition is correct. Let's
       examine the first coordinate.

       t - ab - ab sqrt(s)
       = (a + b) (a + s b) - ab - s a b
       = a^2 + a b + s a b + s b^2 - a b - s a b
       = a^2 + s b^2

       so this is correct as well.
    *)
    let square (a, b) =
      let open F in
      let%map ab = a * b and t = (a + b) * (a + mul_by_non_residue b) in
      (t - ab - mul_by_non_residue ab, ab + ab)

    let assert_square (a, b) (a2, b2) =
      let open F in
      let ab = scale b2 Field.(one / of_int 2) in
      let%map () = assert_r1cs a b ab
      and () =
        assert_r1cs (a + b)
          (a + mul_by_non_residue b)
          (a2 + ab + mul_by_non_residue ab)
      in
      ()

    (*
       (a1 + b1 sqrt(s)) (a2 + b2 sqrt(s))
       = (a1 a2 + b1 b2 s) + (a2 b1 + a1 b2) sqrt(s)

       So it is clear that the first coordinate is correct. Let's examine the second
       coordinate.

       t - a1 a2 - b1 b2
       = (a1 + b1) (a2 + b2) - a1 a2 - b1 b2
       = a1 a2 + b2 b2 + a1 b2 + a2 b1 - a1 a2 - b1 b2
       = a1 b2 + a2 b1

       So this is correct as well.
    *)
    let ( * ) (a1, b1) (a2, b2) =
      let open F in
      let%map a = a1 * a2 and b = b1 * b2 and t = (a1 + b1) * (a2 + b2) in
      (a + mul_by_non_residue b, t - a - b)

    let mul_by_primitive_element (a, b) = (mul_by_non_residue b, a)

    let assert_r1cs (a1, b1) (a2, b2) (a3, b3) =
      let open F in
      let%bind b = b1 * b2 in
      let a = a3 - mul_by_non_residue b in
      let%map () = assert_r1cs a1 a2 a
      and () = assert_r1cs (a1 + b1) (a2 + b2) (b3 + a + b) in
      ()

    let square = `Custom square

    let ( * ) = `Custom ( * )

    let inv_exn = `Define

    let assert_square = `Custom assert_square

    let real_part (x, _) = Base.real_part x
  end

  include T
  include Make (T)

  let unitary_inverse (a, b) = (a, Base.negate b)
end

(* Given a prime order field F and s : F (called [non_residue] below)
   such that x^3 - s is irreducible, construct
   the field F(cube_root(s)) = F[x] / (x^3 - s).

   Let S = cube_root(s) in the following.
*)

module T3 = struct
  type 'a t = 'a * 'a * 'a

  let map (x, y, z) ~f = (f x, f y, f z)

  let map2 (x1, y1, z1) (x2, y2, z2) ~f = (f x1 x2, f y1 y2, f z1 z2)
end

module E3
    (F : Intf.S) (Params : sig
        val non_residue : F.Unchecked.t

        val frobenius_coeffs_c1 : F.Unchecked.t array

        val frobenius_coeffs_c2 : F.Unchecked.t array

        val mul_by_non_residue : F.t -> F.t
    end) :
  Intf.S_with_primitive_element
  with module Impl = F.Impl
   and module Base = F
   and type 'a A.t = 'a * 'a * 'a = struct
  module T = struct
    module Base = F
    module Unchecked = Snarkette.Fields.Make_fp3 (F.Unchecked) (Params)
    module Impl = F.Impl
    open Impl

    module A = struct
      include T3

      let sequence (x, y, z) =
        let%map x = x and y = y and z = z in
        (x, y, z)
    end

    let to_list (x, y, z) = F.to_list x @ F.to_list y @ F.to_list z

    include Make_applicative (Base) (A)

    let typ = Typ.tuple3 F.typ F.typ F.typ

    let mul_field (a, b, c) x =
      let%map a = Base.mul_field a x
      and b = Base.mul_field b x
      and c = Base.mul_field c x in
      (a, b, c)

    (*
       (a1 + S b1 + S^2 c1) (a2 + S b2 + S^2 c2)
       = a1 a2 + S a1 b2 + S^2 a1 c2
         + S b1 a2 + S^2 b1 b2 + S^3 b1 c2
         + S^2 c1 a2 + S^3 c1 b2 + S^4 c1 c2
       = a1 a2 + S a1 b2 + S^2 a1 c2
         + S b1 a2 + S^2 b1 b2 + s b1 c2
         + S^2 c1 a2 + s c1 b2 + s S c1 c2
       = (a1 a2 + s b1 c2 + s c1 b2)
       + S (a1 b2 + b1 a2 + s c1 c2)
       + S^2 (a1 c2 + c1 a2 + b1 b2)

       Let us examine the three coordinates in turn.

       First coordinate:
       a + s (t1 - b - c)
       = a1 a2 + s ( (b1 + c1) (b2 + c2) - b - c)
       = a1 a2 + s (b1 c2 + b2 c1)
       which is evidently correct.

       Second coordinate:
       t2 - a - b + s c
       (a1 + b1) (a2 + b2) - a - b + s c
       a1 b2 + b1 a2 + s c
       which is evidently correct.

       Third coordinate:
       t3 - a + b - c
       = (a1 + c1) (a2 + c2) - a + b - c
       = a1 c2 + c1 a2 + b
       which is evidently correct.
    *)
    let ( * ) (a1, b1, c1) (a2, b2, c2) =
      with_label __LOC__
        (let open F in
        let%map a = a1 * a2
        and b = b1 * b2
        and c = c1 * c2
        and t1 = (b1 + c1) * (b2 + c2)
        and t2 = (a1 + b1) * (a2 + b2)
        and t3 = (a1 + c1) * (a2 + c2) in
        ( a + Params.mul_by_non_residue (t1 - b - c)
        , t2 - a - b + Params.mul_by_non_residue c
        , t3 - a + b - c ))

    (*
       (a + S b + S^2 c)^2
       = a^2 + S a b + S^2 a c
       + S a b + S^2 b^2 + S^3 b c
       + S^2 a c + S^3 b c + S^4 c^2
       = a^2 + S a b + S^2 a c
       + S a b + S^2 b^2 + s b c
       + S^2 a c + s b c + S s c^2
       = (a^2 + 2 s b c)
       + S (2 a b + s c^2)
       + S^2 (b^2 + 2 a c)

       Let us examine the three coordinates in turn.

       First coordinate:
       s0 + s s3
       = a^2 + 2 s b c
       which is evidently correct.

       Second coordinate:
       s1 + s s4
       = 2 a b + s c^2
       which is evidently correct.

       Third coordinate:
       s1 + s2 + s3 - s0 - s4
       = 2 a b + (a - b + c)^2 + 2 b c - a^2 - c^2
       = 2 a b + a^2 - 2 a b + 2 a c - 2 b c + b^2 + c^2 + 2 b c - a^2 - c^2
       = 2 a c + b^2
       which is evidently correct.
    *)
    let square (a, b, c) =
      let open F in
      let%map s0 = square a
      and ab = a * b
      and bc = b * c
      and s2 = square (a - b + c)
      and s4 = square c in
      let s1 = ab + ab in
      let s3 = bc + bc in
      ( s0 + Params.mul_by_non_residue s3
      , s1 + Params.mul_by_non_residue s4
      , s1 + s2 + s3 - s0 - s4 )

    let mul_by_primitive_element (a, b, c) = (Params.mul_by_non_residue c, a, b)

    let assert_r1cs (a1, b1, c1) (a2, b2, c2) (a3, b3, c3) =
      with_label __LOC__
        (let open F in
        let%bind b = b1 * b2 and c = c1 * c2 and t1 = (b1 + c1) * (b2 + c2) in
        let a = a3 - Params.mul_by_non_residue (t1 - b - c) in
        let%map () = assert_r1cs a1 a2 a
        and () =
          assert_r1cs (a1 + b1) (a2 + b2)
            (b3 + a + b - Params.mul_by_non_residue c)
        and () = assert_r1cs (a1 + c1) (a2 + c2) (c3 + a - b + c) in
        ())

    let square = `Custom square

    let ( * ) = `Custom ( * )

    let inv_exn = `Define

    let assert_square = `Define

    let real_part (a, _, _) = F.real_part a
  end

  include T
  include Make (T)
end

module F3
    (F : Intf.S with type 'a A.t = 'a and type 'a Base.t_ = 'a) (Params : sig
        val non_residue : F.Unchecked.t

        val frobenius_coeffs_c1 : F.Unchecked.t array

        val frobenius_coeffs_c2 : F.Unchecked.t array
    end) :
  Intf.S_with_primitive_element
  with module Impl = F.Impl
   and module Base = F
   and type 'a A.t = 'a * 'a * 'a = struct
  module T = struct
    module Base = F
    module Unchecked = Snarkette.Fields.Make_fp3 (F.Unchecked) (Params)
    module Impl = F.Impl
    open Impl

    let mul_by_primitive_element (a, b, c) =
      (F.scale c Params.non_residue, a, b)

    module A = struct
      include T3

      let sequence (x, y, z) =
        let%map x = x and y = y and z = z in
        (x, y, z)
    end

    let to_list (x, y, z) = [x; y; z]

    include Make_applicative (Base) (A)

    let typ = Typ.tuple3 F.typ F.typ F.typ

    let mul_field (a, b, c) x =
      let%map a = Base.mul_field a x
      and b = Base.mul_field b x
      and c = Base.mul_field c x in
      (a, b, c)

    let assert_r1cs (a0, a1, a2) (b0, b1, b2) (c0, c1, c2) =
      let open F in
      let%bind v0 = a0 * b0 and v4 = a2 * b2 in
      let beta = Params.non_residue in
      let beta_inv = F.Unchecked.inv beta in
      let%map () =
        assert_r1cs
          (a0 + a1 + a2)
          (b0 + b1 + b2)
          ( c1 + c2 + F.scale c0 beta_inv
          + F.(scale v0 Unchecked.(one - beta_inv))
          + F.(scale v4 Unchecked.(one - beta)) )
      and () =
        assert_r1cs
          (a0 - a1 + a2)
          (b0 - b1 + b2)
          ( c2 - c1
          + F.(scale v0 Unchecked.(one + beta_inv))
          - F.scale c0 beta_inv
          + F.(scale v4 Unchecked.(one + beta)) )
      and () =
        let two = Impl.Field.of_int 2 in
        let four = Impl.Field.of_int 4 in
        let sixteen = Impl.Field.of_int 16 in
        let eight_beta_inv = Impl.Field.(mul (of_int 8) beta_inv) in
        assert_r1cs
          (a0 + F.scale a1 two + F.scale a2 four)
          (b0 + F.scale b1 two + F.scale b2 four)
          ( F.scale c1 two + F.scale c2 four + F.scale c0 eight_beta_inv
          + F.(scale v0 Unchecked.(one - eight_beta_inv))
          + F.(scale v4 Unchecked.(sixteen - (beta + beta))) )
      in
      ()

    let ( * ) = `Define

    let inv_exn = `Define

    let square = `Define

    let assert_square = `Define

    let real_part (a, _, _) = F.real_part a
  end

  include T
  include Make (T)
end

module Cyclotomic_square = struct
  module Make_F4 (F2 : Intf.S_with_primitive_element) = struct
    let cyclotomic_square (c0, c1) =
      let open F2 in
      let open Impl in
      let%map b_squared = square (c0 + c1) and a = square c1 in
      let c = b_squared - a in
      let d = mul_by_primitive_element a in
      let e = c - d in
      let f = scale d (Field.of_int 2) + one in
      let g = e - one in
      (f, g)
  end

  module Make_F6
      (F2 : Intf.S_with_primitive_element
            with type 'a A.t = 'a * 'a
             and type 'a Base.t_ = 'a) (Params : sig
          val cubic_non_residue : F2.Impl.Field.t
      end) =
  struct
    let cyclotomic_square ((x00, x01, x02), (x10, x11, x12)) =
      let open F2.Impl in
      let ((a0, a1) as a) = (x00, x11) in
      let ((b0, b1) as b) = (x10, x02) in
      let ((c0, c1) as c) = (x01, x12) in
      let%map asq0, asq1 = F2.square a
      and bsq0, bsq1 = F2.square b
      and csq0, csq1 = F2.square c in
      let fpos x y =
        Field.(Var.(add (scale x (of_int 3)) (scale y (of_int 2))))
      in
      let fneg x y =
        Field.(Var.(sub (scale x (of_int 3)) (scale y (of_int 2))))
      in
      ( (fneg asq0 a0, fneg bsq0 c0, fneg csq0 b1)
      , ( fpos (Field.Var.scale csq1 Params.cubic_non_residue) b0
        , fpos asq1 a1
        , fpos bsq1 c1 ) )
  end
end

module F6
    (Fq : Intf.S with type 'a A.t = 'a and type 'a Base.t_ = 'a)
    (Fq2 : Intf.S_with_primitive_element
           with module Impl = Fq.Impl
            and type 'a A.t = 'a * 'a
            and type 'a Base.t_ = 'a Fq.t_) (Fq3 : sig
        include
          Intf.S_with_primitive_element
          with module Impl = Fq.Impl
           and type 'a A.t = 'a * 'a * 'a
           and type 'a Base.t_ = 'a Fq.t_

        module Params : sig
          val non_residue : Fq.Unchecked.t

          val frobenius_coeffs_c1 : Fq.Unchecked.t array

          val frobenius_coeffs_c2 : Fq.Unchecked.t array
        end
    end) (Params : sig
      val frobenius_coeffs_c1 : Fq.Unchecked.t array
    end) =
struct
  include E2
            (Fq3)
            (struct
              let non_residue : Fq3.Unchecked.t =
                Fq.Unchecked.(zero, one, zero)

              let mul_by_non_residue = Fq3.mul_by_primitive_element
            end)

  let fq_mul_by_non_residue x = Fq.scale x Fq3.Params.non_residue

  let special_mul (a0, a1) (b0, b1) =
    let open Impl in
    let%bind v1 = Fq3.(a1 * b1) in
    let%bind v0 =
      let a00, a01, a02 = a0 in
      let _, _, b02 = b0 in
      let%map a00b02 = Fq.(a00 * b02)
      and a01b02 = Fq.(a01 * b02)
      and a02b02 = Fq.(a02 * b02) in
      (fq_mul_by_non_residue a01b02, fq_mul_by_non_residue a02b02, a00b02)
    in
    let beta_v1 = Fq3.mul_by_primitive_element v1 in
    let%map t = Fq3.((a0 + a1) * (b0 + b1)) in
    Fq3.(v0 + beta_v1, t - v0 - v1)

  let assert_special_mul ((((a00, a01, a02) as a0), a1) : t)
      ((((_, _, b02) as b0), b1) : t) ((c00, c01, c02), c1) =
    let open Impl in
    let%bind ((v10, v11, v12) as v1) = Fq3.(a1 * b1) in
    let%bind v0 =
      exists Fq3.typ
        ~compute:
          As_prover.(
            map2 ~f:Fq3.Unchecked.( * ) (read Fq3.typ a0) (read Fq3.typ b0))
      (* v0
          = (a00 + s a01 s^2 a02) (s^2 b02)
        = non_residue a01 b02 + non_residue s a02 b02 + s^2 a00 b02 *)
    in
    let%map () =
      let%map () =
        Fq.assert_r1cs a01
          (Fq.scale b02 Fq3.Params.non_residue)
          (Field.Var.linear_combination
             [(Field.one, c00); (Field.negate Fq3.Params.non_residue, v12)])
      and () =
        Fq.assert_r1cs a02 (Fq.scale b02 Fq3.Params.non_residue) Fq.(c01 - v10)
      and () = Fq.assert_r1cs a00 b02 Fq.(c02 - v11) in
      ()
    and () = Fq3.assert_r1cs Fq3.(a0 + a1) Fq3.(b0 + b1) Fq3.(c1 + v0 + v1) in
    ()

  let special_div_unsafe a b =
    let open Impl in
    let%bind result =
      exists typ
        ~compute:As_prover.(map2 ~f:Unchecked.( / ) (read typ a) (read typ b))
    in
    (* result * b = a *)
    let%map () = assert_special_mul result b a in
    result

  (* TODO: Make sure this is ok *)
  let special_div = special_div_unsafe

  include Cyclotomic_square.Make_F6
            (Fq2)
            (struct
              let cubic_non_residue = Fq3.Params.non_residue
            end)

  let frobenius ((c00, c01, c02), (c10, c11, c12)) power =
    let module Field = Impl.Field in
    let p3 = power mod 3 in
    let p6 = power mod 6 in
    let ( * ) s x = Field.Var.scale x s in
    ( ( c00
      , Fq3.Params.frobenius_coeffs_c1.(p3) * c01
      , Fq3.Params.frobenius_coeffs_c2.(p3) * c02 )
    , ( Params.frobenius_coeffs_c1.(p6) * c10
      , Field.mul
          Params.frobenius_coeffs_c1.(p6)
          Fq3.Params.frobenius_coeffs_c1.(p3)
        * c11
      , Field.mul
          Params.frobenius_coeffs_c1.(p6)
          Fq3.Params.frobenius_coeffs_c2.(p3)
        * c12 ) )
end

module F4
    (Fq2 : Intf.S_with_primitive_element
           with type 'a A.t = 'a * 'a
            and type 'a Base.t_ = 'a) (Params : sig
        val frobenius_coeffs_c1 : Fq2.Impl.Field.t array
    end) =
struct
  include E2
            (Fq2)
            (struct
              let non_residue = Fq2.Impl.Field.(zero, one)

              let mul_by_non_residue = Fq2.mul_by_primitive_element
            end)

  let special_mul = ( * )

  (* TODO: Make sure this is ok *)
  let special_div = div_unsafe

  include Cyclotomic_square.Make_F4 (Fq2)

  let frobenius ((c00, c01), (c10, c11)) power =
    let module Field = Impl.Field in
    let p2 = Params.frobenius_coeffs_c1.(Int.( * ) (power mod 2) 2) in
    let p4 = Params.frobenius_coeffs_c1.(power mod 4) in
    let ( * ) s x = Field.Var.scale x s in
    ((c00, p2 * c01), (p4 * c10, Field.(p4 * p2) * c11))
end
