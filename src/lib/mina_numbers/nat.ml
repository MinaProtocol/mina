[%%import "/src/config.mlh"]

open Core_kernel
open Fold_lib
include Intf
module Intf = Intf
open Snark_bits

[%%ifdef consensus_mechanism]

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
      with_label
        (sprintf "to_bits: %s" __LOC__)
        (Field.Checked.choose_preimage_var t ~length:N.length_in_bits)
    in
    Checked.map (to_bits t) ~f:(fun bits ->
        Random_oracle.Input.Legacy.bitstring bits )

  let constant n =
    Field.Var.constant
      (Bigint.to_field (Bigint.of_bignum_bigint (N.to_bigint n)))

  let () = assert (Int.(N.length_in_bits mod 16 = 0))

  let range_check' (t : var) =
    let _, _, actual_packed =
      Pickles.Scalar_challenge.to_field_checked' ~num_bits:N.length_in_bits m
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
      (Typ
         { field_typ with check = (fun x -> make_checked_ast @@ range_check x) }
      )
      ~there:to_field ~back:of_field

  let () = assert (N.length_in_bits * 2 < Field.size_in_bits + 1)

  let div_mod (x : var) (y : var) =
    let%bind q, r =
      exists (Typ.tuple2 typ typ)
        ~compute:
          As_prover.(
            let%map x = read typ x and y = read typ y in
            (N.div x y, N.rem x y))
    in

    (* q * y + r = x

       q * y = x - r
    *)
    let%map () = assert_r1cs q y (Field.Var.sub x r) in
    (q, r)

  type t = var

  let is_succ ~pred ~succ =
    let open Snark_params.Tick in
    let open Field in
    Checked.(equal (pred + Var.constant one) succ)

  let gte x y =
    let open Pickles.Impls.Step in
    let xy = Pickles.Util.seal m Field.(x - y) in
    let yx = Pickles.Util.seal m (Field.negate xy) in
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

  let seal x = make_checked (fun () -> Pickles.Util.seal m x)

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
    let res = Pickles.Util.seal m Field.(x - y) in
    let neg_res = Pickles.Util.seal m (Field.negate res) in
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

[%%endif]

open Snark_params.Tick

module Make (N : sig
  type t [@@deriving sexp, compare, hash]

  include Unsigned_extended.S with type t := t

  val random : unit -> t
end)
(Bits : Bits_intf.Convertible_bits with type t := N.t) =
struct
  type t = N.t [@@deriving sexp, compare, hash, yojson]

  (* can't be automatically derived *)
  let dhall_type = Ppx_dhall_type.Dhall_type.Text

  let max_value = N.max_int

  include Comparable.Make (N)

  include (N : module type of N with type t := t)

  let sub x y = if x < y then None else Some (N.sub x y)

  [%%ifdef consensus_mechanism]

  module Checked = Make_checked (N) (Bits)

  (* warning: this typ does not work correctly with the generic if_ *)
  let typ = Checked.typ

  [%%endif]

  module Bits = Bits

  let to_bits = Bits.to_bits

  let of_bits = Bits.of_bits

  let to_input (t : t) =
    Random_oracle.Input.Chunked.packed
      (Field.project (to_bits t), N.length_in_bits)

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
