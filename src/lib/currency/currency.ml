[%%import "/src/config.mlh"]

open Core_kernel
open Snark_bits
open Snark_params
open Tick

[%%ifdef consensus_mechanism]

open Bitstring_lib
open Let_syntax

[%%endif]

open Intf

type uint64 = Unsigned.uint64

[%%ifdef consensus_mechanism]

module Signed_var = struct
  type 'mag repr = ('mag, Sgn.var) Signed_poly.t

  (* Invariant: At least one of these is Some *)
  type nonrec 'mag t = { repr : 'mag repr; mutable value : Field.Var.t option }
end

[%%endif]

module Make (Unsigned : sig
  include Unsigned_extended.S

module Make_str (T : Mina_wire_types.Currency.Concrete) = struct
  module Signed_poly = Signed_poly

  module Make (Unsigned : sig
    include Unsigned_extended.S

  include
    S
      with type t = Unsigned.t
       and type var = Field.Var.t
       and type Signed.var = Field.Var.t Signed_var.t
       and type Signed.signed_fee = (Unsigned.t, Sgn.t) Signed_poly.t
       and type Signed.Checked.signed_fee_var = Field.Var.t Signed_var.t

    val var_of_bits : Boolean.var Bitstring.Lsb_first.t -> var

    val unpack_var : Field.Var.t -> (var, _) Tick.Checked.t

  include
    S
      with type t = Unsigned.t
       and type Signed.signed_fee := (Unsigned.t, Sgn.t) Signed_poly.t

    [%%else]

    include S with type t = Unsigned.t

    [%%endif]

    val scale : t -> int -> t option
  end = struct
    let max_int = Unsigned.max_int

    let length_in_bits = M.length

    type t = Unsigned.t [@@deriving sexp, compare, hash]

    (* can't be automatically derived *)
    let dhall_type = Ppx_dhall_type.Dhall_type.Text

    [%%define_locally
    Unsigned.(to_uint64, of_uint64, of_int, to_int, of_string, to_string)]

    let precision = 9

    let precision_exp = Unsigned.of_int @@ Int.pow 10 precision

    let to_formatted_string amount =
      let rec go num_stripped_zeros num =
        let open Int in
        if num mod 10 = 0 && num <> 0 then go (num_stripped_zeros + 1) (num / 10)
        else (num_stripped_zeros, num)
      in
      let whole = Unsigned.div amount precision_exp in
      let remainder = Unsigned.to_int (Unsigned.rem amount precision_exp) in
      if Int.(remainder = 0) then to_string whole
      else
        let num_stripped_zeros, num = go 0 remainder in
        Printf.sprintf "%s.%0*d" (to_string whole)
          Int.(precision - num_stripped_zeros)
          num

    let of_formatted_string input =
      let parts = String.split ~on:'.' input in
      match parts with
      | [ whole ] ->
          of_string (whole ^ String.make precision '0')
      | [ whole; decimal ] ->
          let decimal_length = String.length decimal in
          if Int.(decimal_length > precision) then
            of_string (whole ^ String.sub decimal ~pos:0 ~len:precision)
          else
            of_string
              ( whole ^ decimal
              ^ String.make Int.(precision - decimal_length) '0' )
      | _ ->
          failwith "Currency.of_formatted_string: Invalid currency input"

    module Arg = struct
      type typ = t [@@deriving sexp, hash, compare]

      type t = typ [@@deriving sexp, hash, compare]

      let to_string = to_formatted_string

      let of_string = of_formatted_string
    end

    include Codable.Make_of_string (Arg)
    include Hashable.Make (Arg)
    include Comparable.Make (Arg)

    let gen_incl a b : t Quickcheck.Generator.t =
      let a = Bignum_bigint.of_string Unsigned.(to_string a) in
      let b = Bignum_bigint.of_string Unsigned.(to_string b) in
      Quickcheck.Generator.map
        Bignum_bigint.(gen_incl a b)
        ~f:(fun n -> of_string (Bignum_bigint.to_string n))

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

    module B = Bits.Vector.Make (Vector)

  type var = Field.Var.t

  let pack_var = Fn.id

  let equal_var = Field.Checked.equal

  let m = Snark_params.Tick.m

  let make_checked = Snark_params.Tick.make_checked

  let var_to_bits_ (t : var) = Field.Checked.unpack ~length:length_in_bits t

  let var_to_bits t = var_to_bits_ t >>| Bitstring.Lsb_first.of_list

  let var_to_input (t : var) =
    Random_oracle.Input.Chunked.packed (t, length_in_bits)

  let var_to_input_legacy (t : var) =
    var_to_bits_ t >>| Random_oracle.Input.Legacy.bitstring

  let var_of_t (t : t) : var = Field.Var.constant (Field.project (to_bits t))

  let if_ cond ~then_ ~else_ : var Checked.t =
    Field.Checked.if_ cond ~then_ ~else_

  let () = assert (Int.(length_in_bits mod 16 = 0))

  (** UNSAFE. Take the field element formed by the final [length_in_bits] bits
      of the argument.

      WARNING: The returned value may be chosen arbitrarily by a malicious
      prover, and this is really only useful for the more-efficient bit
      projection. Users of this function must manually assert the relationship
      between the argument and the return value, or the circuit will be
      underconstrained.
  *)
  let image_from_bits_unsafe (t : var) =
    make_checked (fun () ->
        let _, _, actual_packed =
          Pickles.Scalar_challenge.to_field_checked' ~num_bits:length_in_bits m
            (Kimchi_backend_common.Scalar_challenge.create t)
        in
        actual_packed )

  (** [range_check t] asserts that [0 <= t < 2^length_in_bits].

      Any value consumed or returned by functions in this module must satisfy
      this assertion.
  *)
  let range_check t =
    let%bind actual = image_from_bits_unsafe t in
    with_label "range_check" (Field.Checked.Assert.equal actual t)

  let seal x = make_checked (fun () -> Pickles.Util.seal Tick.m x)

  let modulus_as_field =
    lazy (Fn.apply_n_times ~n:length_in_bits Field.(mul (of_int 2)) Field.one)

  let double_modulus_as_field =
    lazy (Field.(mul (of_int 2)) (Lazy.force modulus_as_field))

  (** [range_check_flagged kind t] returns [t'] that fits in [length_in_bits]
      bits, and satisfies [t' = t + k * 2^length_in_bits] for some [k].
      The [`Overflow b] return value is false iff [t' = t].

      This function should be used when [t] was computed via addition or
      subtraction, to calculate the equivalent value that would be returned by
      overflowing or underflowing an integer with [length_in_bits] bits.

      The [`Add] and [`Sub] values for [kind] are specializations that use
      fewer constraints and perform fewer calculations. Any inputs that satisfy
      the invariants for [`Add] or [`Sub] will return the same value if
      [`Add_or_sub] is used instead.

      Invariants:
      * if [kind] is [`Add], [0 <= t < 2 * 2^length_in_bits - 1];
      * if [kind] is [`Sub], [- 2^length_in_bits < t < 2^length_in_bits];
      * if [kind] is [`Add_or_sub],
        [- 2^length_in_bits < t < 2 * 2^length_in_bits - 1].
  *)
  let range_check_flagged (kind : [ `Add | `Sub | `Add_or_sub ]) t =
    let%bind adjustment_factor =
      exists Field.typ
        ~compute:
          As_prover.(
            let%map t = read Field.typ t in
            match kind with
            | `Add ->
                if Int.(Field.compare t (Lazy.force modulus_as_field) < 0) then
                  (* Within range. *)
                  Field.zero
                else
                  (* Overflowed. We compensate by subtracting [modulus_as_field]. *)
                  Field.(negate one)
            | `Sub ->
                if Int.(Field.compare t (Lazy.force modulus_as_field) < 0) then
                  (* Within range. *)
                  Field.zero
                else
                  (* Underflowed, but appears as an overflow because of wrapping in
                     the field (that is, -1 is the largest field element, -2 is the
                     second largest, etc.). Compensate by adding [modulus_as_field].
                  *)
                  Field.one
            | `Add_or_sub ->
                (* This case is a little more nuanced: -modulus_as_field < t <
                   2*modulus_as_field, and we need to detect which 'side of 0' we
                   are. Thus, we have 3 cases:
                *)
                if Int.(Field.compare t (Lazy.force modulus_as_field) < 0) then
                  (* 1. we are already in the desired range, no adjustment; *)
                  Field.zero
                else if
                  Int.(Field.compare t (Lazy.force double_modulus_as_field) < 0)
                then
                  (* 2. we are in the range
                        [modulus_as_field <= t < 2 * modulus_as_field],
                        so this was an addition that overflowed, and we should
                        compensate by subtracting [modulus_as_field];
                  *)
                  Field.(negate one)
                else
                  (* 3. we are outside of either range, so this must be the
                        underflow of a subtraction, and we should compensate by
                        adding [modulus_as_field].
                  *)
                  Field.one)
    in
    let%bind out_of_range =
      match kind with
      | `Add ->
          (* 0 or -1 => 0 or 1 *)
          Boolean.of_field (Field.Var.negate adjustment_factor)
      | `Sub ->
          (* Already 0 or 1 *)
          Boolean.of_field adjustment_factor
      | `Add_or_sub ->
          (* The return flag [out_of_range] is a boolean represented by either 0
             when [t] is in range or 1 when [t] is out-of-range.
             Notice that [out_of_range = adjustment_factor^2] gives us exactly
             the desired values, and moreover we can ensure that
             [adjustment_factor] is exactly one of -1, 0 or 1 by checking that
             [out_of_range] is boolean.
          *)
          Field.Checked.mul adjustment_factor adjustment_factor
          >>= Boolean.of_field
    in
    (* [t_adjusted = t + adjustment_factor * modulus_as_field] *)
    let t_adjusted =
      let open Field.Var in
      add t (scale adjustment_factor (Lazy.force modulus_as_field))
    in
    let%bind t_adjusted = seal t_adjusted in
    let%map () = range_check t_adjusted in
    (t_adjusted, `Overflow out_of_range)

  let of_field (x : Field.t) : t =
    of_bits (List.take (Field.unpack x) length_in_bits)

  let to_field (x : t) : Field.t = Field.project (to_bits x)

  let typ : (var, t) Typ.t =
    let (Typ typ) = Field.typ in
    Typ.transport
      (Typ { typ with check = range_check })
      ~there:to_field ~back:of_field

  [%%endif]

  let zero = Unsigned.zero

  let one = Unsigned.one

  let sub x y = if x < y then None else Some (Unsigned.sub x y)

  let sub_flagged x y =
    let z = Unsigned.sub x y in
    (z, `Underflow (x < y))

  let add x y =
    let z = Unsigned.add x y in
    if z < x then None else Some z

  let add_flagged x y =
    let z = Unsigned.add x y in
    (z, `Overflow (z < x))

  let add_signed_flagged x y =
    match y.Signed_poly.sgn with
    | Sgn.Pos ->
        let z, `Overflow b = add_flagged x y.Signed_poly.magnitude in
        (z, `Overflow b)
    | Sgn.Neg ->
        let z, `Underflow b = sub_flagged x y.Signed_poly.magnitude in
        (z, `Overflow b)

  let scale u64 i =
    let i = Unsigned.of_int i in
    let max_val = Unsigned.(div max_int i) in
    if max_val >= u64 then Some (Unsigned.mul u64 i) else None

  let ( + ) = add

  let ( - ) = sub

  type magnitude = t [@@deriving sexp, hash, compare, yojson]

  let to_input (t : t) =
    Random_oracle.Input.Chunked.packed
      (Field.project (to_bits t), length_in_bits)

  let to_input_legacy t = Random_oracle.Input.Legacy.bitstring @@ to_bits t

  module Signed = struct
    type ('magnitude, 'sgn) typ = ('magnitude, 'sgn) Signed_poly.t =
      { magnitude : 'magnitude; sgn : 'sgn }
    [@@deriving sexp, hash, compare, yojson, hlist]

    type t = (Unsigned.t, Sgn.t) Signed_poly.t [@@deriving sexp, hash, yojson]

    let compare : t -> t -> int =
      let cmp = [%compare: (Unsigned.t, Sgn.t) Signed_poly.t] in
      fun t1 t2 ->
        if Unsigned.(equal t1.magnitude zero && equal t2.magnitude zero) then 0
        else cmp t1 t2

    let equal : t -> t -> bool =
      let eq = [%equal: (Unsigned.t, Sgn.t) Signed_poly.t] in
      fun t1 t2 ->
        if Unsigned.(equal t1.magnitude zero && equal t2.magnitude zero) then
          true
        else eq t1 t2

    let is_zero (t : t) : bool = Unsigned.(equal t.magnitude zero)

    let is_positive (t : t) : bool =
      match t.sgn with
      | Pos ->
          not Unsigned.(equal zero t.magnitude)
      | Neg ->
          false

    let is_negative (t : t) : bool =
      match t.sgn with
      | Neg ->
          not Unsigned.(equal zero t.magnitude)
      | Pos ->
          false

    type magnitude = Unsigned.t [@@deriving sexp, compare]

    let create ~magnitude ~sgn = { magnitude; sgn }

    let sgn { sgn; _ } = sgn

    let magnitude { magnitude; _ } = magnitude

    let zero : t = create ~magnitude:zero ~sgn:Sgn.Pos

    let gen =
      Quickcheck.Generator.map2 gen Sgn.gen ~f:(fun magnitude sgn ->
          if Unsigned.(equal zero magnitude) then zero
          else create ~magnitude ~sgn )

    let sgn_to_bool = function Sgn.Pos -> true | Neg -> false

    let to_bits ({ sgn; magnitude } : t) = sgn_to_bool sgn :: to_bits magnitude

    let to_input { sgn; magnitude } =
      Random_oracle.Input.Chunked.(
        append (to_input magnitude)
          (packed (Field.project [ sgn_to_bool sgn ], 1)))

    let to_input_legacy t = Random_oracle.Input.Legacy.bitstring (to_bits t)

    let add (x : t) (y : t) : t option =
      match (x.sgn, y.sgn) with
      | Neg, (Neg as sgn) | Pos, (Pos as sgn) ->
          let open Option.Let_syntax in
          let%map magnitude = add x.magnitude y.magnitude in
          create ~sgn ~magnitude
      | Pos, Neg | Neg, Pos ->
          let c = compare_magnitude x.magnitude y.magnitude in
          Some
            ( if Int.( < ) c 0 then
              create ~sgn:y.sgn
                ~magnitude:Unsigned.Infix.(y.magnitude - x.magnitude)
            else if Int.( > ) c 0 then
              create ~sgn:x.sgn
                ~magnitude:Unsigned.Infix.(x.magnitude - y.magnitude)
            else zero )

    let add_flagged (x : t) (y : t) : t * [ `Overflow of bool ] =
      match (x.sgn, y.sgn) with
      | Neg, (Neg as sgn) | Pos, (Pos as sgn) ->
          let magnitude, `Overflow b = add_flagged x.magnitude y.magnitude in
          (create ~sgn ~magnitude, `Overflow b)
      | Pos, Neg | Neg, Pos ->
          let c = compare_magnitude x.magnitude y.magnitude in
          ( ( if Int.( < ) c 0 then
              create ~sgn:y.sgn
                ~magnitude:Unsigned.Infix.(y.magnitude - x.magnitude)
            else if Int.( > ) c 0 then
              create ~sgn:x.sgn
                ~magnitude:Unsigned.Infix.(x.magnitude - y.magnitude)
            else zero )
          , `Overflow false )

    let negate t =
      if Unsigned.(equal zero t.magnitude) then zero
      else { t with sgn = Sgn.negate t.sgn }

    let of_unsigned magnitude : t = create ~magnitude ~sgn:Sgn.Pos

    let ( + ) = add

    let to_fee = Fn.id

    let of_fee = Fn.id

    [%%ifdef consensus_mechanism]

    type signed_fee = t

    let magnitude_to_field = to_field

    let to_field (t : t) : Field.t =
      Field.mul (Sgn.to_field t.sgn) (magnitude_to_field t.magnitude)

    type repr = var Signed_var.repr

    type nonrec var = var Signed_var.t

    let repr_typ : (repr, t) Typ.t =
      Typ.of_hlistable [ typ; Sgn.typ ] ~var_to_hlist:typ_to_hlist
        ~var_of_hlist:typ_of_hlist ~value_to_hlist:typ_to_hlist
        ~value_of_hlist:typ_of_hlist

    let typ : (var, t) Typ.t =
      Typ.transport_var repr_typ
        ~back:(fun repr -> { Signed_var.value = None; repr })
        ~there:(fun { Signed_var.repr; _ } -> repr)

    let create_var ~magnitude ~sgn : var =
      { repr = { magnitude; sgn }; value = None }

    module Checked = struct
      type t = var

      type signed_fee_var = t

      let repr (t : var) = Checked.return t.repr

      let value (t : var) =
        match t.value with
        | Some x ->
            Checked.return x
        | None ->
            let r = t.repr in
            let%map x = Field.Checked.mul (r.sgn :> Field.Var.t) r.magnitude in
            t.value <- Some x ;
            x

      let to_field_var = value

      let to_input t =
        let%map { magnitude; sgn } = repr t in
        let mag = var_to_input magnitude in
        Random_oracle.Input.Chunked.(
          append mag (packed ((Sgn.Checked.is_pos sgn :> Field.Var.t), 1)))

      let to_input_legacy t =
        let to_bits { magnitude; sgn } =
          let%map magnitude = var_to_bits_ magnitude in
          Sgn.Checked.is_pos sgn :: magnitude
        in
        repr t >>= to_bits >>| Random_oracle.Input.Legacy.bitstring

      let constant ({ magnitude; sgn } as t) =
        { Signed_var.repr =
            { magnitude = var_of_t magnitude; sgn = Sgn.Checked.constant sgn }
        ; value = Some (Field.Var.constant (to_field t))
        }

      let of_unsigned magnitude : var =
        { repr = { magnitude; sgn = Sgn.Checked.pos }; value = Some magnitude }

      let negate (t : var) : var =
        { value = Option.map t.value ~f:Field.Var.negate
        ; repr =
            (let { magnitude; sgn } = t.repr in
             { magnitude; sgn = Sgn.Checked.negate sgn } )
        }

      let if_repr cond ~then_ ~else_ =
        let%map sgn = Sgn.Checked.if_ cond ~then_:then_.sgn ~else_:else_.sgn
        and magnitude =
          if_ cond ~then_:then_.magnitude ~else_:else_.magnitude
        in
        { sgn; magnitude }

      let if_ cond ~(then_ : var) ~(else_ : var) : var Checked.t =
        let%bind repr = if_repr cond ~then_:then_.repr ~else_:else_.repr in
        let%map value =
          match (then_.value, else_.value) with
          | Some v1, Some v2 ->
              Field.Checked.if_ cond ~then_:v1 ~else_:v2 >>| Option.return
          | _ ->
              return None
        in
        { Signed_var.value; repr }

      let sgn (t : var) =
        let%map r = repr t in
        r.sgn

      let magnitude (t : var) =
        let%map r = repr t in
        r.magnitude

      let add_flagged (x : var) (y : var) =
        let%bind xv = value x and yv = value y in
        let%bind sgn =
          exists Sgn.typ
            ~compute:
              (let open As_prover in
              let%map x = read typ x and y = read typ y in
              match add x y with
              | Some r ->
                  r.sgn
              | None -> (
                  match (x.sgn, y.sgn) with
                  | Sgn.Neg, Sgn.Neg ->
                      (* Ensure that we provide a value in the range
                         [-modulus_as_field < magnitude < 2*modulus_as_field]
                         for [range_check_flagged].
                      *)
                      Sgn.Neg
                  | _ ->
                      Sgn.Pos ))
        in
        let value = Field.Var.add xv yv in
        let%bind magnitude =
          Tick.Field.Checked.mul (sgn :> Field.Var.t) value
        in
        let%bind res_magnitude, `Overflow overflow =
          range_check_flagged `Add_or_sub magnitude
        in
        (* Recompute the result from [res_magnitude], since it may have been
           adjusted.
        *)
        let%map res_value = Field.Checked.mul (sgn :> Field.Var.t) magnitude in
        ( { Signed_var.repr = { magnitude = res_magnitude; sgn }
          ; value = Some res_value
          }
        , `Overflow overflow )

      let add (x : var) (y : var) =
        let%bind xv = value x and yv = value y in
        let%bind sgn =
          exists Sgn.typ
            ~compute:
              (let open As_prover in
              let%map x = read typ x and y = read typ y in
              Option.value_map (add x y) ~default:Sgn.Pos ~f:(fun r -> r.sgn))
        in
        let%bind res_value = seal (Field.Var.add xv yv) in
        let%bind magnitude =
          Tick.Field.Checked.mul (sgn :> Field.Var.t) res_value
        in
        let%map () = range_check magnitude in
        { Signed_var.repr = { magnitude; sgn }; value = Some res_value }

      let ( + ) = add

      let equal (t1 : var) (t2 : var) =
        let%bind t1 = value t1 and t2 = value t2 in
        Field.Checked.equal t1 t2

      let assert_equal (t1 : var) (t2 : var) =
        let%bind t1 = value t1 and t2 = value t2 in
        Field.Checked.Assert.equal t1 t2

      let to_fee = Fn.id

      let of_fee = Fn.id
    end

    [%%endif]
  end

  let currency_length = 64

  module Fee = struct
    module T =
      Make
        (Unsigned_extended.UInt64)
        (struct
          let length = currency_length
        end)

    include T

    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

    (* Unpacking protects against underflow *)
    let sub (x : var) (y : var) =
      let%bind res = seal (Field.Var.sub x y) in
      let%map () = range_check res in
      res

    let sub_flagged x y =
      let%bind z = seal (Field.Var.sub x y) in
      let%map z, `Overflow underflow = range_check_flagged `Sub z in
      (z, `Underflow underflow)

    let sub_or_zero x y =
      let%bind res, `Underflow underflow = sub_flagged x y in
      Field.Checked.if_ underflow ~then_:Field.(Var.constant zero) ~else_:res

    let assert_equal x y = Field.Checked.Assert.equal x y

    let equal x y = Field.Checked.equal x y

    let ( = ) = equal

    let ( < ) x y =
      let%bind diff = seal (Field.Var.sub x y) in
      (* [lt] is true iff [x - y < 0], ie. [x < y] *)
      let%map _res, `Overflow lt = range_check_flagged `Sub diff in
      lt

    (* x <= y iff not (y < x) *)
    let ( <= ) x y =
      let%map y_lt_x = y < x in
      Boolean.not y_lt_x

    (* x >= y iff y <= x *)
    let ( >= ) x y = y <= x

    let ( > ) x y = y < x

    (* Unpacking protects against overflow *)
    let add (x : var) (y : var) =
      let%bind res = seal (Field.Var.add x y) in
      let%map () = range_check res in
      res

    let add_flagged x y =
      let%bind z = seal (Field.Var.add x y) in
      let%map z, `Overflow overflow = range_check_flagged `Add z in
      (z, `Overflow overflow)

    let ( - ) = sub

    let ( + ) = add

    let add_signed (t : var) (d : Signed.var) =
      let%bind d = Signed.Checked.to_field_var d in
      let%bind res = seal (Field.Var.add t d) in
      let%map () = range_check res in
      res

    let add_signed_flagged (t : var) (d : Signed.var) =
      let%bind d = Signed.Checked.to_field_var d in
      let%bind res = seal (Field.Var.add t d) in
      let%map res, `Overflow overflow = range_check_flagged `Add_or_sub res in
      (res, `Overflow overflow)

    let scale (f : Field.Var.t) (t : var) =
      let%bind res = Field.Checked.mul t f in
      let%map () = range_check res in
      res

    let%test_module "currency_test" =
      ( module struct
        let expect_failure err c = if Or_error.is_ok (check c) then failwith err

        let expect_success err c =
          match check c with
          | Ok () ->
              ()
          | Error e ->
              Error.(raise (tag ~tag:err e))

        let to_bigint x = Bignum_bigint.of_string (Unsigned.to_string x)

        let of_bigint x = Unsigned.of_string (Bignum_bigint.to_string x)

        let gen_incl x y =
          Quickcheck.Generator.map ~f:of_bigint
            (Bignum_bigint.gen_incl (to_bigint x) (to_bigint y))

        let shrinker =
          Quickcheck.Shrinker.create (fun i ->
              Sequence.unfold ~init:i ~f:(fun i ->
                  if Unsigned.equal i Unsigned.zero then None
                  else
                    let n = Unsigned.div i (Unsigned.of_int 10) in
                    Some (n, n) ) )

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

        let%test_unit "formatting_roundtrip" =
          let generator = gen_incl Unsigned.zero Unsigned.max_int in
          qc_test_fast generator ~shrinker ~f:(fun num ->
              match of_formatted_string (to_formatted_string num) with
              | after_format ->
                  if Unsigned.equal after_format num then ()
                  else
                    Error.(
                      raise
                        (of_string
                           (sprintf
                              !"formatting: num=%{Unsigned} middle=%{String} \
                                after=%{Unsigned}"
                              num (to_formatted_string num) after_format ) ))
              | exception e ->
                  let err = Error.of_exn e in
                  Error.(
                    raise
                      (tag
                         ~tag:(sprintf !"formatting: num=%{Unsigned}" num)
                         err )) )

        let%test_unit "formatting_trailing_zeros" =
          let generator = gen_incl Unsigned.zero Unsigned.max_int in
          qc_test_fast generator ~shrinker ~f:(fun num ->
              let formatted = to_formatted_string num in
              let has_decimal = String.contains formatted '.' in
              let trailing_zero = String.is_suffix formatted ~suffix:"0" in
              if has_decimal && trailing_zero then
                Error.(
                  raise
                    (of_string
                       (sprintf
                          !"formatting: num=%{Unsigned} formatted=%{String}"
                          num (to_formatted_string num) ) )) )
      end )
  end

  [%%endif]
end

let currency_length = 64

module Fee = struct
  module T =
    Make
      (Unsigned_extended.UInt64)
      (struct
        let length = currency_length
      end)

  include T

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t = Unsigned_extended.UInt64.Stable.V1.t
      [@@deriving sexp, compare, hash, equal]

      [%%define_from_scope to_yojson, of_yojson, dhall_type]

      let to_latest = Fn.id
    end
  end]

  type _unused = unit constraint Signed.t = (t, Sgn.t) Signed_poly.t
end

module Amount = struct
  (* See documentation for {!module:Mina_wire_types} *)
  module Make_sig (A : sig
    type t
  end) =
  struct
    module type S = sig
      [%%versioned:
      module Stable : sig
        module V1 : sig
          type t = A.t [@@deriving sexp, compare, hash, equal, yojson]

          (* not automatically derived *)
          val dhall_type : Ppx_dhall_type.Dhall_type.t
        end
      end]

      [%%ifdef consensus_mechanism]

      (* Give a definition to var, it will be hidden at the interface level *)
      include
        Basic
          with type t := Stable.Latest.t
           and type var =
            Pickles.Impls.Step.Impl.Internal_Basic.field
            Snarky_backendless.Cvar.t

      [%%else]

      include Basic with type t := Stable.Latest.t

      [%%endif]

      include Arithmetic_intf with type t := t

      include Codable.S with type t := t

      [%%ifdef consensus_mechanism]

      module Signed :
        Signed_intf
          with type magnitude := t
           and type magnitude_var := var
           and type signed_fee := Fee.Signed.t
           and type Checked.signed_fee_var := Fee.Signed.Checked.t

      [%%else]

      module Signed :
        Signed_intf with type magnitude := t and type signed_fee := Fee.Signed.t

      [%%endif]

      (* TODO: Delete these functions *)

      val of_fee : Fee.t -> t

      val to_fee : t -> Fee.t

      val add_fee : t -> Fee.t -> t option

      [%%ifdef consensus_mechanism]

      module Checked : sig
        include
          Checked_arithmetic_intf
            with type var := var
             and type signed_var := Signed.var
             and type value := t

        val add_signed : var -> Signed.var -> var Checked.t

        val of_fee : Fee.var -> var

        val to_fee : var -> Fee.var

        module Unsafe : sig
          val of_field : Field.Var.t -> t
        end
      end
    end]

      [%%endif]

      val add_signed_flagged : t -> Signed.t -> t * [ `Overflow of bool ]
    end
  end

  module Amount = struct
    module T =
      Make
        (Unsigned_extended.UInt64)
        (struct
          let length = currency_length
        end)

    [%%ifdef consensus_mechanism]

    include (
      T :
        module type of T
          with type var = T.var
           and module Signed = T.Signed
           and module Checked := T.Checked )

    [%%else]

    include (T : module type of T with module Signed = T.Signed)

    [%%endif]

    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V1 = struct
        type t = Unsigned_extended.UInt64.Stable.V1.t
        [@@deriving sexp, compare, hash, equal, yojson]

        [%%define_from_scope to_yojson, of_yojson, dhall_type]

        let to_latest = Fn.id
      end
    end]

    let of_fee (fee : Fee.t) : t = fee

    let to_fee (fee : t) : Fee.t = fee

    let add_fee (t : t) (fee : Fee.t) = add t (of_fee fee)

    [%%ifdef consensus_mechanism]

    module Checked = struct
      include T.Checked

      let of_fee (fee : Fee.var) : var = fee

      let to_fee (t : var) : Fee.var = t

      module Unsafe = struct
        let of_field : Field.Var.t -> var = Fn.id
      end
    end

    [%%endif]
  end

  module Balance = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Amount.Stable.V1.t
        [@@deriving sexp, compare, equal, hash, yojson]

        let to_latest = Fn.id

        (* can't be automatically derived *)
        let dhall_type = Ppx_dhall_type.Dhall_type.Text
      end
    end]

    [%%ifdef consensus_mechanism]

    include (Amount : Basic with type t := t with type var = Amount.var)

    [%%else]

    include (Amount : Basic with type t := t)

    [%%endif]

    let to_amount = Fn.id

    let add_amount = Amount.add

  let add_amount = Amount.add

  let add_amount_flagged = Amount.add_flagged

  let sub_amount = Amount.sub

  let sub_amount_flagged = Amount.sub_flagged

  let add_signed_amount_flagged = Amount.add_signed_flagged

  let ( + ) = add_amount

  let ( - ) = sub_amount

  [%%ifdef consensus_mechanism]

  module Checked = struct
    include Amount.Checked

    module Unsafe = struct
      let of_field (x : Field.Var.t) : var = x
    end

    let to_amount = Fn.id

    let add_signed_amount = add_signed

    let add_amount = add

    let sub_amount = sub

    let add_amount_flagged = add_flagged

    let add_signed_amount_flagged = add_signed_flagged

    let sub_amount_flagged = sub_flagged

    let ( + ) = add_amount

    let ( - ) = sub_amount

  [%%endif]
end

module Fee_rate = struct
  type t = Q.t

  let uint64_to_z u64 = Z.of_string @@ Unsigned.UInt64.to_string u64

  let uint64_of_z z = Unsigned.UInt64.of_string @@ Z.to_string z

  let max_uint64_z = uint64_to_z Unsigned.UInt64.max_int

  let fits_uint64 z =
    let open Z in
    leq zero z && leq z max_uint64_z

  (** check if a Q.t is in range *)
  let check_q Q.{ num; den } : bool =
    let open Z in
    fits_uint64 num && fits_int32 den
    && if equal zero den then equal zero num else true

  let of_q q = if check_q q then Some q else None

  let of_q_exn q = Option.value_exn (of_q q)

  let to_q = ident

  let make fee weight = of_q @@ Q.make (uint64_to_z fee) (Z.of_int weight)

  let make_exn fee weight = Option.value_exn (make fee weight)

  let to_uint64 Q.{ num; den } =
    if Z.(equal den Z.one) then Some (uint64_of_z num) else None

  let to_uint64_exn fr = Option.value_exn (to_uint64 fr)

  let add x y = of_q @@ Q.add x y

  let add_flagged x y =
    let z = Q.add x y in
    (z, `Overflow (check_q z))

  let sub x y = of_q @@ Q.sub x y

  let sub_flagged x y =
    let z = Q.sub x y in
    (z, `Underflow (check_q z))

  let mul x y = of_q @@ Q.mul x y

  let div x y = of_q @@ Q.div x y

  let ( + ) = add

  let ( - ) = sub

  let ( * ) = mul

  let scale fr s = fr * Q.of_int s

  let scale_exn fr s = Option.value_exn (scale fr s)

  let compare = Q.compare

  let t_of_sexp sexp =
    let open Ppx_sexp_conv_lib.Conv in
    pair_of_sexp Fee.t_of_sexp int_of_sexp sexp
    |> fun (fee, weight) -> make_exn fee weight

  let sexp_of_t Q.{ num = fee; den = weight } =
    let sexp_of_fee fee = Fee.sexp_of_t @@ uint64_of_z fee in
    let sexp_of_weight weight = sexp_of_int @@ Z.to_int weight in
    sexp_of_pair sexp_of_fee sexp_of_weight (fee, weight)

  include Comparable.Make (struct
    type nonrec t = t

    let compare = compare

    let t_of_sexp = t_of_sexp

    let sexp_of_t = sexp_of_t
  end)
end

let%test_module "sub_flagged module" =
  ( module struct
    [%%ifdef consensus_mechanism]

    module Checked = struct
      include Amount.Checked

      let add_signed_amount = add_signed

      let add_amount = add

      type var

      (* TODO =
         field Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t list *)

      let add_amount_flagged = add_flagged

      let add_signed_amount_flagged = add_signed_flagged

      let sub_amount_flagged = sub_flagged

      let ( + ) = add_amount

      module Checked : sig
        val sub_flagged :
          var -> var -> (var * [ `Underflow of Boolean.var ]) Tick.Checked.t
      end
    end

    [%%endif]
  end

  let%test_module "sub_flagged module" =
    ( module struct
      [%%ifdef consensus_mechanism]

      open Tick

      module type Sub_flagged_S = sig
        type t

        type magnitude = t [@@deriving sexp, compare]

        type var =
          field Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t list

        val zero : t

        val ( - ) : t -> t -> t option

        val typ : (var, t) Typ.t

        val gen : t Quickcheck.Generator.t

        module Checked : sig
          val sub_flagged :
               var
            -> var
            -> (var * [ `Underflow of Boolean.var ], 'a) Tick.Checked.t
        end
      end

      let run_test (module M : Sub_flagged_S) =
        let open M in
        let sub_flagged_unchecked (x, y) =
          if compare_magnitude x y < 0 then (zero, true)
          else (Option.value_exn (x - y), false)
        in
        let sub_flagged_checked =
          let f (x, y) =
            Snarky_backendless.Checked.map (M.Checked.sub_flagged x y)
              ~f:(fun (r, `Underflow u) -> (r, u))
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
            if not u then [%test_eq: M.magnitude] m m_checked )

      let%test_unit "fee sub_flagged" = run_test (module Fee)

      let%test_unit "amount sub_flagged" = run_test (module Amount)

      [%%endif]
    end )
end

include Mina_wire_types.Currency.Make (Make_sig) (Make_str)
