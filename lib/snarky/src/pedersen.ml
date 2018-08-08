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

    val to_initial_segment_digest_exn : t -> Digest.var * [`Length of int]
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
        | `Value x1, `Value x2 -> return (`Value (Curve.add x2 x2))

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
        if a <> 0 then
          Or_error.errorf
            "to_initial_segment: Left endpoint was not zero interval: (%d, %d)"
            a b
        else Ok ()
      in
      (digest (acc t), `Length b)

    let to_initial_segment_digest_exn t =
      Or_error.ok_exn (to_initial_segment_digest t)
  end
end
