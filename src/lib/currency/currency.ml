open Core
open Snark_params
open Tick
open Let_syntax
open Snark_bits
open Bitstring_lib
open Fold_lib
open Tuple_lib

type uint64 = Unsigned.uint64

module type Basic = sig
  type t [@@deriving bin_io, sexp, compare, hash]

  include Comparable.S with type t := t

  val gen : t Quickcheck.Generator.t

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, sexp, compare, eq, hash]
    end
  end

  include Bits_intf.S with type t := t

  val fold : t -> bool Triple.t Fold.t

  val length_in_triples : int

  val zero : t

  val of_string : string -> t

  val to_string : t -> string

  type var

  val typ : (var, t) Typ.t

  val of_int : int -> t

  val to_int : t -> int

  val to_uint64 : t -> uint64

  val of_uint64 : uint64 -> t

  val var_of_t : t -> var

  val var_to_triples : var -> Boolean.var Triple.t list
end

module type Arithmetic_intf = sig
  type t

  val add : t -> t -> t option

  val sub : t -> t -> t option

  val ( + ) : t -> t -> t option

  val ( - ) : t -> t -> t option
end

module type Signed_intf = sig
  type magnitude

  type magnitude_var

  type ('magnitude, 'sgn) t_

  type t = (magnitude, Sgn.t) t_ [@@deriving sexp, hash, bin_io, compare, eq]

  val gen : t Quickcheck.Generator.t

  module Stable : sig
    module V1 : sig
      type nonrec ('magnitude, 'sgn) t_ = ('magnitude, 'sgn) t_

      type nonrec t = t [@@deriving bin_io, sexp, hash, compare, eq]
    end
  end

  val length_in_triples : int

  val create : magnitude:'magnitude -> sgn:'sgn -> ('magnitude, 'sgn) t_

  val sgn : t -> Sgn.t

  val magnitude : t -> magnitude

  type nonrec var = (magnitude_var, Sgn.var) t_

  val typ : (var, t) Typ.t

  val zero : t

  val fold : t -> bool Triple.t Fold.t

  val to_triples : t -> bool Triple.t list

  val add : t -> t -> t option

  val ( + ) : t -> t -> t option

  val negate : t -> t

  val of_unsigned : magnitude -> t

  module Checked : sig
    val constant : t -> var

    val of_unsigned : magnitude_var -> var

    val if_ : Boolean.var -> then_:var -> else_:var -> (var, _) Checked.t

    val to_triples : var -> Boolean.var Triple.t list

    val add : var -> var -> (var, _) Checked.t

    val ( + ) : var -> var -> (var, _) Checked.t

    val to_field_var : var -> (Field.var, _) Checked.t

    val cswap :
         Boolean.var
      -> (magnitude_var, Sgn.t) t_ * (magnitude_var, Sgn.t) t_
      -> (var * var, _) Checked.t
  end
end

