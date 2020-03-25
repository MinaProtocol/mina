open Core_kernel
open Snark_params
open Signed
open Unsigned

module T = Coda_numbers.Nat.Make32 ()

include (T : module type of T with module Checked := T.Checked)

let in_seed_update_range (slot : t) ~(c : Coda_numbers.Length.t)
    ~(k : Coda_numbers.Length.t) =
  let open UInt32.Infix in
  let ck = c * k in
  ck <= slot && slot < ck * UInt32.of_int 2

module Checked = struct
  include T.Checked

  let in_seed_update_range (slot : var) ~c ~k =
    let open Tick in
    let open Tick.Let_syntax in
    let open Snarky_integer in
    let module Length = Coda_numbers.Length in
    let integer_mul i i' = make_checked (fun () -> Integer.mul ~m i i') in
    let to_integer = Length.Checked.to_integer in
    let%bind ck = integer_mul (to_integer c) (to_integer k) in
    let two = Integer.constant ~m (Bignum_bigint.of_int 2) in
    let%bind ck_times_2 = integer_mul ck two in
    let slot_gte_ck = Integer.gte ~m (T.Checked.to_integer slot) ck in
    let slot_lt_ck_times_2 =
      Integer.lt ~m (T.Checked.to_integer slot) ck_times_2
    in
    Boolean.(slot_gte_ck && slot_lt_ck_times_2)
end

let gen =
  let open Quickcheck.Let_syntax in
  let constants = Constants.compiled in
  let ck3 =
    UInt32.Infix.(constants.c * constants.k * UInt32.of_int 3) |> UInt32.to_int
  in
  Core.Int.gen_incl 0 ck3 >>| UInt32.of_int

let%test_unit "in_seed_update_range unchecked vs. checked equality" =
  let constants = Constants.compiled in
  let module Length = Coda_numbers.Length in
  let test x =
    Test_util.test_equal
      (Snarky.Typ.tuple3 Length.typ Length.typ typ)
      Tick.Boolean.typ
      (fun (c, k, x) -> Checked.in_seed_update_range ~c ~k x)
      (fun (c, k, x) -> in_seed_update_range ~c ~k x)
      (constants.c, constants.k, x)
  in
  let x = UInt32.mul constants.c constants.k |> UInt32.to_int in
  let examples =
    List.map ~f:UInt32.of_int [x; x - 1; x + 1; x * 2; (x * 2) - 1; (x * 2) + 1]
  in
  Quickcheck.test ~trials:100 ~examples gen ~f:test
