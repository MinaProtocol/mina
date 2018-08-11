open Core_kernel

module Make
    (Impl : Snark_intf.S) (Curve : sig
        type var = Impl.Field.Checked.t * Impl.Field.Checked.t

        type value

        val typ : (var, value) Impl.Typ.t

        val add : value -> value -> value

        val var_of_value : value -> var

        val identity : value

        module Checked : sig
          val add : var -> var -> (var, _) Impl.Checked.t

          val add_known : var -> value -> (var, _) Impl.Checked.t

          val cond_add :
            value -> to_:var -> if_:Impl.Boolean.var -> (var, _) Impl.Checked.t
        end
    end) (Params : sig
      val params : Curve.value array
    end) : sig
  open Impl

  module Digest : sig
    module Unpacked : sig
      type var = Boolean.var list

      type value

      val typ : (var, value) Typ.t
    end

    type var = Field.Checked.t

    type value = Field.t

    val typ : (var, value) Typ.t

    val choose_preimage : var -> (Unpacked.var, _) Checked.t
  end

  module Section : sig
    type t

    val disjoint_union_exn : t -> t -> (t, _) Checked.t

    val extend : t -> Boolean.var list -> start:int -> (t, _) Checked.t

    val acc : t -> Curve.var

    val support : t -> Interval_union.t

    val empty : t

    val create :
         acc:[`Var of Curve.var | `Value of Curve.value]
      -> support:Interval_union.t
      -> t

    val of_bits : bool list -> t

    val to_initial_segment_digest :
      t -> (Digest.var * [`Length of int]) Or_error.t
  end

  val hash :
    init:int * Curve.var -> Boolean.var list -> (Curve.var, _) Checked.t

  val digest : Curve.var -> Digest.var
end = struct
  open Impl
  open Params

  let hash_length = Field.size_in_bits

  module Digest = struct
    module Unpacked = struct
      type var = Boolean.var list

      type value = bool list

      let typ : (var, value) Typ.t = Typ.list Boolean.typ ~length:hash_length
    end

    type var = Field.Checked.t

    type value = Field.t

    let typ = Typ.field

    let choose_preimage x =
      with_label "Pedersen.Digest.choose_preimage"
        (Field.Checked.choose_preimage_var ~length:Field.size_in_bits x)
  end

  open Let_syntax

  let hash_unchecked ~init:(i0, init) bs0 =
    let n = Array.length params in
    let rec go acc i = function
      | [] -> acc
      | b :: bs ->
          if i = n then
            failwithf
              "Pedersen.hash_unchecked: Input length (%d) exceeded max (%d)"
              (List.length bs0) n ()
          else
            let acc' = if b then Curve.add params.(i) acc else acc in
            go acc' (i + 1) bs
    in
    go init i0 bs0

  let hash ~init:(i0, init) bs0 =
    let n = Array.length params in
    let rec go acc i = function
      | [] -> return acc
      | b :: bs ->
          if i = n then
            failwithf "Pedersen.hash: Input length (%d) exceeded max (%d)"
              (List.length bs0) n ()
          else
            let%bind acc' =
              Curve.Checked.cond_add params.(i) ~to_:acc ~if_:b
            in
            go acc' (i + 1) bs
    in
    with_label "Pedersen.hash" (go init i0 bs0)

  let digest (x, _) = x

  module Section = struct
    module Acc = struct
      type t = [`Var of Curve.var | `Value of Curve.value]

      let add t1 t2 =
        match (t1, t2) with
        | `Var v1, `Var v2 ->
            let%map v = Curve.Checked.add v1 v2 in
            `Var v
        | `Var v, `Value x | `Value x, `Var v ->
            let%map v = Curve.Checked.add_known v x in
            `Var v
        | `Value x1, `Value x2 -> return (`Value (Curve.add x1 x2))

      let to_var = function `Var v -> v | `Value x -> Curve.var_of_value x
    end

    type t = {support: Interval_union.t; acc: Acc.t}

    let create ~acc ~support = {acc; support}

    let of_bits bs =
      let n = List.length bs in
      let interval = (0, n) in
      { support= Interval_union.of_interval interval
      ; acc= `Value (hash_unchecked ~init:(0, Curve.identity) bs) }

    let empty = {support= Interval_union.empty; acc= `Value Curve.identity}

    let acc t = Acc.to_var t.acc

    let support t = t.support

    let extend t bits ~start =
      let n = List.length bits in
      let interval = (start, start + n) in
      let support =
        Interval_union.(disjoint_union_exn (of_interval interval) t.support)
      in
      let%map acc = hash ~init:(start, Acc.to_var t.acc) bits in
      {support; acc= `Var acc}

    let disjoint_union_exn t1 t2 =
      let support = Interval_union.disjoint_union_exn t1.support t2.support in
      let%map acc = Acc.add t1.acc t2.acc in
      {support; acc}

    let to_initial_segment_digest t =
      let open Or_error.Let_syntax in
      let%bind a, b = Interval_union.to_interval t.support in
      let%map () =
        if a = 0 then
          Or_error.error_string
            "to_initial_segment: Left endpoint was not zero"
        else Ok ()
      in
      (digest (acc t), `Length b)
  end
end


module Four = struct
  type t =
  | Zero
  | One 
  | Two
  | Three
end

module Triple = struct
  type 'a t = 'a * 'a * 'a

  let get (b : bool t) =
    let (s0, s1, s2) = b in
      match s0, s1 with
      | false, false -> Four.Zero
      | true, false -> Four.One
      | false, true -> Four.Two
      | true, true -> Four.Three
end

module Quadruple = struct
  type 'a t = 'a * 'a * 'a * 'a

  let get quad (index : Four.t) = 
    let (g0, g1, g2, g3) = quad in
      match index with 
      | Zero -> g0
      | One -> g1
      | Two -> g2
      | Three -> g3
end

module Make_faster
    (Impl : Snark_intf.S) (Weierstrass_curve : sig
        type var = Impl.Field.Checked.t * Impl.Field.Checked.t

        type t = Impl.Field.t * Impl.Field.t

        val typ : (var, t) Impl.Typ.t

        val add : t -> t -> t

        val var_of_value : t -> var

        module Checked : sig
          val add : var -> var -> (var, _) Impl.Checked.t

          val add_known : var -> t -> (var, _) Impl.Checked.t
          
          val cond_add : 
          t -> to_:var -> if_:Impl.Boolean.var -> (var, _) Impl.Checked.t
        end
    end) (Params : sig
    (* g0 g1 g2 g3 *)
      val params : Weierstrass_curve.t Quadruple.t array
    end) : sig
  open Impl

  module Digest : sig
    module Unpacked : sig
      type var = Boolean.var list

      type value

      val typ : (var, value) Typ.t
    end

    type var = Field.Checked.t

    type value = Field.t

    val typ : (var, value) Typ.t

    val choose_preimage : var -> (Unpacked.var, _) Checked.t
  end
(*
  module Curve : sig
    type var = Impl.Field.Checked.t * Impl.Field.Checked.t

    type t

    val add : t -> t -> t
  end
*)
  module Section : sig
    type t

    val disjoint_union_exn : t -> t -> (t, _) Checked.t

    val extend : t -> Boolean.var Triple.t list -> start:int -> (t, _) Checked.t

    val acc : t -> Weierstrass_curve.var

    val support : t -> Interval_union.t

  module Acc : sig
    type t 
  end

   (* val empty : t *)

    val create :
         acc: (*[`Var of Weierstrass_curve.var | `Value of Weierstrass_curve.t]*) Acc.t
      -> support:Interval_union.t
      -> t

    (* why checked ?? *)
    val of_triples : 
    bool Triple.t list
    -> Field.t * Field.t 
    -> t

    val to_initial_segment_digest :
      t -> (Digest.var * [`Length of int]) Or_error.t
  end

  val hash :
    init:int * Weierstrass_curve.var -> Boolean.var Triple.t list -> (Weierstrass_curve.var, _) Checked.t

  val digest : Weierstrass_curve.var -> Digest.var
end = struct
  open Impl
  open Params

    open Let_syntax

    let lookup ((s0, s1, s2): Boolean.var Triple.t) (q: Weierstrass_curve.t Quadruple.t) =
    let open Let_syntax in
    let open Field.Checked.Infix in
    let ((x1, y1), (x2, y2), (x3, y3), (x4, y4)) = q in
    let%bind s_and = Boolean.(s0 && s1) in
    (* these are linear so don't need checking *)
    let xs = Field.Checked.constant x1 + (Field.sub x2  x1) * (s0 :> Field.Checked.t) + (Field.sub x3 x1) * (s1 :> Field.Checked.t) + Field.Infix.(x4 + x1 - x2 - x3) * (s_and :> Field.Checked.t) in
    let y_rhs = Field.Checked.constant y1 + (Field.sub y2 y1) * (s0 :> Field.Checked.t) + (Field.sub y3 y1) * (s1 :> Field.Checked.t) + Field.Infix.(y4 + y1 - y2 - y3) * (s_and :> Field.Checked.t) in
    let y_lhs = Field.Checked.constant Field.one - (Field.of_int 2) * (s2 :> Field.Checked.t) in
    let%map ys = Field.Checked.mul y_lhs y_rhs 
    in (xs, ys)


  let hash_length = Field.size_in_bits

  module Digest = struct
    module Unpacked = struct
      type var = Boolean.var list

      type value = bool list

      let typ : (var, value) Typ.t = Typ.list Boolean.typ ~length:hash_length
    end

    type var = Field.Checked.t

    type value = Field.t

    let typ = Typ.field

    let choose_preimage x =
      with_label "Pedersen.Digest.choose_preimage"
        (Field.Checked.choose_preimage_var ~length:Field.size_in_bits x)
  end

  open Let_syntax

(* bs0 is now a list of triples *)
  let hash_unchecked ~init:(i0, init) (bs0 : bool Triple.t list) =
    let n = Array.length params in
    let rec go acc i = function
      | [] -> acc
      | b :: bs ->
          if i = n then
            failwithf
              "Pedersen.hash_unchecked: Input length (%d) exceeded max (%d)"
              (List.length bs0) n ()
          else
            (* b2 isnt used *)
            let (b0, b1, b2) = b in
            (* i dont think these are needed ever *)
            let index = Triple.get b in
            let (resx, resy) = Quadruple.get params.(i) index in
            let acc' = if b2 then
              Weierstrass_curve.add (resx, Field.negate resy) acc 
              else Weierstrass_curve.add (resx, resy) acc
            in
            go acc' (i + 1) bs
    in
    go init i0 bs0

  let hash ~init:(i0, init) (bs0 : Boolean.var Triple.t list) =
    let n = Array.length params in
    let rec go acc i = function
      | [] -> return acc
      | b :: bs ->
          if i = n then
            failwithf "Pedersen.hash: Input length (%d) exceeded max (%d)"
              (List.length bs0) n ()
          else
            let%bind res = lookup b params.(i) in
            let%bind acc' =
              Weierstrass_curve.Checked.add res acc
            in
            go acc' (i + 1) bs
    in
    with_label "Pedersen.hash" (go init i0 bs0)

  let digest (x, _) = x


  module Section = struct

    module Acc = struct
      type t =
      | Var of Weierstrass_curve.var
      | Value of Weierstrass_curve.t

      let add t1 t2 =
        match (t1, t2) with
        | Var v1, Var v2 ->
            let%map v = Weierstrass_curve.Checked.add v1 v2 in
            Var v
        | Var v, Value x | Value x, Var v ->
            let%map v = Weierstrass_curve.Checked.add_known v x in
            Var v
        | Value x1, Value x2 -> return (Value (Weierstrass_curve.add x1 x2))

      let to_var : t -> Weierstrass_curve.var = function
      | Var v -> v 
      | Value x -> Weierstrass_curve.var_of_value x
    end
    
    type t = {support: Interval_union.t; acc: Acc.t}

    let create ~acc ~support = {acc; support}

    let of_triples bs g =
      let (x, y) = g in
      let n = List.length bs in
      let interval = (0, n) in
      { support = Interval_union.of_interval interval
      ; acc = Value (hash_unchecked ~init:(0, (x, y)) bs) }

    let acc t = Acc.to_var t.acc

    let support t = t.support

    let extend t triples ~start =
      let n = List.length triples in
      let interval = (start, start + n) in
      let support =
        Interval_union.(disjoint_union_exn (of_interval interval) t.support)
      in
      let%map acc = hash ~init:(start, Acc.to_var t.acc) triples in
      {support; acc= Var acc}

    let disjoint_union_exn t1 t2 =
      let support = Interval_union.disjoint_union_exn t1.support t2.support in
      let%map acc = Acc.add t1.acc t2.acc in
      {support; acc}

    let to_initial_segment_digest t =
      let open Or_error.Let_syntax in
      let%bind a, b = Interval_union.to_interval t.support in
      let%map () =
        if a = 0 then
          Or_error.error_string
            "to_initial_segment: Left endpoint was not zero"
        else Ok ()
      in
      (digest (acc t), `Length b)
  end
end
