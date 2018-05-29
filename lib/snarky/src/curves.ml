open Core_kernel
open Util

module type Params_intf = sig
  type field
  val generator : field * field
  module Coefficients : sig
    val a : field
    val b : field
  end
end

module type Scalar_intf = sig
  type (_, _) typ 
  type (_, _) checked
  type boolean_var
  type var
  type value
  val length : int
  val typ : (var, value) typ
  val assert_equal : var -> var -> (unit, _) checked
  val equal : var -> var -> (boolean_var, _) checked
  val test_bit : value -> int -> bool
end

module Make_intf (Impl : Snark_intf.S) = struct
  open Impl

  module type S = sig
    include Params_intf with type field := Field.t

    module Scalar : Scalar_intf
      with type ('a, 'b) typ := ('a, 'b) Typ.t
       and type ('a, 'b) checked := ('a, 'b) Checked.t
       and type boolean_var := Boolean.var

    type 'a t = 'a * 'a

    type var = Cvar.t t
    type value = Field.t t

    val value_to_var : value -> var

    val typ : (var, value) Typ.t

    val add : value -> value -> value
    val double : value -> value

    val equal : value -> value -> bool

    module Checked : sig
      val identity : var
      val generator : var

      val if_ : Boolean.var -> then_:var -> else_:var -> (var, _) Checked.t

      val assert_equal : var -> var -> (unit, _) Checked.t
      val assert_on_curve : var -> (unit, _) Checked.t
      val add : var -> var -> (var, _) Checked.t
      val double : var -> (var, _) Checked.t

      val scale_bits : var -> Scalar.var -> init:var -> (var, _) Checked.t
      val multi_sum : (Scalar.var * var) list -> init:var -> (var, _) Checked.t
    end
  end
end

