module Bignum_bigint = Bigint
open Core_kernel

module type Params_intf = sig
  type field

  val a : field

  val b : field
end

module type Scalar_intf = sig
  type (_, _) typ

  type (_, _) checked

  type boolean_var

  type var

  type t [@@deriving eq, sexp]

  val typ : (var, t) typ

  val length_in_bits : int

  val test_bit : t -> int -> bool

  module Checked : sig
    val equal : var -> var -> (boolean_var, _) checked

    module Assert : sig
      val equal : var -> var -> (unit, _) checked
    end
  end
end

module Make_intf (Impl : Snark_intf.S) = struct
  open Impl

  module type S = sig
    include Params_intf with type field := Field.t

    module Scalar :
      Scalar_intf
      with type ('a, 'b) typ := ('a, 'b) Typ.t
       and type ('a, 'b) checked := ('a, 'b) Checked.t
       and type boolean_var := Boolean.var

    type 'a t = 'a * 'a

    type var = Field.Checked.t t

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

module type Shifted_intf = sig
  type (_, _) checked

  type boolean_var

  type curve_var

  type t

  val zero : t

  val add : t -> curve_var -> (t, _) checked

  (* This is only safe if the result is guaranteed to not be zero. *)

  val unshift_nonzero : t -> (curve_var, _) checked

  val if_ : boolean_var -> then_:t -> else_:t -> (t, _) checked

  module Assert : sig
    val equal : t -> t -> (unit, _) checked
  end
end

