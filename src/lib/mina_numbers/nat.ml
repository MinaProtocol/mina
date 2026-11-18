open Core_kernel
open Fold_lib
include Intf
module Intf = Intf
open Snark_bits

module Make_checked
    (N : Unsigned_extended.S)
    (Bits : Bits_intf.Convertible_bits with type t := N.t) =
struct
  open Snark_params.Tick

  type var = Field.Var.t

  let () = assert (Int.(N.length_in_bits < Field.size_in_bits))

  let to_input (t : var) =
    Random_oracle.Input.Chunked.packed (t, N.length_in_bits)

  let to_input_legacy (t : var) =
    let to_bits (t : var) =
      with_label (sprintf "to_bits: %s" __LOC__) (fun () ->
          Field.Checked.choose_preimage_var t ~length:N.length_in_bits )
    in
    Checked.map (to_bits t) ~f:(fun bits ->
        Random_oracle.Input.Legacy.bitstring bits )

  let constant n =
    Field.Var.constant
      (Bigint.to_field (Bigint.of_bignum_bigint (N.to_bigint n)))

  let () = assert (Int.(N.length_in_bits mod 16 = 0))

  let range_check' (t : var) =
    let _, _, actual_packed =
      Pickles.Scalar_challenge.to_field_checked' ~num_bits:N.length_in_bits
        (module Run)
        (Kimchi_backend_common.Scalar_challenge.create t)
    in
    actual_packed

  let range_check t =
    let%bind actual = make_checked (fun () -> range_check' t) in
    Field.Checked.Assert.equal actual t

  let range_check_flag t =
    let open Pickles.Impls.Step in
    let actual = range_check' t in
    Field.equal actual t

  let of_field (x : Field.t) : N.t =
    let of_bits bs =
      (* TODO: Make this efficient *)
      List.foldi bs ~init:N.zero ~f:(fun i acc b ->
          if b then N.(logor (shift_left one i) acc) else acc )
    in
    of_bits (List.take (Field.unpack x) N.length_in_bits)

  let to_field (x : N.t) : Field.t = Field.project (Fold.to_list (Bits.fold x))

  let typ : (var, N.t) Typ.t =
    let (Typ field_typ) = Field.typ in
    Typ.transport
      (Typ { field_typ with check = range_check })
      ~there:to_field ~back:of_field

  let () = assert (N.length_in_bits * 2 < Field.size_in_bits + 1)

  let assert_div_mod ~(x : var) ~(y : var) ~(q : var) ~(r : var) =
    (* q * y + r = x

       q * y = x - r
    *)
    let%bind () = assert_r1cs q y (Field.Var.sub x r) in
    (* r < y, i.e. y - r - 1 does not underflow. Since r >= 0, this also
       forces y <> 0; together these make (q, r) the unique Euclidean
       quotient and remainder.
    *)
    range_check Field.Var.(sub (sub y r) (constant Field.one))

  let div_mod (x : var) (y : var) =
    let%bind q, r =
      exists (Typ.tuple2 typ typ)
        ~compute:
          As_prover.(
            let%map x = read typ x and y = read typ y in
            (N.div x y, N.rem x y))
    in
    let%map () = assert_div_mod ~x ~y ~q ~r in
    (q, r)

  type t = var

  let is_succ ~pred ~succ =
    let open Snark_params.Tick in
    let open Field in
    Checked.(equal (pred + Var.constant one) succ)

  let gte x y =
    let open Pickles.Impls.Step in
    let xy = Pickles.Util.Step.seal Field.(x - y) in
    let yx = Pickles.Util.Step.seal (Field.negate xy) in
    let x_gte_y = range_check_flag xy in
    let y_gte_x = range_check_flag yx in
    Boolean.Assert.any [ x_gte_y; y_gte_x ] ;
    x_gte_y

  let op op a b = make_checked (fun () -> op a b)

  let ( >= ) a b = op gte a b

  let ( <= ) a b = b >= a

  let ( < ) a b =
    make_checked (fun () ->
        let open Pickles.Impls.Step in
        Boolean.( &&& ) (gte b a) (Boolean.not (Field.equal b a)) )

  let ( > ) a b = b < a

  module Assert = struct
    let equal = Field.Checked.Assert.equal
  end

  let to_field = Fn.id

  module Unsafe = struct
    let of_field = Fn.id
  end

  let min a b =
    let%bind a_lte_b = a <= b in
    Field.Checked.if_ a_lte_b ~then_:a ~else_:b

  let if_ = Field.Checked.if_

  let succ_if (t : var) (c : Boolean.var) =
    Checked.return (Field.Var.add t (c :> Field.Var.t))

  let succ (t : var) =
    Checked.return (Field.Var.add t (Field.Var.constant Field.one))

  let seal x = make_checked (fun () -> Pickles.Util.Step.seal x)

  let add (x : var) (y : var) =
    let%bind res = seal (Field.Var.add x y) in
    let%map () = range_check res in
    res

  let mul (x : var) (y : var) =
    let%bind res = Field.Checked.mul x y in
    let%map () = range_check res in
    res

  let subtract_unpacking_or_zero x y =
    let open Pickles.Impls.Step in
    let res = Pickles.Util.Step.seal Field.(x - y) in
    let neg_res = Pickles.Util.Step.seal (Field.negate res) in
    let x_gte_y = range_check_flag res in
    let y_gte_x = range_check_flag neg_res in
    Boolean.Assert.any [ x_gte_y; y_gte_x ] ;
    (* If y_gte_x is false, then x_gte_y is true, so x >= y and
       thus there was no underflow.

       If y_gte_x is true, then y >= x, which means there was underflow
       iff y != x.

       Thus, underflow = (neg_res_good && y != x)
    *)
    let underflow = Boolean.( &&& ) y_gte_x (Boolean.not (Field.equal x y)) in
    (`Underflow underflow, Field.if_ underflow ~then_:Field.zero ~else_:res)

  let sub_or_zero a b = make_checked (fun () -> subtract_unpacking_or_zero a b)

  (* Unpacking protects against underflow *)
  let sub (x : var) (y : var) =
    let%bind res = seal (Field.Var.sub x y) in
    let%map () = range_check res in
    res

  let equal a b = Field.Checked.equal a b

  let ( = ) = equal

  let zero = Field.Var.constant Field.zero
end

open Snark_params.Tick

module Make (N : sig
  type t [@@deriving sexp, compare, hash]

  include Unsigned_extended.S with type t := t

  val random : unit -> t
end)
(Bits : Bits_intf.Convertible_bits with type t := N.t) =
struct
  type t = N.t [@@deriving sexp, compare, hash, yojson]

  let max_value = N.max_int

  include Comparable.Make (N)

  include (N : module type of N with type t := t)

  let sub x y = if x < y then None else Some (N.sub x y)

  let to_field n = Bigint.to_field (Bigint.of_bignum_bigint (N.to_bigint n))

  module Checked = Make_checked (N) (Bits)

  (* warning: this typ does not work correctly with the generic if_ *)
  let typ = Checked.typ

  module Bits = Bits

  let to_bits = Bits.to_bits

  let of_bits = Bits.of_bits

  let to_input (t : t) =
    Random_oracle.Input.Chunked.packed (to_field t, N.length_in_bits)

  let to_input_legacy t = Random_oracle.Input.Legacy.bitstring (to_bits t)

  let fold t = Fold.group3 ~default:false (Bits.fold t)

  let gen =
    Quickcheck.Generator.map
      ~f:(fun n -> N.of_string (Bignum_bigint.to_string n))
      (Bignum_bigint.gen_incl Bignum_bigint.zero
         (Bignum_bigint.of_string N.(to_string max_int)) )

  let gen_incl min max =
    let open Quickcheck.Let_syntax in
    let%map n =
      Bignum_bigint.gen_incl
        (Bignum_bigint.of_string (N.to_string min))
        (Bignum_bigint.of_string (N.to_string max))
    in
    N.of_string (Bignum_bigint.to_string n)
end

module Make32 () : UInt32 = struct
  open Unsigned_extended

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      [@@@with_all_version_tags]

      type t = UInt32.Stable.V1.t
      [@@deriving sexp, equal, compare, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  include
    Make
      (struct
        include UInt32

        let random () =
          let mask = if Random.bool () then one else zero in
          let open UInt32.Infix in
          logor (mask lsl 31)
            ( Int32.max_value |> Random.int32 |> Int64.of_int32
            |> UInt32.of_int64 )
      end)
      (Bits.UInt32)

  let to_uint32 = Unsigned_extended.UInt32.to_uint32

  let of_uint32 = Unsigned_extended.UInt32.of_uint32
end

module Make64 () : UInt64 = struct
  open Unsigned_extended

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      [@@@with_all_version_tags]

      type t = UInt64.Stable.V1.t
      [@@deriving sexp, equal, compare, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  include
    Make
      (struct
        include UInt64

        let random () =
          let mask = if Random.bool () then one else zero in
          let open UInt64.Infix in
          logor (mask lsl 63)
            (Int64.max_value |> Random.int64 |> UInt64.of_int64)
      end)
      (Bits.UInt64)

  let to_uint64 = Unsigned_extended.UInt64.to_uint64

  let of_uint64 = Unsigned_extended.UInt64.of_uint64
end

let%test_module "div_mod" =
  ( module struct
    module N = Unsigned_extended.UInt32
    module C = Make_checked (N) (Bits.UInt32)

    let accepts ~x ~y ~q ~r =
      let witness n = exists C.typ ~compute:(As_prover.return n) in
      Or_error.is_ok
        (check
           (let%bind x = witness x
            and y = witness y
            and q = witness q
            and r = witness r in
            C.assert_div_mod ~x ~y ~q ~r ) )

    module N64 = Unsigned_extended.UInt64
    module C64 = Make_checked (N64) (Bits.UInt64)

    let accepts64 ~x ~y ~q ~r =
      let witness n = exists C64.typ ~compute:(As_prover.return n) in
      Or_error.is_ok
        (check
           (let%bind x = witness x
            and y = witness y
            and q = witness q
            and r = witness r in
            C64.assert_div_mod ~x ~y ~q ~r ) )

    let%test_unit "div_mod computes the quotient and remainder" =
      Quickcheck.test
        Quickcheck.Generator.(
          both (Int.gen_incl 0 1_000_000) (Int.gen_incl 1 1_000_000))
        ~f:(fun (x, y) ->
          let q, r =
            Or_error.ok_exn
              (run_and_check
                 (let%bind x =
                    exists C.typ ~compute:(As_prover.return (N.of_int x))
                  and y =
                    exists C.typ ~compute:(As_prover.return (N.of_int y))
                  in
                  let%map q, r = C.div_mod x y in
                  As_prover.(
                    let%map q = read C.typ q and r = read C.typ r in
                    (N.to_int q, N.to_int r)) ) )
          in
          [%test_eq: int * int] (q, r) (x / y, x % y) )

    let%test "accepts the canonical witness" =
      accepts ~x:(N.of_int 17) ~y:(N.of_int 5) ~q:(N.of_int 3) ~r:(N.of_int 2)

    let%test "rejects a remainder equal to the divisor" =
      not
        (accepts ~x:(N.of_int 15) ~y:(N.of_int 5) ~q:(N.of_int 2)
           ~r:(N.of_int 5) )

    let%test "rejects a remainder larger than the divisor" =
      not
        (accepts ~x:(N.of_int 17) ~y:(N.of_int 5) ~q:(N.of_int 1)
           ~r:(N.of_int 12) )

    let%test "rejects the trivial witness q = 0, r = x" =
      not
        (accepts ~x:(N.of_int 17) ~y:(N.of_int 5) ~q:(N.of_int 0)
           ~r:(N.of_int 17) )

    let%test "rejects a zero divisor" =
      not
        (accepts ~x:(N.of_int 17) ~y:(N.of_int 0) ~q:(N.of_int 42)
           ~r:(N.of_int 17) )

    let%test "accepts a remainder one less than the divisor" =
      accepts ~x:(N.of_int 9) ~y:(N.of_int 5) ~q:N.one ~r:(N.of_int 4)

    let%test "accepts x = y = max" =
      accepts ~x:N.max_int ~y:N.max_int ~q:N.one ~r:N.zero

    let%test "accepts x = max - 1, y = max" =
      accepts ~x:(N.pred N.max_int) ~y:N.max_int ~q:N.zero ~r:(N.pred N.max_int)

    let%test "rejects r = x = y = max" =
      not (accepts ~x:N.max_int ~y:N.max_int ~q:N.zero ~r:N.max_int)

    let%test "accepts x = q = max, y = 1" =
      accepts ~x:N.max_int ~y:N.one ~q:N.max_int ~r:N.zero

    let%test "64-bit: accepts the canonical witness for x = max" =
      let x = N64.max_int and y = N64.of_int 7 in
      accepts64 ~x ~y ~q:(N64.div x y) ~r:(N64.rem x y)

    let%test "64-bit: rejects a remainder equal to the divisor" =
      not
        (accepts64 ~x:(N64.of_int 15) ~y:(N64.of_int 5) ~q:(N64.of_int 2)
           ~r:(N64.of_int 5) )

    let%test "64-bit: rejects the trivial witness q = 0, r = x" =
      not
        (accepts64 ~x:N64.max_int ~y:(N64.of_int 5) ~q:N64.zero ~r:N64.max_int)

    let%test "64-bit: rejects a zero divisor" =
      not
        (accepts64 ~x:(N64.of_int 17) ~y:N64.zero ~q:(N64.of_int 42)
           ~r:(N64.of_int 17) )
  end )
