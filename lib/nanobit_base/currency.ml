open Core
open Snark_params
open Tick
open Let_syntax

module type Basic = sig
  type t [@@deriving sexp, compare, eq, hash]

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, sexp, compare, eq, hash]
    end
  end

  include Bits_intf.S with type t := t

  val length : int

  val zero : t

  val of_string : string -> t

  val to_string : t -> string

  type var

  val typ : (var, t) Typ.t

  val of_int : int -> t

  val var_of_t : t -> var

  val var_to_bits : var -> Boolean.var Bitstring.Lsb_first.t
end

module type Arithmetic_intf = sig
  type t

  val add : t -> t -> t option

  val sub : t -> t -> t option

  val ( + ) : t -> t -> t option

  val ( - ) : t -> t -> t option
end

module type Checked_arithmetic_intf = sig
  type var

  val add : var -> var -> (var, _) Checked.t

  val sub : var -> var -> (var, _) Checked.t

  val ( + ) : var -> var -> (var, _) Checked.t

  val ( - ) : var -> var -> (var, _) Checked.t
end

module type S = sig
  include Basic

  include Arithmetic_intf with type t := t

  module Checked : Checked_arithmetic_intf with type var := var
end

module Make
    (Unsigned : Unsigned_extended.S) (M : sig
        val length : int
    end) : sig
  include S with type t = Unsigned.t

  val var_of_bits : Boolean.var Bitstring.Lsb_first.t -> var

  val unpack_var : Field.Checked.t -> (var, _) Tick.Checked.t

  val pack_var : var -> Field.Checked.t