module type Checked_arithmetic_intf = sig
  type t

  type var

  type signed_var

  val if_ : Boolean.var -> then_:var -> else_:var -> (var, _) Checked.t

  val if_value : Boolean.var -> then_:t -> else_:t -> var

  val add : var -> var -> (var, _) Checked.t

  val sub : var -> var -> (var, _) Checked.t

  val sub_flagged :
    var -> var -> (var * [`Underflow of Boolean.var], _) Checked.t

  val ( + ) : var -> var -> (var, _) Checked.t

  val ( - ) : var -> var -> (var, _) Checked.t

  val add_signed : var -> signed_var -> (var, _) Checked.t
end

module type S = sig
  include Basic

  include Arithmetic_intf with type t := t

  module Signed :
    Signed_intf with type magnitude := t and type magnitude_var := var

  module Checked :
    Checked_arithmetic_intf
    with type var := var
     and type signed_var := Signed.var
     and type t := t
end

module Make (Unsigned : sig
  include Unsigned_extended.S

  val to_uint64 : t -> uint64

  val of_uint64 : uint64 -> t
end) (M : sig
  val length : int
end) : sig
  include S with type t = Unsigned.t and type var = Boolean.var list

  val var_of_bits : Boolean.var Bitstring.Lsb_first.t -> var

  val unpack_var : Field.Checked.t -> (var, _) Tick.Checked.t

  val pack_var : var -> Field.Checked.t
end = struct
  let length_in_bits = M.length

  let length_in_triples = (length_in_bits + 2) / 3

  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Unsigned.t [@@deriving bin_io, sexp, compare, hash]
      end

      include T
      include Hashable.Make (T)
      include Comparable.Make (T)
    end
  end

  include Stable.V1

  let to_uint64 = Unsigned.to_uint64

  let of_uint64 = Unsigned.of_uint64

  let of_int = Unsigned.of_int

  let to_int = Unsigned.to_int

  let of_string = Unsigned.of_string

  let to_string = Unsigned.to_string

  let gen : t Quickcheck.Generator.t =
    let m = Bignum_bigint.of_string Unsigned.(to_string max_int) in
    Quickcheck.Generator.map
      Bignum_bigint.(gen_incl zero m)
      ~f:(fun n -> of_string (Bignum_bigint.to_string n))

  module Vector = struct
    include M
    include Unsigned

    let empty = zero

    let get t i = Infix.((t lsr i) land one = one)

    let set v i b =
      if b then Infix.(v lor (one lsl i))
      else Infix.(v land lognot (one lsl i))
  end

  include (Bits.Vector.Make (Vector) : Bits_intf.S with type t := t)

  include Bits.Snarkable.Small_bit_vector (Tick) (Vector)
  include Unpacked

  let var_to_triples t =
    Bitstring.pad_to_triple_list ~default:Boolean.false_ (var_to_bits t)

  let var_of_bits (bits : Boolean.var Bitstring.Lsb_first.t) : var =
    let bits = (bits :> Boolean.var list) in
    let n = List.length bits in
    assert (Int.( <= ) n M.length) ;
    let padding = M.length - n in
    bits @ List.init padding ~f:(fun _ -> Boolean.false_)

  let zero = Unsigned.zero

  let sub x y = if x < y then None else Some (Unsigned.sub x y)

  let add x y =
    let z = Unsigned.add x y in
    if z < x then None else Some z

  let ( + ) = add

  let ( - ) = sub

  let var_of_t t =
    List.init M.length ~f:(fun i -> Boolean.var_of_value (Vector.get t i))

  type magnitude = t [@@deriving sexp, bin_io, hash, compare, eq]

  let fold_bits = fold

  let fold t = Fold.group3 ~default:false (fold t)

  let if_ cond ~then_ ~else_ =
    Field.Checked.if_ cond ~then_:(pack_var then_) ~else_:(pack_var else_)
    >>= unpack_var

  module Signed = struct
    module Stable = struct
      module V1 = struct
        type ('magnitude, 'sgn) t_ = {magnitude: 'magnitude; sgn: 'sgn}
        [@@deriving bin_io, sexp, hash, compare, fields, eq]

        let create ~magnitude ~sgn = {magnitude; sgn}

        type t = (magnitude, Sgn.t) t_
        [@@deriving bin_io, sexp, hash, compare, eq]
      end
    end

    include Stable.V1

    let zero = create ~magnitude:zero ~sgn:Sgn.Pos

    let gen =
      Quickcheck.Generator.map2 gen Sgn.gen ~f:(fun magnitude sgn ->
          create ~magnitude ~sgn )

    type nonrec var = (var, Sgn.var) t_

    let length_in_bits = Int.( + ) length_in_bits 1

    let length_in_triples = Int.((length_in_bits + 2) / 3)

    let of_hlist : (unit, 'a -> 'b -> unit) Snarky.H_list.t -> ('a, 'b) t_ =
      Snarky.H_list.(fun [magnitude; sgn] -> {magnitude; sgn})

    let to_hlist {magnitude; sgn} = Snarky.H_list.[magnitude; sgn]

    let typ =
      Typ.of_hlistable
        Data_spec.[typ; Sgn.typ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let sgn_to_bool = function Sgn.Pos -> true | Neg -> false

    let fold_bits ({sgn; magnitude} : t) =
      { Fold.fold=
          (fun ~init ~f ->
            let init = (fold_bits magnitude).fold ~init ~f in
            f init (sgn_to_bool sgn) ) }

    let fold t = Fold.group3 ~default:false (fold_bits t)

    let to_triples t =
      List.rev ((fold t).fold ~init:[] ~f:(fun acc x -> x :: acc))

    let add (x : t) (y : t) : t option =
      match (x.sgn, y.sgn) with
      | Neg, (Neg as sgn) | Pos, (Pos as sgn) ->
          let open Option.Let_syntax in
          let%map magnitude = add x.magnitude y.magnitude in
          {sgn; magnitude}
      | Pos, Neg | Neg, Pos ->
          let c = compare_magnitude x.magnitude y.magnitude in
          Some
            ( if Int.( < ) c 0 then
              { sgn= y.sgn
              ; magnitude= Unsigned.Infix.(y.magnitude - x.magnitude) }
            else if Int.( > ) c 0 then
              { sgn= x.sgn
              ; magnitude= Unsigned.Infix.(x.magnitude - y.magnitude) }
            else zero )

    let negate t = {t with sgn= Sgn.negate t.sgn}

    let of_unsigned magnitude = {magnitude; sgn= Sgn.Pos}

    let ( + ) = add

    module Checked = struct
      let to_bits {magnitude; sgn} =
        var_to_bits magnitude @ [Sgn.Checked.is_pos sgn]

      let constant {magnitude; sgn} =
        {magnitude= var_of_t magnitude; sgn= Sgn.Checked.constant sgn}

      let of_unsigned magnitude = {magnitude; sgn= Sgn.Checked.pos}

      let if_ cond ~then_ ~else_ =
        let%map sgn = Sgn.Checked.if_ cond ~then_:then_.sgn ~else_:else_.sgn
        and magnitude =
          if_ cond ~then_:then_.magnitude ~else_:else_.magnitude
        in
        {sgn; magnitude}

      let to_triples t =
        Bitstring.pad_to_triple_list ~default:Boolean.false_ (to_bits t)

      let to_field_var ({magnitude; sgn} : var) =
        Tick.Field.Checked.mul (pack_var magnitude) (sgn :> Field.Checked.t)

      let add (x : var) (y : var) =
        let%bind xv = to_field_var x and yv = to_field_var y in
        let%bind sgn =
          provide_witness Sgn.typ
            (let open As_prover in
            let open Let_syntax in
            let%map x = read typ x and y = read typ y in
            (Option.value_exn (add x y)).sgn)
        in
        let%bind res =
          Tick.Field.Checked.mul
            (sgn :> Field.Checked.t)
            (Field.Checked.add xv yv)
        in
        let%map magnitude = unpack_var res in
        {magnitude; sgn}

      let ( + ) = add

      let cswap_field (b : Boolean.var) (x, y) =
        (* (x + b(y - x), y + b(x - y)) *)
        let open Field.Checked.Infix in
        let%map b_y_minus_x =
          Tick.Field.Checked.mul (b :> Field.Checked.t) (y - x)
        in
        (x + b_y_minus_x, y - b_y_minus_x)

      let cswap b (x, y) =
        let l_sgn, r_sgn =
          match (x.sgn, y.sgn) with
          | Sgn.Pos, Sgn.Pos -> Sgn.Checked.(pos, pos)
          | Neg, Neg -> Sgn.Checked.(neg, neg)
          | Pos, Neg -> (Sgn.Checked.neg_if_true b, Sgn.Checked.pos_if_true b)
          | Neg, Pos -> (Sgn.Checked.pos_if_true b, Sgn.Checked.neg_if_true b)
        in
        let%map l_mag, r_mag =
          let%bind l, r =
            cswap_field b (pack_var x.magnitude, pack_var y.magnitude)
          in
          let%map l = unpack_var l and r = unpack_var r in
          (l, r)
        in
        ({sgn= l_sgn; magnitude= l_mag}, {sgn= r_sgn; magnitude= r_mag})
    end
  end

  module Checked = struct
    let if_ = if_

    let if_value cond ~then_ ~else_ : var =
      List.init M.length ~f:(fun i ->
          match (Vector.get then_ i, Vector.get else_ i) with
          | true, true -> Boolean.true_
          | false, false -> Boolean.false_
          | true, false -> cond
          | false, true -> Boolean.not cond )

    (* Unpacking protects against underflow *)
    let sub (x : Unpacked.var) (y : Unpacked.var) =
      unpack_var (Field.Checked.sub (pack_var x) (pack_var y))

    let sub_flagged x y =
      let z = Field.Checked.sub (pack_var x) (pack_var y) in
      let%map bits, `Success no_underflow =
        Field.Checked.unpack_flagged z ~length:length_in_bits
      in
      (bits, `Underflow (Boolean.not no_underflow))

    let%test_unit "sub_flagged" =
      let sub_flagged_unchecked (x, y) =
        if x < y then (zero, true) else (Option.value_exn (x - y), false)
      in
      let sub_flagged_checked =
        let f (x, y) =
          Checked.map (sub_flagged x y) ~f:(fun (r, `Underflow u) -> (r, u))
        in
        Test_util.checked_to_unchecked (Typ.tuple2 typ typ)
          (Typ.tuple2 typ Boolean.typ)
          f
      in
      Quickcheck.test ~trials:100 (Quickcheck.Generator.tuple2 gen gen)
        ~f:(fun p ->
          let m, u = sub_flagged_unchecked p in
          let m_checked, u_checked = sub_flagged_checked p in
          assert (Bool.equal u u_checked) ;
          if not u then [%test_eq: magnitude] m m_checked )

    (* Unpacking protects against overflow *)
    let add (x : Unpacked.var) (y : Unpacked.var) =
      unpack_var (Field.Checked.add (pack_var x) (pack_var y))

    let ( - ) = sub

    let ( + ) = add

    let add_signed (t : var) (d : Signed.var) =
      let%bind d = Signed.Checked.to_field_var d in
      Field.Checked.add (pack_var t) d |> unpack_var

    let%test_module "currency_test" =
      ( module struct
        let expect_failure err c = if check c () then failwith err

        let expect_success err c = if not (check c ()) then failwith err

        let to_bigint x = Bignum_bigint.of_string (Unsigned.to_string x)

        let of_bigint x = Unsigned.of_string (Bignum_bigint.to_string x)

        let gen_incl x y =
          Quickcheck.Generator.map ~f:of_bigint
            (Bignum_bigint.gen_incl (to_bigint x) (to_bigint y))

        (* TODO: When we do something to make snarks run fast for tests, increase the trials *)
        let qc_test_fast = Quickcheck.test ~trials:100

        let%test_unit "subtraction_completeness" =
          let generator =
            let open Quickcheck.Generator.Let_syntax in
            let%bind x = gen_incl Unsigned.zero Unsigned.max_int in
            let%map y = gen_incl Unsigned.zero x in
            (x, y)
          in
          qc_test_fast generator ~f:(fun (lo, hi) ->
              expect_success
                (sprintf !"subtraction: lo=%{Unsigned} hi=%{Unsigned}" lo hi)
                (var_of_t lo - var_of_t hi) )

        let%test_unit "subtraction_soundness" =
          let generator =
            let open Quickcheck.Generator.Let_syntax in
            let%bind x = gen_incl Unsigned.zero Unsigned.(sub max_int one) in
            let%map y = gen_incl Unsigned.(add x one) Unsigned.max_int in
            (x, y)
          in
          qc_test_fast generator ~f:(fun (lo, hi) ->
              expect_failure
                (sprintf !"underflow: lo=%{Unsigned} hi=%{Unsigned}" lo hi)
                (var_of_t lo - var_of_t hi) )

        let%test_unit "addition_completeness" =
          let generator =
            let open Quickcheck.Generator.Let_syntax in
            let%bind x = gen_incl Unsigned.zero Unsigned.max_int in
            let%map y = gen_incl Unsigned.zero Unsigned.(sub max_int x) in
            (x, y)
          in
          qc_test_fast generator ~f:(fun (x, y) ->
              expect_success
                (sprintf !"overflow: x=%{Unsigned} y=%{Unsigned}" x y)
                (var_of_t x + var_of_t y) )

        let%test_unit "addition_soundness" =
          let generator =
            let open Quickcheck.Generator.Let_syntax in
            let%bind x = gen_incl Unsigned.one Unsigned.max_int in
            let%map y =
              gen_incl Unsigned.(add (sub max_int x) one) Unsigned.max_int
            in
            (x, y)
          in
          qc_test_fast generator ~f:(fun (x, y) ->
              expect_failure
                (sprintf !"overflow: x=%{Unsigned} y=%{Unsigned}" x y)
                (var_of_t x + var_of_t y) )
      end )
  end
end

let currency_length = 64

module Fee =
  Make
    (Unsigned_extended.UInt64)
    (struct
      let length = currency_length
    end)

module Amount = struct
  module T =
    Make
      (Unsigned_extended.UInt64)
      (struct
        let length = currency_length
      end)

  type amount = T.Stable.V1.t [@@deriving bin_io, sexp]

  include (
    T :
      module type of T
      with type var = T.var
       and module Signed = T.Signed
       and module Checked := T.Checked )

  let of_fee (fee : Fee.t) : t = fee

  let to_fee (fee : t) : Fee.t = fee

  let add_fee (t : t) (fee : Fee.t) = add t (of_fee fee)

  module Checked = struct
    include T.Checked

    let of_fee (fee : Fee.var) : var = fee

    let to_fee (t : var) : Fee.var = t

    let add_fee (t : var) (fee : Fee.var) =
      Field.Checked.add (pack_var t) (Fee.pack_var fee) |> unpack_var
  end
end

module Balance = struct
  include (Amount : Basic with type t = Amount.t and type var = Amount.var)

  let to_amount = Fn.id

  let add_amount = Amount.add

  let sub_amount = Amount.sub

  let ( + ) = add_amount

  let ( - ) = sub_amount

  module Checked = struct
    let add_signed_amount = Amount.Checked.add_signed

    let add_amount = Amount.Checked.add

    let sub_amount = Amount.Checked.sub

    let ( + ) = add_amount

    let ( - ) = sub_amount
  end
end
