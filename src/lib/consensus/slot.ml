open Core_kernel
open Snark_params
open Signed
open Unsigned

module T = Coda_numbers.Nat.Make32 ()

include (T : module type of T with module Checked := T.Checked)

let in_seed_update_range (slot : t) ~c ~k =
  let ck = c * k |> UInt32.of_int in
  let open UInt32.Infix in
  ck <= slot && slot < ck * UInt32.of_int 2

module Checked = struct
  include T.Checked

  let in_seed_update_range (slot : var) ~c ~k =
    (*let uint32_msb (x : UInt32.t) =
      List.init 32 ~f:(fun i ->
          let open UInt32 in
          let open Infix in
          let ( = ) x y = Core.Int.equal (compare x y) 0 in
          (x lsr Int.sub 31 i) land UInt32.one = UInt32.one )
      |> Bitstring_lib.Bitstring.Msb_first.of_list
    in*)
    let open Tick in
    let open Tick.Let_syntax in
    let open Snarky_integer in
    (*let ( < ) = Bitstring_checked.lt_value in
    let constants = (Coda_constants.t ()).consensus in*)
    let const_to_integer =
      Coda_base.Coda_constants_checked.T.Checked.to_integer
    in
    let ck = Integer.mul ~m (const_to_integer c) (const_to_integer k) in
    (*let ck_bitstring = uint32_msb ck in*)
    let two = Integer.constant ~m (Bignum_bigint.of_int 2) in
    let ck_times_2 = Integer.mul ~m ck two in
    let slot = to_integer slot in
    (*let%bind slot_msb =
      to_bits slot >>| Bitstring_lib.Bitstring.Msb_first.of_lsb_first
    in*)
    let slot_gte_ck = Integer.gte ~m slot ck
    (*slot_msb < ck_bitstring >>| Boolean.not*)
    and slot_lt_ck_times_2 =
      Integer.lt ~m slot ck_times_2
      (*slot_msb < ck_times_2*)
    in
    Boolean.(slot_gte_ck && slot_lt_ck_times_2)
end

let gen =
  let open Quickcheck.Let_syntax in
  let constants = Coda_constants.compiled_constants_for_test.consensus in
  Core.Int.gen_incl 0 (constants.c * constants.k * 3) >>| UInt32.of_int

let%test_unit "in_seed_update_range unchecked vs. checked equality" =
  let constants = Coda_constants.compiled_constants_for_test.consensus in
  let test =
    Test_util.test_equal typ Tick.Boolean.typ
      (Checked.in_seed_update_range
         ~c:
           (Coda_base.Coda_constants_checked.T.Checked.constant
              (UInt32.of_int constants.c))
         ~k:
           (Coda_base.Coda_constants_checked.T.Checked.constant
              (UInt32.of_int constants.k)))
      (in_seed_update_range ~c:constants.c ~k:constants.k)
  in
  let x = constants.c * constants.k in
  let examples =
    List.map ~f:UInt32.of_int [x; x - 1; x + 1; x * 2; (x * 2) - 1; (x * 2) + 1]
  in
  Quickcheck.test ~trials:100 ~examples gen ~f:test