module Edwards = struct
  module type Params_intf = sig
    type field
    val d : field
    val cofactor : Bignum.Bigint.t
    val generator : field * field
    val order : Bignum.Bigint.t
  end

  module Basic = struct
    module type S = sig
      type field

      type t = field * field

      module Params : Params_intf with type field := field

      val generator : t
      val identity  : t
      val add       : t -> t -> t
      val double    : t -> t

      val equal : t -> t -> bool

      val find_y : field -> field option
    end

    module Make
      (Field : Field_intf.Extended)
      (Params : Params_intf with type field := Field.t)
    : S with type field := Field.t
         and module Params = Params
    =
    struct
      open Field

      module Params = Params

      type t = Field.t * Field.t

      (* x^2 + y^2 = 1 + dx^2 y^2 *)

      let generator : t = Params.generator

      let identity : t = (Field.zero, Field.one)

      let equal (x1, y1) (x2, y2) = Field.equal x1 x2 && Field.equal y1 y2

      (* (x^2 - 1)/(d x^2 - 1) = y^2 *)
      let find_y x =
        let xx = Field.square x in
        let yy = Field.Infix.((xx - one) / (Params.d * xx - one)) in
        if Field.is_square yy
        then Some (sqrt yy)
        else None
      ;;

      let add (x1, y1) (x2, y2) =
        let open Field.Infix in
        let x1x2 = x1 * x2 in
        let y1y2 = y1 * y2 in
        let x1y2 = x1 * y2 in
        let y1x2 = y1 * x2 in
        let c = Params.d * x1x2 * y1y2 in
        ((x1y2 + y1x2) / (Field.one + c), (y1y2 - x1x2)/(Field.one - c))
      ;;

      let double (x, y) =
        let open Field.Infix in
        let xy = x * y in
        let xx = x * x in
        let yy = y * y in
        let two = Field.of_int 2 in
        ((two * xy)/(xx + yy), (yy - xx)/(two - xx - yy))
      ;;
    end
  end

  module type S = sig
    type (_, _) checked
    type (_, _) typ

    type boolean_var
    type field

    include Basic.S with type field := field

    module Scalar : Scalar_intf
      with type ('a, 'b) checked := ('a, 'b) checked
       and type ('a, 'b) typ := ('a, 'b) typ
       and type boolean_var := boolean_var

    type var
    type value = t

    val typ : (var, value) typ
    val add : value -> value -> value

    val equal : value -> value -> bool

    val identity : value
    val generator : value

    val scale : value -> Scalar.value -> value

    val is_on_subgroup : value -> bool

    module Checked : sig
      val generator : var
      val identity : var

      val add : var -> var -> (var, _) checked

      val if_ : boolean_var -> then_:var -> else_:var -> (var, _) checked

      val cond_add : value -> to_:var -> if_:boolean_var -> (var, _) checked

      module Assert : sig
        val equal : var -> var -> (unit, _) checked
        val on_curve : var -> (unit, _) checked
        val on_subgroup : var -> (unit, _) checked
      end

      val scale : var -> Scalar.var -> (var, _) checked
      val scale_known : value -> Scalar.var -> (var, _) checked
      val scale_known_scalar : var -> Scalar.value -> num_bits:int -> (var, _) checked
    end
  end

  module Extend
      (Impl : Snark_intf.S)
      (Scalar : Scalar_intf
       with type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
        and type ('a, 'b) typ := ('a, 'b) Impl.Typ.t
        and type value = Bignum.Bigint.t
        and type boolean_var := Impl.Boolean.var
        and type var = Impl.Boolean.var list)
      (Basic : Basic.S with type field := Impl.Field.t)
    : S with type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
         and type ('a, 'b) typ := ('a, 'b) Impl.Typ.t
         and type boolean_var := Impl.Boolean.var
         and type field := Impl.Field.t
         and type var = Impl.Cvar.t * Impl.Cvar.t
         and type value = Impl.Field.t * Impl.Field.t
         and module Scalar = Scalar
  =
  struct
    open Impl

    include Basic

    module Scalar = Scalar

    type 'a tup = 'a * 'a
    type var = Cvar.t tup
    type value = Field.t tup

    let var_of_value (x, y) = (Cvar.constant x, Cvar.constant y)

    let identity_value = identity

    let () = assert (not (Field.is_square Params.d))

    (* Someday: This is pretty inefficient *)
    let scale_unchecked x s ~num_bits =
      let rec go i two_to_the_i_x acc =
        if i >= num_bits
        then acc
        else 
          let acc' =
            if Scalar.test_bit s i
            then add acc two_to_the_i_x
            else acc
          in
          go (i + 1) (add two_to_the_i_x two_to_the_i_x) acc'
      in
      go 0 x identity_value

    let scale = scale_unchecked ~num_bits:Scalar.length

    let typ_unchecked : (var, value) Typ.t = Typ.(tuple2 field field)

    let double_value = double

    let cofactor_inverse_mod_subgroup_order =
      let (gcd, x, y) = euclid Params.cofactor Params.order in
      assert Bignum.Bigint.(gcd = one);
      assert Bignum.Bigint.(one = x * Params.cofactor + y * Params.order);
      let x = Bignum.Bigint.(x % Params.order) in
      assert (Bignum.Bigint.is_non_negative x);
      assert Bignum.Bigint.(x * Params.cofactor % Params.order = one);
      x

    let is_on_subgroup =
      (*
         Let [G] be the entire group of rational points of this curve.
         We have [G = H * < g >] (where [g = Params.generator] is an
         element of prime order [p = Params.order] and [|H| = Params.cofactor].

         Let [c = Params.cofactor] and [d = 1 / c mod p] (i.e., [d = cofactor_inverse_mod_subgroup_order]).
         This means that [cd = kp + 1] for some [k].

         Let's see how to check if [x : G] is in [< g >].
         By the above we have [x = h g^r] for some [h : H] and [r].
         Let [y = x^{cd}]. We have

         y
         = x^{cd}
         = h^{cd} g^{r * cd}
         = (h^c)^d (g^{cd})^r
         = 1^d (g^{kp + 1})^r
         = (g^{kp} g)^r
         = g^r

         (Here we use the fact that [h] has order dividing [c] and [g] has order [p].)
         Thus we have [x : < g >] iff [h = 1] iff [x = y].
      *)
      let s = Bignum.Bigint.(Params.cofactor * cofactor_inverse_mod_subgroup_order) in
      let num_bits = bigint_num_bits s in
      fun x -> equal x (scale_unchecked ~num_bits x s)


    (* TODO: Come up with a way to test off subgroup points as well. *)
    let%test_unit "on_subgroup" =
      let subgroup_pt =
        let open Quickcheck.Generator in
        Bignum.Bigint.(gen_incl zero Params.order) >>| fun s ->
        scale generator s
      in
      Quickcheck.test subgroup_pt ~f:(fun x -> assert (is_on_subgroup x))

    module Checked = struct
      open Let_syntax

      let identity = var_of_value identity_value
      let generator = var_of_value generator

      (* TODO: Optimize -- could probably shave off one constraint. *)
      let add (x1, y1) (x2, y2) =
        with_label "Edwards.Checked.add" begin
          let%bind x1x2 = Checked.mul x1 x2
          and y1y2      = Checked.mul y1 y2
          and x1y2      = Checked.mul x1 y2
          and x2y1      = Checked.mul x2 y1
          in
          let%bind p = Checked.mul x1x2 y1y2 in
          let open Cvar.Infix in
          let p     = Params.d * p in
          let%map a = Checked.div (x1y2 + x2y1) (Cvar.constant Field.one + p)
          and b     = Checked.div (y1y2 - x1x2) (Cvar.constant Field.one - p)
          in
          (a, b)
        end
      ;;

      let double (x, y) =
        with_label "Edwards.Checked.double" begin
          let%bind xy = Checked.mul x y
          and xx = Checked.mul x x
          and yy = Checked.mul y y
          in
          let open Cvar.Infix in
          let two = Field.of_int 2 in
          let%map a = Checked.div (two * xy) (xx + yy)
          and b = Checked.div (yy - xx) (Cvar.constant two - xx - yy)
          in
          (a, b)
        end
      ;;

      (* TODO-someday: Make it so this doesn't have to compute both branches *)
      let if_ =
        let to_list (x, y) = [x; y] in
        let rev_map3i_exn xs ys zs ~f =
          let rec go i acc xs ys zs =
            match xs, ys, zs with
            | x :: xs, y :: ys, z :: zs -> go (i + 1) (f i x y z :: acc) xs ys zs
            | [], [], [] -> acc
            | _ -> failwith "rev_map3i_exn"
          in
          go 0 [] xs ys zs
        in
        fun b ~then_ ~else_ ->
          with_label "Edwards.Checked.if_" begin
            let%bind r =
              provide_witness typ_unchecked As_prover.(Let_syntax.(
                let%bind b = read Boolean.typ b in
                read typ_unchecked (if b then then_ else else_)))
            in
          (*     r - e = b (t - e) *)
            let%map () =
              rev_map3i_exn (to_list r) (to_list then_) (to_list else_) ~f:(fun i r t e ->
                let open Cvar.Infix in
                Constraint.r1cs ~label:(sprintf "main_%d" i)
                  (b :> Cvar.t)
                  (t - e)
                  (r - e)
              )
              |> assert_all
            in
            r
          end
      ;;

      let scale t (c : Scalar.var) =
        with_label "Edwards.Checked.scale" begin
          let rec go i acc pt = function
            | [] -> return acc
            | b :: bs ->
              let%bind acc' =
                with_label (sprintf "acc_%d" i) begin
                  let%bind add_pt = add acc pt in
                  let don't_add_pt = acc in
                  if_ b ~then_:add_pt ~else_:don't_add_pt
                end
              and pt' = double pt
              in
              go (i + 1) acc' pt' bs
          in
          match c with
          | [] -> failwith "Edwards.Checked.scale: Empty bits"
          | b :: bs ->
            let%bind acc = if_ b ~then_:t ~else_:identity
            and pt = double t
            in
            go 1 acc pt bs
        end
      ;;

      let scale_known_scalar t (c : Scalar.value) ~num_bits =
        with_label "Edwards.Checked.scale_known_scalar" begin
          let rec go i acc pt =
            if i >= num_bits
            then return acc
            else
              let%bind acc' =
                if Scalar.test_bit c i
                then add acc pt
                else return acc
              and pt' = double pt
              in
              go (i + 1) acc' pt'
          in
          if num_bits = 0
          then failwith "Edwards.Checked.scale_known_scalar: Empty bits"
          else
            let b = Scalar.test_bit c 0 in
            let acc = if b then t else identity in
            let%bind pt = double t in
            go 1 acc pt
        end

      let gen =
        let open Quickcheck.Generator in
        let open Let_syntax in
        let field =
          let%map x = Bignum.Bigint.(gen_incl zero Field.size) in
          Bigint.(to_field (of_bignum_bigint x))
        in
        filter_map field ~f:(fun x ->
          Option.map (find_y x) ~f:(fun y ->
            let%map b = Bool.gen in
            if b then (x, y) else (x, Field.negate y)))
        |> join

      let%test_unit "scale-known-scalar" =
        let module T = Test_util.Make(Impl) in
        let open Quickcheck in
        let gen =
          Generator.tuple3
            gen
            Bignum.Bigint.(gen_incl zero Params.order)
            (Int.gen_incl 1 (bigint_num_bits Params.order))
        in
        Quickcheck.test gen ~f:(fun (pt, s, num_bits) ->
          T.test_equal ~equal typ_unchecked typ_unchecked
            (fun pt -> scale_known_scalar pt ~num_bits s)
            (fun pt -> scale_unchecked pt ~num_bits s)
            pt)

      (* TODO: Unit test *)
      let cond_add ((x2, y2) : value) ~to_:((x1, y1) : var) ~if_:(b : Boolean.var) : (var, _) Checked.t =
        with_label "Edwards.Checked.cond_add" begin
          let one = Cvar.constant Field.one in
          let b   = (b :> Cvar.t) in
          let open Let_syntax in
          let open Cvar.Infix in
          let res a1 a3 =
            let%bind a =
              provide_witness Typ.field begin
                let open As_prover in
                let open As_prover.Let_syntax in
                let open Field.Infix in
                let%map b = read_var b
                and a3 = read_var a3
                and a1 = read_var a1 in
                a1 + b * (a3 - a1)
              end
            in
            let%map () = assert_r1cs b (a3 - a1) (a - a1) in
            a
          in
          let%bind beta = Checked.mul x1 y1 in
          let p         = Field.Infix.(Params.d * x2 * y2) * beta in
          let%bind x3   = Checked.div (y2 * x1 + x2 * y1) (one + p)
          and y3        = Checked.div (y2 * y1 - x2 * x1) (one - p) in
          let%map x_res = res x1 x3
          and y_res = res y1 y3
          in
          (x_res, y_res)
        end
      ;;

      let scale_known (t : value) (c : Scalar.var) =
        let label = "Edwards.Checked.scale_known" in
        with_label label begin
          let rec go i acc pt = function
            | b :: bs ->
                let%bind acc' =
                  with_label (sprintf "acc_%d" i) begin
                    cond_add pt ~to_:acc ~if_:b
                  end
                in
                go (i + 1) acc' (double_value pt) bs
            | [] -> return acc
          in
          match c with
          | [] -> failwithf "%s: Empty bits" label ()
          | b :: bs ->
            let acc =
              let b = (b :> Cvar.t) in
              let (x_id, y_id) = identity_value in
              let (x_t, y_t) = t in
              let open Cvar.Infix in
              ( Field.Infix.(x_t - x_id) * b + Cvar.constant x_id,
                Field.Infix.(y_t - y_id) * b + Cvar.constant y_id )
            in
            go 1 acc (double_value t) bs
        end
      ;;

      module Assert = struct
        let on_curve (x, y) =
          let open Let_syntax in
          let%bind x2 = Checked.mul x x
          and y2      = Checked.mul y y in
          let open Cvar.Infix in
          assert_r1cs
            (Params.d * x2)
            y2
            (x2 + y2 - Cvar.constant Field.one)

        let equal (x1, y1) (x2, y2) =
          let%map () = assert_equal x1 x2
          and () = assert_equal y1 y2 in
          ()

        let not_identity =
          assert (not (Field.(equal Params.d one)));
          (* Let (x, y) be a point on the curve.
             Claim:
             To check if (x, y) is not the identity it is sufficient to check y != 1.
             This is essentially because y = 1 implies x = 0 (which implies (x, y) is the identity).

             First, it is clear that if y != 1, then (x, y) is not the identity since
             the identity is (0, 1).

             Conversely suppose (x, y) is not the identity. This means either x != 0 or y != 1.
             If y != 1, we're done. Otherwise x != 0 and y = 1. (x, y) is on the curve so we have

             x^2 + y^2 = 1 + dx^2 y^2
             x^2 + 1 = 1 + dx^2
             x^2 = dx^2

             Which implies x = 0 since d != 1. This is in contradiction to x != 0, so in fact
             we must have y != 1. *)
          fun (x, y) ->
            Checked.Assert.not_equal y (Cvar.constant Field.one)

        let typ_on_curve : (var, value) Typ.t =
          { typ_unchecked with check = on_curve }

        let cofactor_inverse_num_bits = bigint_num_bits cofactor_inverse_mod_subgroup_order

        let cofactor_num_bits = bigint_num_bits Params.cofactor

        let move_to_subgroup pt =
          scale_known_scalar pt Params.cofactor ~num_bits:cofactor_num_bits

        let on_subgroup =
          fun pt ->
            let%bind on_curve_preimage =
              provide_witness typ_on_curve As_prover.(
                map (read typ_unchecked pt) ~f:(fun t ->
                  scale_unchecked ~num_bits:cofactor_inverse_num_bits
                    t cofactor_inverse_mod_subgroup_order))
            in
            move_to_subgroup on_curve_preimage >>= equal pt
      end
    end

    let typ : (var, value) Typ.t =
      { typ_unchecked with check = Checked.Assert.on_subgroup }
  end

  module Make
      (Impl : Snark_intf.S)
      (Scalar : sig
        type var = Impl.Boolean.var list
        type value = Bignum.Bigint.t
        val test_bit : value -> int -> bool
        val length : int
        val typ : (var, value) Impl.Typ.t
        val equal : var -> var -> (Impl.Boolean.var, _) Impl.Checked.t
        val assert_equal : var -> var -> (unit, _) Impl.Checked.t
      end)
      (Params : Params_intf with type field := Impl.Field.t)
    : S
      with type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
        and type Scalar.value = Scalar.value
        and type ('a, 'b) typ := ('a, 'b) Impl.Typ.t
        and type boolean_var := Impl.Boolean.var
        and type field := Impl.Field.t
        and type var = Impl.Cvar.t * Impl.Cvar.t
        and type value = Impl.Field.t * Impl.Field.t
    =
    Extend(Impl)(Scalar)(Basic.Make(Impl.Field)(Params))
end

module Make
    (Impl : Snark_intf.S)
    (Params : Params_intf with type field := Impl.Field.t)
    (Scalar : sig
      type var = Impl.Boolean.var list
      type value
      val length : int
      val typ : (var, value) Impl.Typ.t
    end)
= struct
open Impl

type 'a t = 'a * 'a
type var = Cvar.t t
type value = Field.t t

(* TODO: Check if point is on curve! *)
let typ : (var, value) Typ.t = Typ.(tuple2 field field)

include Params

module Scalar = struct
  include Scalar

  let assert_equal = Checked.Assert.equal_bitstrings
end

let value_to_var ((x, y) : value) : var =
  Cvar.(constant x, constant y)
;;

let add (ax, ay) (bx, by) =
  let lambda = Field.(Infix.((by - ay) * inv (bx - ax))) in
  let cx = Field.Infix.(lambda * lambda - (ax + bx)) in
  let cy = Field.Infix.(lambda * (ax - cx) - ay) in
  (cx, cy)
;;

let equal ((x1, y1) : value) ((x2, y2) : value) =
  Field.equal x1 x2 && Field.equal y1 y2

let double (ax, ay) =
  if Field.(equal ay zero) then failwith "Curve.double: y = 0";
  let x_squared = Field.square ax in
  let lambda = Field.(Infix.( (of_int 3 * x_squared + Coefficients.a) * inv (of_int 2 * ay))) in
  let bx = Field.(Infix.(square lambda - of_int 2 * ax)) in
  let by = Field.Infix.(lambda * (ax - bx) - ay) in
  (bx, by)
;;

module Checked = struct
  let generator = value_to_var generator

  let assert_equal (x1, y1) (x2, y2) =
    assert_all
      [ Constraint.equal x1 x2; Constraint.equal y1 y2 ]
  ;;

  let assert_on_curve (x, y) =
    with_label "Curve.assert_on_curve" begin
      let open Let_syntax in
      let%bind x_squared = Checked.mul x x in
      let%bind y_squared = Checked.mul y y in
      let open Cvar.Infix in
      assert_r1cs ~label:"main"
        x
        (x_squared + Cvar.constant Coefficients.a)
        (y_squared - Cvar.constant Coefficients.b)
    end
  ;;

  let add (ax, ay) (bx, by) =
    with_label "Curve.add" begin
      let open Let_syntax in
      let%bind denom = Checked.inv Cvar.Infix.(bx - ax) in
      let%bind lambda = Checked.mul Cvar.Infix.(by - ay) denom in
      let%bind cx =
        provide_witness Typ.field begin
          let open As_prover in let open Let_syntax in
          let%map ax = read_var ax
          and bx = read_var bx
          and lambda = read_var lambda
          in
          Field.(sub (square lambda) (add ax bx))
        end
      in
      let%bind () =
        assert_r1cs ~label:"c1"
          lambda lambda
          Cvar.Infix.(cx + ax + bx)
      in
      let%bind cy =
        provide_witness Typ.field begin
          let open As_prover in let open Let_syntax in
          let%map ax = read_var ax
          and ay = read_var ay
          and cx = read_var cx
          and lambda = read_var lambda
          in
          Field.(sub (mul lambda (sub ax cx)) ay)
        end
      in
      let%map () =
        let open Cvar.Infix in
        assert_r1cs ~label:"c2"
          lambda (ax - cx) (cy + ay)
      in
      (cx, cy)
    end
  ;;

  let double (ax, ay) =
    with_label "Curve.double" begin
      let open Let_syntax in
      let%bind x_squared = Checked.mul ax ax in
      let%bind lambda =
        provide_witness Typ.field begin
          let open As_prover in
          map2 (read_var x_squared) (read_var ay) ~f:(fun x_squared ay ->
            Field.(Infix.((of_int 3 * x_squared + Coefficients.a) * inv (of_int 2 * ay))))
        end
      in
      let%bind bx =
        provide_witness Typ.field begin
          let open As_prover in
          map2 (read_var lambda) (read_var ax) ~f:(fun lambda ax ->
            Field.(Infix.(square lambda - of_int 2 * ax)))
        end
      in
      let%bind by =
        provide_witness Typ.field begin
          let open As_prover in let open Let_syntax in
          let%map lambda = read_var lambda
          and ax = read_var ax
          and ay = read_var ay
          and bx = read_var bx
          in
          Field.Infix.(lambda * (ax - bx) - ay)
        end
      in
      let two = Field.of_int 2 in
      let open Cvar.Infix in
      let%map () =
        assert_r1cs
          (two * lambda)
          ay
          (Field.of_int 3 * x_squared + Cvar.constant Coefficients.a)
      and () =
        assert_r1cs lambda lambda (bx + two * ax)
      and () =
        assert_r1cs lambda (ax - bx) (by + ay)
      in
      (bx, by)
    end
  ;;

  (* TODO-someday: Make it so this doesn't have to compute both branches *)
  let if_ =
    let to_list (x, y) = [x; y] in
    let rev_map3i_exn xs ys zs ~f =
      let rec go i acc xs ys zs =
        match xs, ys, zs with
        | x :: xs, y :: ys, z :: zs -> go (i + 1) (f i x y z :: acc) xs ys zs
        | [], [], [] -> acc
        | _ -> failwith "rev_map3i_exn"
      in
      go 0 [] xs ys zs
    in
    fun b ~then_ ~else_ ->
      let open Let_syntax in
      let%bind r =
        provide_witness typ As_prover.(Let_syntax.(
          let%bind b = read Boolean.typ b in
          read typ (if b then then_ else else_)))
      in
    (*     r - e = b (t - e) *)
      let%map () =
        rev_map3i_exn (to_list r) (to_list then_) (to_list else_) ~f:(fun i r t e ->
          let open Cvar.Infix in
          Constraint.r1cs ~label:(sprintf "main_%d" i)
            (b :> Cvar.t)
            (t - e)
            (r - e)
        )
        |> assert_all
      in
      r
  ;;


  let scale_bits t (c : Boolean.var list) ~init =
    with_label "Curve.scale_bits" begin
      let open Let_syntax in
      let rec go i bs0 acc pt =
        match bs0 with
        | [] -> return acc
        | b :: bs ->
          let%bind acc' =
            with_label (sprintf "acc_%d" i) begin
              let%bind add_pt = add acc pt in
              let don't_add_pt = acc in
              if_ b ~then_:add_pt ~else_:don't_add_pt
            end
          and pt' = double pt
          in
          go (i + 1) bs acc' pt'
      in
      go 0 c init t
    end
  ;;

  let sum =
    let open Let_syntax in
    let rec go acc = function
      | [] -> return acc
      | t :: ts ->
        printf "sum loop\n%!";
        let%bind acc' = add t acc in
        go acc' ts
    in
    function
    | [] -> failwith "Curves.sum: Expected non-empty list"
    | t :: ts -> go t ts
  ;;

  let multi_sum (pairs : (Scalar.var * var) list) ~init =
    with_label "multi_sum" begin
      let open Let_syntax in
      let rec go init = function
        | (c, t) :: ps ->
          let%bind acc = scale_bits t c ~init in
          go acc ps
        | [] -> return init
      in
      go init pairs
    end
  ;;

end

end