end = struct
  let length = M.length

  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Unsigned.t [@@deriving bin_io, sexp, eq, compare, hash]
      end

      include T
      include Hashable.Make (T)
    end
  end

  include Stable.V1

  let of_int = Unsigned.of_int

  let of_string = Unsigned.of_string

  let to_string = Unsigned.to_string

  module Vector = struct
    include M
    include Unsigned

    let empty = zero

    let get t i = Infix.((t lsr i) land one = one)

    let set v i b =
      if b then Infix.(v lor (one lsl i)) else Infix.(v land lognot (one lsl i))
  end

  include (Bits.Vector.Make (Vector) : Bits_intf.S with type t := t)

  include Bits.Snarkable.Small_bit_vector (Tick) (Vector)
  include Unpacked

  let var_to_bits t = Bitstring.Lsb_first.of_list (var_to_bits t)

  let var_of_bits (bits: Boolean.var Bitstring.Lsb_first.t) : var =
    let bits = (bits :> Boolean.var list) in
    let n = List.length bits in
    assert (n <= M.length) ;
    let padding = M.length - n in
    bits @ List.init padding ~f:(fun _ -> Boolean.false_)

  let zero = Unsigned.zero

  let sub x y = if compare x y < 0 then None else Some (Unsigned.sub x y)

  let add x y =
    let z = Unsigned.add x y in
    if compare z x < 0 then None else Some z

  let ( + ) = add

  let ( - ) = sub

  let var_of_t t =
    List.init M.length (fun i -> Boolean.var_of_value (Vector.get t i))

  module Checked = struct
    (* Unpacking protects against underflow *)
    let sub (x: Unpacked.var) (y: Unpacked.var) =
      unpack_var (Field.Checked.sub (pack_var x) (pack_var y))

    (* Unpacking protects against overflow *)
    let add (x: Unpacked.var) (y: Unpacked.var) =
      unpack_var (Field.Checked.add (pack_var x) (pack_var y))

    let ( - ) = sub

    let ( + ) = add

    let%test_module "currency_test" =
      ( module struct
        let expect_failure err c = if check c () then failwith err

        let expect_success err c = if not (check c ()) then failwith err

        let to_bigint x = Bignum_bigint.of_string (Unsigned.to_string x)

        let of_bigint x = Unsigned.of_string (Bignum_bigint.to_string x)

        let gen_incl x y =
          Quickcheck.Generator.map ~f:of_bigint
            (Bignum_bigint.gen_incl (to_bigint x) (to_bigint y))

        let%test_unit "subtraction_completeness" =
          let generator =
            let open Quickcheck.Generator.Let_syntax in
            let%bind x = gen_incl Unsigned.zero Unsigned.max_int in
            let%map y = gen_incl Unsigned.zero x in
            (x, y)
          in
          Quickcheck.test generator ~f:(fun (lo, hi) ->
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
          Quickcheck.test generator ~f:(fun (lo, hi) ->
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
          Quickcheck.test generator ~f:(fun (x, y) ->
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
          Quickcheck.test generator ~f:(fun (x, y) ->
              expect_failure
                (sprintf !"overflow: x=%{Unsigned} y=%{Unsigned}" x y)
                (var_of_t x + var_of_t y) )
      end )
  end
end

module Fee =
  Make (Unsigned_extended.UInt32)
    (struct
      let length = 32
    end)

module Amount = struct
  module T =
    Make (Unsigned_extended.UInt64)
      (struct
        let length = 64
      end)

  type amount = T.Stable.V1.t [@@deriving bin_io, sexp]

  type amount_var = T.var

  include (
    T :
      module type of T
      with type var = amount_var
       and module Checked := T.Checked )

  let of_fee (fee: Fee.t) : t =
    Unsigned.UInt64.of_int64 (Unsigned.UInt32.to_int64 fee)

  let add_fee (t: t) (fee: Fee.t) = add t (of_fee fee)

  module Signed = struct
    type ('magnitude, 'sgn) t_ = {magnitude: 'magnitude; sgn: 'sgn}
    [@@deriving bin_io, sexp]

    let create ~magnitude ~sgn = {magnitude; sgn}

    type t = (amount, Sgn.t) t_ [@@deriving bin_io, sexp]

    let zero = create ~magnitude:zero ~sgn:Sgn.Pos

    type nonrec var = (var, Sgn.var) t_

    let length = Int.( + ) T.length 1

    let of_hlist : (unit, 'a -> 'b -> unit) H_list.t -> ('a, 'b) t_ =
      H_list.(fun [magnitude; sgn] -> {magnitude; sgn})

    let to_hlist {magnitude; sgn} = H_list.[magnitude; sgn]

    let typ =
      Typ.of_hlistable
        Data_spec.[typ; Sgn.typ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let fold ({sgn; magnitude}: t) ~init ~f =
      let init = f init (match sgn with Pos -> true | Neg -> false) in
      fold magnitude ~init ~f

    let add (x: t) (y: t) : t option =
      match (x.sgn, y.sgn) with
      | Neg, (Neg as sgn) | Pos, (Pos as sgn) ->
          let open Option.Let_syntax in
          let%map magnitude = add x.magnitude y.magnitude in
          {sgn; magnitude}
      | Pos, Neg | Neg, Pos ->
          let c = compare x.magnitude y.magnitude in
          Some
            ( if c < 0 then
                { sgn= y.sgn
                ; magnitude= Unsigned.UInt64.Infix.(y.magnitude - x.magnitude)
                }
            else if c > 0 then
              { sgn= x.sgn
              ; magnitude= Unsigned.UInt64.Infix.(x.magnitude - y.magnitude) }
            else zero )

    let ( + ) = add

    module Checked = struct
      let to_bits {magnitude; sgn} =
        Sgn.Checked.is_pos sgn :: (var_to_bits magnitude :> Boolean.var list)

      let to_field_var ({magnitude; sgn}: var) =
        Tick.Checked.mul (pack_var magnitude) (sgn :> Field.Checked.t)

      let add (x: var) (y: var) =
        let%bind xv = to_field_var x and yv = to_field_var y in
        let%bind sgn =
          provide_witness Sgn.typ
            (let open As_prover in
            let open Let_syntax in
            let%map x = read typ x and y = read typ y in
            (Option.value_exn (add x y)).sgn)
        in
        let%bind res =
          Tick.Checked.mul (sgn :> Field.Checked.t) (Field.Checked.add xv yv)
        in
        let%map magnitude = unpack_var res in
        {magnitude; sgn}

      let ( + ) = add

      let cswap_field (b: Boolean.var) (x, y) =
        (* (x + b(y - x), y + b(x - y)) *)
        let open Field.Checked.Infix in
        let%map b_y_minus_x =
          Tick.Checked.mul (b :> Field.Checked.t) (y - x)
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
    include T.Checked

    let of_fee (fee: Fee.var) = var_of_bits (Fee.var_to_bits fee)

    let add_fee (t: var) (fee: Fee.var) =
      Field.Checked.add (pack_var t) (Fee.pack_var fee) |> unpack_var

    let add_signed (t: var) (d: Signed.var) =
      let%bind d = Signed.Checked.to_field_var d in
      Field.Checked.add (pack_var t) d |> unpack_var
  end
end

module Balance = struct
  include (Amount : Basic with type t = Amount.t and type var = Amount.var)

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
