open Core_kernel
open Snark_params
open Signed
open Unsigned
module T = Coda_numbers.Slot

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
    let length_to_int = Coda_numbers.Length.Checked.to_integer in
    let ck = Integer.mul ~m (length_to_int c) (length_to_int k) in
    let two = Integer.constant ~m (Bignum_bigint.of_int 2) in
    let ck_times_2 = Integer.mul ~m ck two in
    let slot = to_integer slot in
    let slot_gte_ck = Integer.gte ~m slot ck
    and slot_lt_ck_times_2 = Integer.lt ~m slot ck_times_2 in
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
  let to_var c =
    let open Snark_params.Tick in
    let c = exists Coda_numbers.Length.typ ~compute:(As_prover.return c) in
    run_unchecked c () |> snd
  in
  let test =
    Test_util.test_equal typ Tick.Boolean.typ
      (Checked.in_seed_update_range ~c:(to_var constants.c)
         ~k:(to_var constants.k))
      (in_seed_update_range ~c:constants.c ~k:constants.k)
  in
  let x = UInt32.mul constants.c constants.k |> UInt32.to_int in
  let examples =
    List.map ~f:UInt32.of_int [x; x - 1; x + 1; x * 2; (x * 2) - 1; (x * 2) + 1]
  in
  Quickcheck.test ~trials:100 ~examples gen ~f:test