module Edwards = struct
  module type Params_intf = sig
    type field

    val d : field

    val cofactor : Bignum_bigint.t

    val generator : field * field

    val order : Bignum_bigint.t
  end

  module Basic = struct
    module type S = sig
      type field

      type t = field * field [@@deriving sexp]

      module Params : Params_intf with type field := field

      val generator : t

      val identity : t

      val add : t -> t -> t

      val double : t -> t

      val equal : t -> t -> bool

      val find_y : field -> field option
    end

    module Make
        (Field : Field_intf.Extended)
        (Params : Params_intf with type field := Field.t) :
      S with type field := Field.t and module Params = Params = struct
      open Field
      module Params = Params

      type t = Field.t * Field.t [@@deriving sexp]

      (* x^2 + y^2 = 1 + dx^2 y^2 *)
      (* x^2 - d x^2 y^2 = 1 - y^2 *)
      (* x^2 (1 - d y^2) = 1 - y^2 *)
      (* x^2 = (1 - y^2)/(1 - d y^2) *)

      let generator : t = Params.generator

      let identity : t = (Field.zero, Field.one)

      let equal (x1, y1) (x2, y2) = Field.equal x1 x2 && Field.equal y1 y2

      (* (x^2 - 1)/(d x^2 - 1) = y^2 *)
      let find_y x =
        let xx = Field.square x in
        let yy = Field.Infix.((xx - one) / ((Params.d * xx) - one)) in
        if Field.is_square yy then Some (sqrt yy) else None

      let add (x1, y1) (x2, y2) =
        let open Field.Infix in
        let x1x2 = x1 * x2 in
        let y1y2 = y1 * y2 in
        let x1y2 = x1 * y2 in
        let y1x2 = y1 * x2 in
        let c = Params.d * x1x2 * y1y2 in
        ((x1y2 + y1x2) / (Field.one + c), (y1y2 - x1x2) / (Field.one - c))

      let double (x, y) =
        let open Field.Infix in
        let xy = x * y in
        let xx = x * x in
        let yy = y * y in
        let two = Field.of_int 2 in
        (two * xy / (xx + yy), (yy - xx) / (two - xx - yy))
    end
  end

  module type S = sig
    type (_, _) checked

    type (_, _) typ

    type boolean_var

    type field

    include Basic.S with type field := field

    module Scalar :
      Scalar_intf
      with type ('a, 'b) checked := ('a, 'b) checked
       and type ('a, 'b) typ := ('a, 'b) typ
       and type boolean_var := boolean_var

    type var

    type value = t [@@deriving eq, sexp]

    val var_of_value : value -> var

    val typ : (var, value) typ

    val add : value -> value -> value

    val equal : value -> value -> bool

    val identity : value

    val generator : value

    module Checked : sig
      val generator : var

      val identity : var

      val add : var -> var -> (var, _) checked

      val add_known : var -> value -> (var, _) checked

      val if_ : boolean_var -> then_:var -> else_:var -> (var, _) checked

      val if_value : boolean_var -> then_:value -> else_:value -> var

      val cond_add : value -> to_:var -> if_:boolean_var -> (var, _) checked

      module Assert : sig
        val equal : var -> var -> (unit, _) checked

        val on_curve : var -> (unit, _) checked
      end

      val scale : var -> Scalar.var -> (var, _) checked

      val scale_known : value -> Scalar.var -> (var, _) checked
    end
  end

  module Extend
      (Impl : Snark_intf.S)
      (Scalar : Scalar_intf
                with type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
                 and type ('a, 'b) typ := ('a, 'b) Impl.Typ.t
                 and type boolean_var := Impl.Boolean.var
                 and type var = Impl.Boolean.var list)
      (Basic : Basic.S with type field := Impl.Field.t) :
    S
    with type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
     and type ('a, 'b) typ := ('a, 'b) Impl.Typ.t
     and type boolean_var := Impl.Boolean.var
     and type field := Impl.Field.t
     and type var = Impl.Field.Checked.t * Impl.Field.Checked.t
     and type value = Impl.Field.t * Impl.Field.t
     and module Scalar = Scalar = struct
    open Impl
    include Basic
    module Scalar = Scalar

    type 'a tup = 'a * 'a [@@deriving eq, sexp]

    type var = Field.Checked.t tup

    type value = Field.t tup [@@deriving eq, sexp]

    let var_of_value (x, y) =
      (Field.Checked.constant x, Field.Checked.constant y)

    let identity_value = identity

    (* TODO: Assert quadratic non-residuosity of Params.d *)

    let assert_on_curve (x, y) =
      let open Let_syntax in
      let%bind x2 = Field.Checked.mul x x and y2 = Field.Checked.mul y y in
      let open Field.Checked.Infix in
      assert_r1cs (Params.d * x2) y2
        (x2 + y2 - Field.Checked.constant Field.one)

    let typ_unchecked : (var, value) Typ.t = Typ.(tuple2 field field)

    let typ : (var, value) Typ.t =
      (* TODO: Check if in subgroup? *)
      {typ_unchecked with check= assert_on_curve}

    let double_value = double

    module Checked = struct
      open Let_syntax

      let identity = var_of_value identity_value

      let generator = var_of_value generator

      module Assert = struct
        let on_curve = assert_on_curve

        let equal (x1, y1) (x2, y2) =
          let%map () = Field.Checked.Assert.equal x1 x2
          and () = Field.Checked.Assert.equal y1 y2 in
          ()
      end

      let add_known (x1, y1) (x2, y2) =
        with_label __LOC__
          (let x1x2 = Field.Checked.scale x1 x2
           and y1y2 = Field.Checked.scale y1 y2
           and x1y2 = Field.Checked.scale x1 y2
           and y1x2 = Field.Checked.scale y1 x2 in
           let%bind p = Field.Checked.mul x1x2 y1y2 in
           let open Field.Checked.Infix in
           let p = Params.d * p in
           let%map a =
             Field.Checked.div (x1y2 + y1x2)
               (Field.Checked.constant Field.one + p)
           and b =
             Field.Checked.div (y1y2 - x1x2)
               (Field.Checked.constant Field.one - p)
           in
           (a, b))

      (* TODO: Optimize -- could probably shave off one constraint. *)
      let add (x1, y1) (x2, y2) =
        with_label __LOC__
          (let%bind x1x2 = Field.Checked.mul x1 x2
           and y1y2 = Field.Checked.mul y1 y2
           and x1y2 = Field.Checked.mul x1 y2
           and x2y1 = Field.Checked.mul x2 y1 in
           let%bind p = Field.Checked.mul x1x2 y1y2 in
           let open Field.Checked.Infix in
           let p = Params.d * p in
           let%map a =
             Field.Checked.div (x1y2 + x2y1)
               (Field.Checked.constant Field.one + p)
           and b =
             Field.Checked.div (y1y2 - x1x2)
               (Field.Checked.constant Field.one - p)
           in
           (a, b))

      let double (x, y) =
        with_label __LOC__
          (let%bind xy = Field.Checked.mul x y
           and xx = Field.Checked.mul x x
           and yy = Field.Checked.mul y y in
           let open Field.Checked.Infix in
           let two = Field.of_int 2 in
           let%map a = Field.Checked.div (two * xy) (xx + yy)
           and b =
             Field.Checked.div (yy - xx) (Field.Checked.constant two - xx - yy)
           in
           (a, b))

      let if_value (b : Boolean.var) ~then_:(x1, y1) ~else_:(x2, y2) =
        let not_b = (Boolean.not b :> Field.Checked.t) in
        let b = (b :> Field.Checked.t) in
        let choose_field t e =
          let open Field.Checked in
          Infix.((t * b) + (e * not_b))
        in
        (choose_field x1 x2, choose_field y1 y2)

      (* TODO-someday: Make it so this doesn't have to compute both branches *)
      let if_ =
        let to_list (x, y) = [x; y] in
        let rev_map3i_exn xs ys zs ~f =
          let rec go i acc xs ys zs =
            match (xs, ys, zs) with
            | x :: xs, y :: ys, z :: zs ->
                go (i + 1) (f i x y z :: acc) xs ys zs
            | [], [], [] -> acc
            | _ -> failwith "rev_map3i_exn"
          in
          go 0 [] xs ys zs
        in
        fun b ~then_ ~else_ ->
          with_label __LOC__
            (let%bind r =
               provide_witness typ
                 (let open As_prover in
                 let open Let_syntax in
                 let%bind b = read Boolean.typ b in
                 read typ (if b then then_ else else_))
             in
             (*     r - e = b (t - e) *)
             let%map () =
               rev_map3i_exn (to_list r) (to_list then_) (to_list else_)
                 ~f:(fun i r t e ->
                   let open Field.Checked.Infix in
                   Constraint.r1cs ~label:(sprintf "main_%d" i)
                     (b :> Field.Checked.t)
                     (t - e) (r - e) )
               |> assert_all
             in
             r)

      let scale t (c : Scalar.var) =
        with_label __LOC__
          (let rec go i acc pt = function
             | [] -> return acc
             | b :: bs ->
                 let%bind acc' =
                   with_label (sprintf "acc_%d" i)
                     (let%bind add_pt = add acc pt in
                      let don't_add_pt = acc in
                      if_ b ~then_:add_pt ~else_:don't_add_pt)
                 and pt' = double pt in
                 go (i + 1) acc' pt' bs
           in
           match c with
           | [] -> failwith "Edwards.Checked.scale: Empty bits"
           | b :: bs ->
               let%bind acc = if_ b ~then_:t ~else_:identity
               and pt = double t in
               go 1 acc pt bs)

      (* TODO: Unit test *)
      let cond_add ((x2, y2) : value) ~to_:((x1, y1) : var)
          ~if_:(b : Boolean.var) : (var, _) Checked.t =
        with_label __LOC__
          (let one = Field.Checked.constant Field.one in
           let b = (b :> Field.Checked.t) in
           let open Let_syntax in
           let open Field.Checked.Infix in
           let res a1 a3 =
             let%bind a =
               provide_witness Typ.field
                 (let open As_prover in
                 let open As_prover.Let_syntax in
                 let open Field.Infix in
                 let%map b = read_var b
                 and a3 = read_var a3
                 and a1 = read_var a1 in
                 a1 + (b * (a3 - a1)))
             in
             let%map () = assert_r1cs b (a3 - a1) (a - a1) in
             a
           in
           let%bind beta = Field.Checked.mul x1 y1 in
           let p = Field.Infix.(Params.d * x2 * y2) * beta in
           let%bind x3 = Field.Checked.div ((y2 * x1) + (x2 * y1)) (one + p)
           and y3 = Field.Checked.div ((y2 * y1) - (x2 * x1)) (one - p) in
           let%map x_res = res x1 x3 and y_res = res y1 y3 in
           (x_res, y_res))

      let scale_known (t : value) (c : Scalar.var) =
        with_label __LOC__
          (let rec go i acc pt = function
             | b :: bs ->
                 let%bind acc' =
                   with_label (sprintf "acc_%d" i)
                     (cond_add pt ~to_:acc ~if_:b)
                 in
                 go (i + 1) acc' (double_value pt) bs
             | [] -> return acc
           in
           match c with
           | [] -> failwith "scale_known: Empty bits"
           | b :: bs ->
               let acc =
                 let b = (b :> Field.Checked.t) in
                 let x_id, y_id = identity_value in
                 let x_t, y_t = t in
                 let open Field.Checked.Infix in
                 ( (Field.Infix.(x_t - x_id) * b) + Field.Checked.constant x_id
                 , (Field.Infix.(y_t - y_id) * b) + Field.Checked.constant y_id
                 )
               in
               go 1 acc (double_value t) bs)
    end
  end

  module Make
      (Impl : Snark_intf.S)
      (Scalar : Scalar_intf
                with type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
                 and type ('a, 'b) typ := ('a, 'b) Impl.Typ.t
                 and type boolean_var := Impl.Boolean.var
                 and type var = Impl.Boolean.var list)
      (Params : Params_intf with type field := Impl.Field.t) :
    S
    with type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
     and type Scalar.t = Scalar.t
     and type Scalar.var = Scalar.var
     and type ('a, 'b) typ := ('a, 'b) Impl.Typ.t
     and type boolean_var := Impl.Boolean.var
     and type field := Impl.Field.t
     and type var = Impl.Field.Checked.t * Impl.Field.Checked.t
     and type value = Impl.Field.t * Impl.Field.t =
    Extend (Impl) (Scalar) (Basic.Make (Impl.Field) (Params))
end

module type Weierstrass_checked_intf = sig
  module Impl : Snark_intf.S

  open Impl

  type t

  type var

  val typ : (var, t) Typ.t

  module Shifted : sig
    module type S =
      Shifted_intf
      with type ('a, 'b) checked := ('a, 'b) Checked.t
       and type curve_var := var
       and type boolean_var := Boolean.var

    type 'a m = (module S with type t = 'a)

    val create : unit -> ((module S), _) Checked.t
  end

  val negate : var -> var

  val constant : t -> var

  val add_unsafe : var -> var -> (var, _) Checked.t

  val if_ : Boolean.var -> then_:var -> else_:var -> (var, _) Checked.t

  val double : var -> (var, _) Checked.t

  val if_value : Boolean.var -> then_:t -> else_:t -> var

  val scale :
       's Shifted.m
    -> var
    -> Boolean.var Bitstring_lib.Bitstring.Lsb_first.t
    -> init:'s
    -> ('s, _) Checked.t

  val scale_known :
       's Shifted.m
    -> t
    -> Boolean.var Bitstring_lib.Bitstring.Lsb_first.t
    -> init:'s
    -> ('s, _) Checked.t

  val sum : 's Shifted.m -> var list -> init:'s -> ('s, _) Checked.t

  module Assert : sig
    val on_curve : var -> (unit, _) Checked.t

    val equal : var -> var -> (unit, _) Checked.t
  end
end

module Make_weierstrass_checked
    (Impl : Snark_intf.S) (Scalar : sig
        type t

        val of_int : int -> t
    end) (Curve : sig
      type t

      val random : unit -> t

      val to_coords : t -> Impl.Field.t * Impl.Field.t

      val of_coords : Impl.Field.t * Impl.Field.t -> t

      val double : t -> t

      val add : t -> t -> t

      val negate : t -> t

      val scale : t -> Scalar.t -> t
    end)
    (Params : Params_intf with type field := Impl.Field.t) :
  Weierstrass_checked_intf
  with module Impl := Impl
   and type t := Curve.t
   and type var := Impl.Field.var * Impl.Field.var = struct
  open Impl

  type var = Field.Checked.t * Field.Checked.t

  type t = Curve.t

  let assert_on_curve (x, y) =
    let open Let_syntax in
    let%bind x2 = Field.Checked.square x in
    let%bind x3 = Field.Checked.mul x2 x in
    assert_square y
      Field.Checked.Infix.(
        x3 + (Params.a * x) + Field.Checked.constant Params.b)

  let typ : (var, t) Typ.t =
    let unchecked =
      Typ.transport
        Typ.(tuple2 field field)
        ~there:Curve.to_coords ~back:Curve.of_coords
    in
    {unchecked with check= assert_on_curve}

  let negate ((x, y) : var) : var =
    (x, Field.Checked.scale y Field.(negate one))

  let constant (t : t) : var =
    let x, y = Curve.to_coords t in
    Field.Checked.(constant x, constant y)

  let assert_equal (x1, y1) (x2, y2) =
    assert_all [Constraint.equal x1 x2; Constraint.equal y1 y2]

  module Assert = struct
    let on_curve = assert_on_curve

    let equal = assert_equal
  end

  let add_unsafe (ax, ay) (bx, by) =
    with_label __LOC__
      (let open Let_syntax in
      let%bind lambda = Field.Checked.(div (sub by ay) (sub bx ax)) in
      let%bind cx =
        provide_witness Typ.field
          (let open As_prover in
          let open Let_syntax in
          let%map ax = read_var ax
          and bx = read_var bx
          and lambda = read_var lambda in
          Field.(sub (square lambda) (add ax bx)))
      in
      let%bind () =
        (* lambda^2 = cx + ax + bx
            cx = lambda^2 - (ax + bc)
        *)
        assert_
          (Constraint.square ~label:"c1" lambda
             Field.Checked.Infix.(cx + ax + bx))
      in
      let%bind cy =
        provide_witness Typ.field
          (let open As_prover in
          let open Let_syntax in
          let%map ax = read_var ax
          and ay = read_var ay
          and cx = read_var cx
          and lambda = read_var lambda in
          Field.(sub (mul lambda (sub ax cx)) ay))
      in
      let%map () =
        Field.Checked.Infix.(
          assert_r1cs ~label:"c2" lambda (ax - cx) (cy + ay))
      in
      (cx, cy))

  (* TODO-someday: Make it so this doesn't have to compute both branches *)
  let if_ =
    let to_list (x, y) = [x; y] in
    let rev_map3i_exn xs ys zs ~f =
      let rec go i acc xs ys zs =
        match (xs, ys, zs) with
        | x :: xs, y :: ys, z :: zs -> go (i + 1) (f i x y z :: acc) xs ys zs
        | [], [], [] -> acc
        | _ -> failwith "rev_map3i_exn"
      in
      go 0 [] xs ys zs
    in
    fun b ~then_ ~else_ ->
      let open Let_syntax in
      let%bind r =
        provide_witness typ
          (let open As_prover in
          let open Let_syntax in
          let%bind b = read Boolean.typ b in
          read typ (if b then then_ else else_))
      in
      (*     r - e = b (t - e) *)
      let%map () =
        rev_map3i_exn (to_list r) (to_list then_) (to_list else_)
          ~f:(fun i r t e ->
            let open Field.Checked.Infix in
            Constraint.r1cs ~label:(sprintf "main_%d" i)
              (b :> Field.Checked.t)
              (t - e) (r - e) )
        |> assert_all
      in
      r

  module Shifted = struct
    module type S =
      Shifted_intf
      with type ('a, 'b) checked := ('a, 'b) Checked.t
       and type curve_var := var
       and type boolean_var := Boolean.var

    type 'a m = (module S with type t = 'a)

    module Make (M : sig
      val shift : var
    end) : S = struct
      open M

      type t = var

      let zero = shift

      let if_ = if_

      let unshift_nonzero shifted = add_unsafe (negate shift) shifted

      let add shifted x = add_unsafe shifted x

      module Assert = struct
        let equal = assert_equal
      end
    end

    let create (type shifted) () : ((module S), _) Checked.t =
      let open Let_syntax in
      let%map shift =
        provide_witness typ As_prover.(map (return ()) ~f:Curve.random)
      in
      let module M = Make (struct
        let shift = shift
      end) in
      (module M : S)
  end

  let double (ax, ay) =
    with_label __LOC__
      (let open Let_syntax in
      let%bind x_squared = Field.Checked.square ax in
      let%bind lambda =
        provide_witness Typ.field
          As_prover.(
            map2 (read_var x_squared) (read_var ay) ~f:(fun x_squared ay ->
                let open Field in
                let open Infix in
                ((of_int 3 * x_squared) + Params.a) * inv (of_int 2 * ay) ))
      in
      let%bind bx =
        provide_witness Typ.field
          As_prover.(
            map2 (read_var lambda) (read_var ax) ~f:(fun lambda ax ->
                let open Field in
                Infix.(square lambda - (of_int 2 * ax)) ))
      in
      let%bind by =
        provide_witness Typ.field
          (let open As_prover in
          let open Let_syntax in
          let%map lambda = read_var lambda
          and ax = read_var ax
          and ay = read_var ay
          and bx = read_var bx in
          Field.Infix.((lambda * (ax - bx)) - ay))
      in
      let two = Field.of_int 2 in
      let open Field.Checked.Infix in
      let%map () =
        assert_r1cs (two * lambda) ay
          ((Field.of_int 3 * x_squared) + Field.Checked.constant Params.a)
      and () = assert_square lambda (bx + (two * ax))
      and () = assert_r1cs lambda (ax - bx) (by + ay) in
      (bx, by))

  let if_value (cond : Boolean.var) ~then_ ~else_ =
    let x1, y1 = Curve.to_coords then_ in
    let x2, y2 = Curve.to_coords else_ in
    let cond = (cond :> Field.Checked.t) in
    let choose a1 a2 =
      let open Field.Checked in
      Infix.((a1 * cond) + (a2 * (constant Field.one - cond)))
    in
    (choose x1 x2, choose y1 y2)

  let scale (type shifted) (module Shifted : Shifted.S with type t = shifted) t
      (c : Boolean.var Bitstring_lib.Bitstring.Lsb_first.t) ~(init : shifted) :
      (shifted, _) Checked.t =
    let c = Bitstring_lib.Bitstring.Lsb_first.to_list c in
    with_label __LOC__
      (let open Let_syntax in
      let rec go i bs0 acc pt =
        match bs0 with
        | [] -> return acc
        | b :: bs ->
            let%bind acc' =
              with_label (sprintf "acc_%d" i)
                (let%bind add_pt = Shifted.add acc pt in
                 let don't_add_pt = acc in
                 Shifted.if_ b ~then_:add_pt ~else_:don't_add_pt)
            and pt' = double pt in
            go (i + 1) bs acc' pt'
      in
      go 0 c init t)

  (* This 'looks up' a field element from a lookup table of size 2^2 = 4 with
   a 2 bit index.  See https://github.com/zcash/zcash/issues/2234#issuecomment-383736266 for
   a discussion of this trick.
*)
  let lookup_point (b0, b1) (t1, t2, t3, t4) =
    let open Let_syntax in
    let%map b0_and_b1 = Boolean.( && ) b0 b1 in
    let lookup_one (a1, a2, a3, a4) =
      let open Field.Infix in
      let ( * ) = Field.Checked.Infix.( * ) in
      let ( +^ ) = Field.Checked.Infix.( + ) in
      Field.Checked.constant a1
      +^ ((a2 - a1) * (b0 :> Field.Checked.t))
      +^ ((a3 - a1) * (b1 :> Field.Checked.t))
      +^ ((a4 + a1 - a2 - a3) * (b0_and_b1 :> Field.Checked.t))
    in
    let x1, y1 = Curve.to_coords t1
    and x2, y2 = Curve.to_coords t2
    and x3, y3 = Curve.to_coords t3
    and x4, y4 = Curve.to_coords t4 in
    (lookup_one (x1, x2, x3, x4), lookup_one (y1, y2, y3, y4))

  (* Similar to the above, but doing lookup in a size 1 table *)
  let lookup_single_bit (b : Boolean.var) (t1, t2) =
    let lookup_one (a1, a2) =
      let open Field.Checked.Infix in
      Field.Checked.constant a1 + (Field.sub a2 a1 * (b :> Field.Checked.t))
    in
    let x1, y1 = Curve.to_coords t1 and x2, y2 = Curve.to_coords t2 in
    (lookup_one (x1, x2), lookup_one (y1, y2))

  let scale_known (type shifted)
      (module Shifted : Shifted.S with type t = shifted) (t : Curve.t)
      (b : Boolean.var Bitstring_lib.Bitstring.Lsb_first.t) ~init =
    let b = Bitstring_lib.Bitstring.Lsb_first.to_list b in
    let sigma = t in
    let n = List.length b in
    let sigma_count = (n + 1) / 2 in
    (* = ceil (n / 2.0) *)
    (* We implement a complicated optimzation so that in total
       this costs roughly (1 + 3) * (n / 2) constaints, rather than
       the naive 4*n + 3*n. If scalars were represented with some
       kind of signed digit representation we could probably get it
       down to 2 * (n / 3) + 3 * (n / 3).
    *)
    (* Assume n is even *)
    (* Define
       to_term_unshifted i (b0, b1) =
       match b0, b1 with
       | false, false -> oo
       | true, false -> 2^i * t
       | false, true -> 2^{i+1} * t
       | true, true -> 2^i * t + 2^{i + 1} t

       to_term i (b0, b1) =
       sigma + to_term_unshifted i (b0, b1) =
       match b0, b1 with
       | false, false -> sigma
       | true, false -> sigma + 2^i * t
       | false, true -> sigma + 2^{i+1} * t
       | true, true -> sigma + 2^i * t + 2^{i + 1} t
    *)
    let to_term ~two_to_the_i ~two_to_the_i_plus_1 bits =
      lookup_point bits
        ( sigma
        , Curve.add sigma two_to_the_i
        , Curve.add sigma two_to_the_i_plus_1
        , Curve.(add sigma (add two_to_the_i two_to_the_i_plus_1)) )
    in
    (*
       Say b = b0, b1, .., b_{n-1}.
       We compute

       (to_term 0 (b0, b1)
       + to_term 2 (b2, b3)
       + to_term 4 (b4, b5)
       + ...
       + to_term (n-2) (b_{n-2}, b_{n-1}))
       - (n/2) * sigma
       =
       (n/2)*sigma + (b0*2^0 + b1*21 + ... + b_{n-1}*2^{n-1}) t - (n/2) * sigma
       =
       (n/2)*sigma + b * t - (n/2)*sigma
       = b * t
    *)
    let open Let_syntax in
    let rec go acc two_to_the_i bits =
      match bits with
      | [] -> return acc
      | [b_i] ->
          let term =
            lookup_single_bit b_i (sigma, Curve.add sigma two_to_the_i)
          in
          Shifted.add acc term
      | b_i :: b_i_plus_1 :: rest ->
          let two_to_the_i_plus_1 = Curve.double two_to_the_i in
          let%bind term =
            to_term ~two_to_the_i ~two_to_the_i_plus_1 (b_i, b_i_plus_1)
          in
          let%bind acc = Shifted.add acc term in
          go acc (Curve.double two_to_the_i_plus_1) rest
    in
    let%bind result_with_shift = go init t b in
    let unshift =
      Curve.scale (Curve.negate sigma) (Scalar.of_int sigma_count)
    in
    Shifted.add result_with_shift (constant unshift)

  let sum (type shifted) (module Shifted : Shifted.S with type t = shifted) xs
      ~init =
    let open Let_syntax in
    let rec go acc = function
      | [] -> return acc
      | t :: ts ->
          let%bind acc' = Shifted.add acc t in
          go acc' ts
    in
    go init xs
end
